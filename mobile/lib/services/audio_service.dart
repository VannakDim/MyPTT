import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;

  bool isMuted = false;
  StreamController<Uint8List>? _recordingStreamController;
  StreamSubscription<Uint8List>? _recordingSubscription;

  // ១. ផ្ដួចផ្ដើមសេវាកម្មសំឡេង (Initialization)
  Future<void> initialize({bool requestPermission = true}) async {
    if (requestPermission) {
      // ស្នើសុំសិទ្ធិប្រើប្រាស់ Microphone
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception("Microphone permission not granted");
      }
    }

    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();

    await _recorder!.openRecorder();
    _isRecorderInitialized = true;

    await _player!.openPlayer();
    _isPlayerInitialized = true;

    // កំណត់ទំហំ Buffer សម្រាប់ការចាក់សំឡេងកុំឱ្យរអាក់រអួល
    await _player!.setSubscriptionDuration(const Duration(milliseconds: 10));
  }

  // ២. ចាប់ផ្ដើមថតសំឡេងជាទម្រង់ PCM 16-bit, 16000Hz mono (PTT Talk)
  Future<void> startRecording(Function(Uint8List) onDataReceived) async {
    if (!_isRecorderInitialized) return;

    _recordingStreamController = StreamController<Uint8List>();
    _recordingSubscription = _recordingStreamController!.stream.listen((buffer) {
      onDataReceived(buffer);
    });

    await _recorder!.startRecorder(
      toStream: _recordingStreamController!.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
    );
  }

  // ៣. បញ្ឈប់ការថតសំឡេង (PTT Release)
  Future<void> stopRecording() async {
    if (!_isRecorderInitialized) return;
    try {
      await _recorder!.stopRecorder();
    } catch (e) {
      // Ignore recorder state errors if already stopped
    }

    await _recordingSubscription?.cancel();
    await _recordingStreamController?.close();
    _recordingSubscription = null;
    _recordingStreamController = null;
  }

  // ៤. ចាប់ផ្ដើមការចាក់សំឡេងពី Stream (Start Playback Stream)
  Future<void> startPlaybackStream() async {
    if (!_isPlayerInitialized) return;
    await _player!.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
      bufferSize: 8192,
      interleaved: true,
    );
  }

  // ៥. ចាក់កញ្ចប់សំឡេង PCM Binary (Play Chunk)
  Future<void> playChunk(Uint8List chunk) async {
    if (!_isPlayerInitialized || isMuted) return;
    try {
      if (_player!.uint8ListSink != null) {
        _player!.uint8ListSink!.add(chunk);
      }
    } catch (e) {
      // Audio stream playback warnings ignored for continuous stream
    }
  }

  // ៦. បញ្ឈប់ការចាក់សំឡេងពី Stream
  Future<void> stopPlaybackStream() async {
    if (!_isPlayerInitialized) return;
    await _player!.stopPlayer();
  }

  // ៧. បិទសំឡេង (Mute/Unmute toggle)
  void setMute(bool mute) {
    isMuted = mute;
    if (_isPlayerInitialized) {
      _player!.setVolume(mute ? 0.0 : 1.0);
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
    if (_player != null) {
      await _player!.closePlayer();
      _player = null;
    }
    _isRecorderInitialized = false;
    _isPlayerInitialized = false;
  }
}
