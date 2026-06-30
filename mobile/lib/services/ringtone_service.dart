import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';

/// Plays short audio alerts for:
/// - Incoming call ring tone (looping beep)
/// - PTT start beep (quick chirp)
/// Uses programmatically generated PCM audio — no asset files needed.
class RingtoneService {
  static final RingtoneService _instance = RingtoneService._internal();
  factory RingtoneService() => _instance;
  RingtoneService._internal();

  FlutterSoundPlayer? _player;
  bool _isRinging = false;

  /// Initialize the player
  Future<void> initialize() async {
    _player = FlutterSoundPlayer();
    await _player!.openPlayer();
    debugPrint('[RingtoneService] Initialized');
  }

  /// Play a call ring tone using the system's default ringtone (looping) and vibrate
  Future<void> startRinging() async {
    if (_isRinging) return;
    _isRinging = true;
    try {
      await FlutterRingtonePlayer().playRingtone(
        looping: true,
        asAlarm: false,
      );
      // រំញ័រជារង្វង់រៀងរាល់ការរោទិ៍ (Vibrate pattern: delay 500ms, vibrate 1000ms, repeat)
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
      }
      debugPrint('[RingtoneService] System ringtone and vibration started');
    } catch (e) {
      debugPrint('[RingtoneService] startRinging error: $e. Falling back to custom beep.');
      _playFallbackRinging();
    }
  }

  /// Helper to play custom looping beep as fallback
  Future<void> _playFallbackRinging() async {
    if (!_isRinging || _player == null) return;
    try {
      final pcm = _generateTone(
        frequency: 880,
        durationMs: 600,
        sampleRate: 16000,
        amplitude: 0.6,
      );
      await _player!.startPlayer(
        fromDataBuffer: pcm,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
        whenFinished: () async {
          if (_isRinging) {
            await Future.delayed(const Duration(milliseconds: 400));
            if (_isRinging) _playFallbackRinging();
          }
        },
      );
    } catch (e) {
      debugPrint('[RingtoneService] Fallback ringtone error: $e');
    }
  }

  /// Stop the ring tone and vibration
  Future<void> stopRinging() async {
    _isRinging = false;
    try {
      await FlutterRingtonePlayer().stop();
      await Vibration.cancel();
      if (_player?.isPlaying == true) {
        await _player!.stopPlayer();
      }
      debugPrint('[RingtoneService] Ringtone and vibration stopped');
    } catch (e) {
      debugPrint('[RingtoneService] stopRinging error: $e');
    }
  }

  /// Play a short "PTT start" chirp (440Hz, 100ms)
  Future<void> playPttBeep() async {
    if (_player == null) return;
    try {
      final pcm = _generateTone(
        frequency: 1200,
        durationMs: 80,
        sampleRate: 16000,
        amplitude: 0.5,
      );
      await _player!.startPlayer(
        fromDataBuffer: pcm,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
      );
    } catch (e) {
      debugPrint('[RingtoneService] playPttBeep error: $e');
    }
  }

  /// Play a short "message received" notification beep (two-tone) and vibrate
  Future<void> playMessageBeep() async {
    // ញ័រទូរស័ព្ទមួយខ្សឹបពេលមានសារថ្មី (Vibrate briefly for message)
    try {
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(duration: 300);
      }
    } catch (e) {
      debugPrint('[RingtoneService] Message vibration error: $e');
    }

    if (_player == null) return;
    try {
      final pcm = _generateTwoTone(
        freq1: 880,
        freq2: 1100,
        toneDurationMs: 80,
        gapMs: 40,
        sampleRate: 16000,
        amplitude: 0.4,
      );
      await _player!.startPlayer(
        fromDataBuffer: pcm,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
      );
    } catch (e) {
      debugPrint('[RingtoneService] playMessageBeep error: $e. Falling back to system notification sound.');
      try {
        await FlutterRingtonePlayer().playNotification();
      } catch (ne) {
        debugPrint('[RingtoneService] Fallback system notification sound error: $ne');
      }
    }
  }

  /// Dispose
  Future<void> dispose() async {
    _isRinging = false;
    try {
      await Vibration.cancel();
      await _player?.closePlayer();
    } catch (_) {}
    _player = null;
  }

  // ─── PCM Generation Helpers ─────────────────────────────────────────────────

  /// Generate a single sine-wave tone as raw 16-bit PCM bytes
  Uint8List _generateTone({
    required double frequency,
    required int durationMs,
    required int sampleRate,
    double amplitude = 0.5,
  }) {
    final int totalSamples = (sampleRate * durationMs ~/ 1000);
    final Uint8List bytes = Uint8List(totalSamples * 2);
    int idx = 0;
    for (int i = 0; i < totalSamples; i++) {
      // Fade in/out over 10ms to avoid clicks
      double env = 1.0;
      final fadeSamples = sampleRate * 10 ~/ 1000;
      if (i < fadeSamples) env = i / fadeSamples;
      if (i > totalSamples - fadeSamples) env = (totalSamples - i) / fadeSamples;

      final double sample = amplitude * env * sin(2 * pi * frequency * i / sampleRate);
      final int pcm = (sample * 32767).clamp(-32768, 32767).round();
      bytes[idx++] = pcm & 0xFF;        // Low byte
      bytes[idx++] = (pcm >> 8) & 0xFF; // High byte
    }
    return bytes;
  }

  /// Generate two sequential tones (tone1 + gap + tone2)
  Uint8List _generateTwoTone({
    required double freq1,
    required double freq2,
    required int toneDurationMs,
    required int gapMs,
    required int sampleRate,
    double amplitude = 0.5,
  }) {
    final tone1 = _generateTone(frequency: freq1, durationMs: toneDurationMs, sampleRate: sampleRate, amplitude: amplitude);
    final gapSamples = sampleRate * gapMs ~/ 1000 * 2;
    final tone2 = _generateTone(frequency: freq2, durationMs: toneDurationMs, sampleRate: sampleRate, amplitude: amplitude);
    final result = Uint8List(tone1.length + gapSamples + tone2.length);
    result.setRange(0, tone1.length, tone1);
    // gap is already zeros
    result.setRange(tone1.length + gapSamples, result.length, tone2);
    return result;
  }
}
