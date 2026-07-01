import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:shared_preferences/shared_preferences.dart';

class WebSocketService {
  static String _customWsUrl = "ws://10.10.60.116:9005";

  static String get wsUrl => _customWsUrl;

  static void updateWsUrl(String newWsUrl) {
    _customWsUrl = newWsUrl;
  }

  static Future<void> loadSavedWsUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedWsUrl = prefs.getString('websocket_url');
    if (savedWsUrl != null && savedWsUrl.isNotEmpty) {
      _customWsUrl = savedWsUrl;
    }
  }

  WebSocketChannel? _channel;
  bool isConnected = false;

  // ១. បង្កើតការតភ្ជាប់ទៅកាន់ WebSocket (Connect)
  Future<void> connect({
    required String channelName,
    required String token,
    required Function(dynamic) onDataReceived,
    required Function() onDisconnected,
    required Function() onConnected,
  }) async {
    final url = '$wsUrl/ws/$channelName?token=$token';
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      isConnected = true;

      // Monitor connection readiness
      _channel!.ready.then((_) {
        onConnected();
      }).catchError((err) {
        print("[WS READY ERROR] $err");
        isConnected = false;
        onDisconnected();
      });

      _channel!.stream.listen(
        (data) {
          onDataReceived(data);
        },
        onError: (err) {
          print("[WS ERROR] $err");
          isConnected = false;
          onDisconnected();
        },
        onDone: () {
          print("[WS DONE] Connection closed");
          isConnected = false;
          onDisconnected();
        },
      );
    } catch (e) {
      print("[WS CONNECTION ERROR] $e");
      isConnected = false;
      onDisconnected();
    }
  }

  // ២. ផ្ញើសារអក្សរជាទម្រង់ JSON Frame (Send Action Command)
  void sendAction(String action, Map<String, dynamic> params) {
    if (_channel == null || !isConnected) return;
    final payload = {
      'action': action,
      ...params,
    };
    print("[WS Outgoing JSON] Action: $action, payload: $payload");
    _channel!.sink.add(jsonEncode(payload));
  }

  // ៣. ផ្ញើកញ្ចប់សំឡេងជាទម្រង់ Binary PCM (Send Audio Bytes) — ប្រើសម្រាប់ PTT group
  void sendAudio(Uint8List audioBytes) {
    if (_channel == null || !isConnected) return;
    print("[WS Outgoing Audio] Sending ${audioBytes.length} bytes");
    _channel!.sink.add(audioBytes);
  }

  // ៤. ផ្ញើសំឡេងការហៅ Private ចំគោលដៅ (Private Call Audio — JSON+base64, មិន broadcast)
  void sendPrivateAudio(Uint8List audioBytes, String targetUser) {
    if (_channel == null || !isConnected) return;
    final payload = {
      'action': 'call_audio',
      'target': targetUser,
      'audio': base64Encode(audioBytes),
    };
    _channel!.sink.add(jsonEncode(payload));
  }

  // ៥. ផ្ដាច់ការតភ្ជាប់ (Disconnect)
  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    isConnected = false;
  }
}
