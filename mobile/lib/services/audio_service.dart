import 'dart:async';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

class AudioService {
  static const _channel = MethodChannel('com.example.mobile/audio');

  Future<void> _setAndroidSpeakerphone(bool enable) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setSpeakerphoneOn', {'enable': enable});
      print("[AudioService] Set android speakerphone to: $enable");
    } catch (e) {
      print("[AudioService] Failed to set speakerphone: $e");
    }
  }
  FlutterSoundRecorder? _recorder;
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
        avAudioSessionMode: AVAudioSessionMode.videoChat,
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

    await _recorder!.openRecorder();
    _isRecorderInitialized = true;

    // Initialize flutter_pcm_sound for output stream
    try {
      await FlutterPcmSound.setup(
        sampleRate: 16000,
        channelCount: 1,
      );
      await FlutterPcmSound.setFeedThreshold(800); // Trigger callback when remaining samples < 800
      FlutterPcmSound.setFeedCallback(_onFeed);
      _isPlayerInitialized = true;
      await _setAndroidSpeakerphone(true);
    } catch (e) {
      print("[AudioService] Failed to initialize PcmSound player: $e");
    }
  }

  // Callback to feed samples dynamically to AudioTrack
  void _onFeed(int remainingFrames) async {
    final int framesToFeed = remainingFrames > 0 ? remainingFrames : 800;
    
    // If buffering or queue has fewer samples than requested, feed silence (zeros)
    if (_isBuffering || _audioQueue.length < framesToFeed) {
      _isBuffering = true;
      try {
        await FlutterPcmSound.feed(PcmArrayInt16.fromList(List.filled(framesToFeed, 0)));
      } catch (e) {
        // Ignore feed errors
      }
      return;
    }

    final List<int> chunk = _audioQueue.sublist(0, framesToFeed);
    _audioQueue.removeRange(0, framesToFeed);
    
    try {
      await FlutterPcmSound.feed(PcmArrayInt16.fromList(chunk));
    } catch (e) {
      // Ignore feed errors
    }
  }

  // ២. ចាប់ផ្ដើមថតសំឡេងជាទម្រង់ PCM 16-bit, 16000Hz mono (PTT Talk)
  Future<void> startRecording(Function(Uint8List) onDataReceived) async {
    if (!_isRecorderInitialized) return;

    // Clean up any existing recording/subscription to prevent leaks
    await stopRecording();

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
      audioSource: AudioSource.voice_communication,
      numChannels: 1,
      sampleRate: 16000,
    );

    // Force speakerphone ON immediately after starting recording
    try {
      await _setAndroidSpeakerphone(true);
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
      if (_recorder!.isRecording) {
        await _recorder!.stopRecorder();
      }
    } catch (e) {
      // Ignore recorder state errors if already stopped
      print("[AudioService] Error stopping recorder: $e");
    }
  }

  // ៤. ចាប់ផ្ដើមការចាក់សំឡេងពី Stream (Start Playback Stream)
  Future<void> startPlaybackStream() async {
    if (!_isPlayerInitialized) return;
    _isPlaying = true;
    try {
      await FlutterPcmSound.play();
      // Force speakerphone ON immediately after starting playback
      await _setAndroidSpeakerphone(true);
    } catch (e) {
      print("[AudioService] Error starting playback stream: $e");
    }
  }

  // ៥. ចាក់កញ្ចប់សំឡេង PCM Binary (Play Chunk)
  Future<void> playChunk(Uint8List chunk) async {
    if (!_isPlayerInitialized || isMuted) return;
    try {
      // Convert Uint8List bytes to Int16List (16-bit PCM samples)
      final int16List = Int16List.view(
        chunk.buffer,
        chunk.offsetInBytes,
        chunk.lengthInBytes ~/ 2,
      );
      
      _audioQueue.addAll(int16List);

      // Latency mitigation: if queue builds up more than 8000 samples (500ms),
      // discard the oldest samples to catch up to real-time.
      if (_audioQueue.length > 8000) {
        _audioQueue.removeRange(0, _audioQueue.length - 4000);
      }

      // Exit buffering state if we have accumulated enough samples (e.g. 3200 samples = 200ms)
      if (_isBuffering && _audioQueue.length >= 3200) {
        _isBuffering = false;
        // Make sure speakerphone is still forced on during state changes
        _setAndroidSpeakerphone(true).catchError((_) {});
      }

      // Start the player once if it's not already playing
      if (!_isPlaying && _audioQueue.length >= 1600) {
        _isPlaying = true;
        _isBuffering = false;
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

  // ៨. សម្អាតធនធាន (Dispose)
  Future<void> dispose() async {
    await stopRecording();
    await stopPlaybackStream();

    if (_recorder != null) {
      await _recorder!.closeRecorder();
      _recorder = null;
    }
    try {
      await FlutterPcmSound.release();
    } catch (e) {
      print("[AudioService] Error releasing PcmSound: $e");
    }
    await _setAndroidSpeakerphone(false);
    _isRecorderInitialized = false;
    _isPlayerInitialized = false;
  }
}
