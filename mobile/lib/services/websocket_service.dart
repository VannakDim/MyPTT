import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  // 🟢 កំណត់អាសយដ្ឋាន IP សម្រាប់តភ្ជាប់ទៅ Voice Server (FastAPI)
  static const String wsUrl = "ws://192.168.100.11:9000";

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
    _channel!.sink.add(jsonEncode(payload));
  }

  // ៣. ផ្ញើកញ្ចប់សំឡេងជាទម្រង់ Binary PCM (Send Audio Bytes)
  void sendAudio(Uint8List audioBytes) {
    if (_channel == null || !isConnected) return;
    _channel!.sink.add(audioBytes);
  }

  // ៤. ផ្ដាច់ការតភ្ជាប់ (Disconnect)
  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    isConnected = false;
  }
}
