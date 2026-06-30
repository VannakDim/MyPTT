import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';


class AudioService {
  static const _channel = MethodChannel('com.example.mobile/audio');

  Future<void> _setSpeakerphone(bool enable) async {
    try {
      await _channel.invokeMethod('setSpeakerphoneOn', {'enable': enable});
      print("[AudioService] Set speakerphone to: $enable");
    } catch (e) {
      print("[AudioService] Failed to set speakerphone: $e");
    }
  }

  /// ប្តូរ Audio Output: 'speaker' | 'earpiece' | 'bluetooth'
  Future<void> setAudioOutput(String port) async {
    try {
      await _channel.invokeMethod('setAudioOutput', {'port': port});
      print("[AudioService] Set audio output to: $port");
    } catch (e) {
      print("[AudioService] Failed to set audio output: $e");
    }
  }

  /// ទាញយកបញ្ជី Audio Output ដែលមាន (earpiece, speaker, bluetooth)
  Future<List<Map<String, String>>> listAudioOutputs() async {
    try {
      final List<dynamic> raw = await _channel.invokeMethod('listAudioOutputs');
      return raw.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (e) {
      print("[AudioService] Failed to list audio outputs: $e");
      return [
        {'id': 'earpiece', 'name': 'ស្មាហ្វូន', 'type': 'earpiece'},
        {'id': 'speaker',  'name': 'លំโพ',     'type': 'speaker'},
      ];
    }
  }
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _urlPlayer;
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;

  bool isMuted = false;
  StreamController<Uint8List>? _recordingStreamController;
  StreamSubscription<Uint8List>? _recordingSubscription;

  // variables for flutter_pcm_sound queue based playback
  final List<int> _audioQueue = [];
  bool _isPlaying = false;
  bool _isBuffering = false;
  final List<int> _accumulationBuffer = [];
  Function(Uint8List)? _onDataReceivedCallback;

  // ១. ផ្ដួចផ្ដើមសេវាកម្មសំឡេង (Initialization)
  Future<void> initialize({bool requestPermission = true}) async {
    if (requestPermission) {
      // ស្នើសុំសិទ្ធិប្រើប្រាស់ Microphone
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception("Microphone permission not granted");
      }
    }

    // Configure system audio session to force loudspeaker/speakerphone by default
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker |
                                       AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ));
      await session.setActive(true);
    } catch (e) {
      print("[AudioService] Failed to configure audio session: $e");
    }

    _recorder = FlutterSoundRecorder();
    _isRecorderInitialized = true;

    // Initialize flutter_pcm_sound for output stream
    try {
      await FlutterPcmSound.setup(
        sampleRate: 16000,
        channelCount: 1,
      );
      await FlutterPcmSound.setFeedThreshold(1600); // Trigger callback when remaining samples < 1600
      FlutterPcmSound.setFeedCallback(_onFeed);
      _isPlayerInitialized = true;
      await _setSpeakerphone(true);
    } catch (e) {
      print("[AudioService] Failed to initialize PcmSound player: $e");
    }
  }

  // Callback to feed samples dynamically to AudioTrack
  void _onFeed(int remainingFrames) async {
    final int framesToFeed = remainingFrames > 0 ? remainingFrames : 1600;
    
    if (_isBuffering) {
      // Jitter buffer threshold: wait until we accumulate 1600 samples (100ms of audio)
      if (_audioQueue.length >= 1600) {
        _isBuffering = false;
      } else {
        try {
          await FlutterPcmSound.feed(PcmArrayInt16.fromList(List.filled(framesToFeed, 0)));
        } catch (e) {
          // Ignore feed errors
        }
        return;
      }
    }

    if (_audioQueue.length >= framesToFeed) {
      final List<int> chunk = _audioQueue.sublist(0, framesToFeed);
      _audioQueue.removeRange(0, framesToFeed);
      try {
        await FlutterPcmSound.feed(PcmArrayInt16.fromList(chunk));
      } catch (e) {
        // Ignore feed errors
      }
    } else {
      // Buffer underrun: feed remaining samples padded with silence, and re-enter buffering state
      final List<int> chunk = List<int>.from(_audioQueue);
      final int silenceNeeded = framesToFeed - chunk.length;
      chunk.addAll(List.filled(silenceNeeded, 0));
      _audioQueue.clear();
      _isBuffering = true;
      try {
        await FlutterPcmSound.feed(PcmArrayInt16.fromList(chunk));
      } catch (e) {
        // Ignore feed errors
      }
    }
  }

  // ២. ចាប់ផ្ដើមថតសំឡេងជាទម្រង់ PCM 16-bit, 16000Hz mono (PTT Talk)
  Future<void> startRecording(Function(Uint8List) onDataReceived) async {
    if (!_isRecorderInitialized) return;

    // Clean up any existing recording/subscription to prevent leaks
    await stopRecording();

    if (_recorder == null) {
      _recorder = FlutterSoundRecorder();
    }
    await _recorder!.openRecorder();

    _onDataReceivedCallback = onDataReceived;
    _accumulationBuffer.clear();

    _recordingStreamController = StreamController<Uint8List>();
    _recordingSubscription = _recordingStreamController!.stream.listen((bytes) {
      _accumulationBuffer.addAll(bytes);
      // We packetize into chunks of 4096 bytes (2048 samples / 128ms)
      // to make it much easier for the Web Audio API on the PC browser to play back smoothly
      while (_accumulationBuffer.length >= 4096) {
        final Uint8List packet = Uint8List.fromList(_accumulationBuffer.sublist(0, 4096));
        _accumulationBuffer.removeRange(0, 4096);
        _onDataReceivedCallback?.call(packet);
      }
    });

    await _recorder!.startRecorder(
      toStream: _recordingStreamController!.sink,
      codec: Codec.pcm16,
      audioSource: AudioSource.microphone, // ប្រើប្រាស់ microphone ធម្មតាដើម្បីជៀសវាង hardware echo canceler កាត់សំឡេងដំបូងៗឱ្យរអាក់រអួល
      numChannels: 1,
      sampleRate: 16000,
    );

    // Force speakerphone ON immediately after starting recording
    try {
      await _setSpeakerphone(true);
    } catch (e) {
      print("[AudioService] Failed to set speakerphone on record: $e");
    }
  }

  // ៣. បញ្ឈប់ការថតសំឡេង (PTT Release)
  Future<void> stopRecording() async {
    if (!_isRecorderInitialized) return;

    // Cancel subscription first so no more data callbacks are fired
    await _recordingSubscription?.cancel();
    await _recordingStreamController?.close();
    _recordingSubscription = null;
    _recordingStreamController = null;

    // Flush remaining bytes in accumulation buffer as a final packet
    if (_accumulationBuffer.isNotEmpty && _onDataReceivedCallback != null) {
      if (_accumulationBuffer.length % 2 != 0) {
        _accumulationBuffer.add(0);
      }
      _onDataReceivedCallback?.call(Uint8List.fromList(_accumulationBuffer));
      _accumulationBuffer.clear();
    }
    _onDataReceivedCallback = null;

    try {
      if (_recorder != null) {
        if (_recorder!.isRecording) {
          await _recorder!.stopRecorder();
        }
        await _recorder!.closeRecorder();
      }
    } catch (e) {
      // Ignore recorder state errors if already stopped
      print("[AudioService] Error stopping recorder: $e");
    }
  }

  // ៤. ចាប់ផ្ដើមការចាក់សំឡេងពី Stream (Start Playback Stream)
  Future<void> startPlaybackStream() async {
    if (!_isPlayerInitialized) return;
    // Reset buffering state so we wait for real audio samples before playing
    _isBuffering = true;
    _isPlaying = true;
    _audioQueue.clear();
    try {
      await FlutterPcmSound.play();
    } catch (e) {
      print("[AudioService] Error starting playback stream: $e");
    }
  }

  // ៥. ចាក់កញ្ចប់សំឡេង PCM Binary (Play Chunk)
  Future<void> playChunk(Uint8List chunk) async {
    if (!_isPlayerInitialized || isMuted) return;
    try {
      // Safely convert Uint8List bytes to Int16List (16-bit PCM samples) to prevent alignment errors
      final byteData = chunk.buffer.asByteData(chunk.offsetInBytes, chunk.length);
      final int16List = Int16List(chunk.length ~/ 2);
      for (int i = 0; i < int16List.length; i++) {
        int16List[i] = byteData.getInt16(i * 2, Endian.little);
      }
      
      _audioQueue.addAll(int16List);

      // Latency mitigation: if queue builds up more than 6400 samples (400ms),
      // discard the oldest samples to catch up to real-time.
      if (_audioQueue.length > 6400) {
        _audioQueue.removeRange(0, _audioQueue.length - 1600);
      }

      // Start the player once if it's not already playing
      if (!_isPlaying) {
        _isPlaying = true;
        _isBuffering = true; // Start in buffering state to accumulate initial samples
        await startPlaybackStream();
      }
    } catch (e) {
      print("[AudioService] Error playing pcm chunk: $e");
    }
  }

  // ៦. បញ្ឈប់ការចាក់សំឡេងពី Stream
  Future<void> stopPlaybackStream() async {
    if (!_isPlayerInitialized) return;
    _isPlaying = false;
    _isBuffering = false;
    try {
      await FlutterPcmSound.stop();
    } catch (e) {
      print("[AudioService] Error stopping playback stream: $e");
    }
    _audioQueue.clear();
  }

  // ៧. បិទសំឡេង (Mute/Unmute toggle)
  void setMute(bool mute) {
    isMuted = mute;
    if (mute) {
      _audioQueue.clear();
    }
  }

  bool _wasStreamPlayingBeforeUrl = false;

  // ៧b. ចាក់សំឡេងពី URL (សម្រាប់សារសំឡេង PTT ដែលបានរក្សាទុក)
  Future<void> playUrl(String url, {required Function() onFinished}) async {
    // Stop PcmSound stream player first on iOS/Android to prevent native crash
    if (_isPlaying) {
      _wasStreamPlayingBeforeUrl = true;
      await stopPlaybackStream();
    } else {
      _wasStreamPlayingBeforeUrl = false;
    }

    if (_urlPlayer == null) {
      _urlPlayer = FlutterSoundPlayer();
      await _urlPlayer!.openPlayer();
    }

    if (_urlPlayer!.isPlaying) {
      await _urlPlayer!.stopPlayer();
    }

    try {
      await _setSpeakerphone(true);
      await _urlPlayer!.startPlayer(
        fromURI: url,
        whenFinished: () async {
          onFinished();
          // Restart PcmSound stream player if it was active
          if (_wasStreamPlayingBeforeUrl) {
            _wasStreamPlayingBeforeUrl = false;
            await startPlaybackStream();
          }
        },
      );
      // Extra safety: re-apply speakerphone after starting player to ensure it takes effect
      await _setSpeakerphone(true);
    } catch (e) {
      print("[AudioService] Error playing URL $url: $e");
      onFinished();
      if (_wasStreamPlayingBeforeUrl) {
        _wasStreamPlayingBeforeUrl = false;
        await startPlaybackStream();
      }
    }
  }

  Future<void> stopUrlPlayer() async {
    if (_urlPlayer != null && _urlPlayer!.isPlaying) {
      await _urlPlayer!.stopPlayer();
    }
    // Restart PcmSound stream player if it was active before URL play
    if (_wasStreamPlayingBeforeUrl) {
      _wasStreamPlayingBeforeUrl = false;
      await startPlaybackStream();
    }
  }

  // ៨. សម្អាតធនធាន (Dispose)
  Future<void> dispose() async {
    await stopRecording();
    await stopPlaybackStream();
    await stopUrlPlayer();

    if (_recorder != null) {
      await _recorder!.closeRecorder();
      _recorder = null;
    }
    if (_urlPlayer != null) {
      await _urlPlayer!.closePlayer();
      _urlPlayer = null;
    }
    try {
      await FlutterPcmSound.release();
    } catch (e) {
      print("[AudioService] Error releasing PcmSound: $e");
    }
    await _setSpeakerphone(false);
    _isRecorderInitialized = false;
    _isPlayerInitialized = false;
  }
}
