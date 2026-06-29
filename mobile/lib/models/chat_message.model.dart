class ChatMessage {
  final int? id;
  final String sender;
  final String type; // 'chat', 'file', 'voice', 'system'
  final String? text;
  final String? fileName;
  final String? fileType;
  final String? fileData; // base64 for live WebSocket transfers
  final String? filePath; // public URL path for stored files/voices
  final bool isMe;
  final DateTime? createdAt;

  ChatMessage({
    this.id,
    required this.sender,
    required this.type,
    this.text,
    this.fileName,
    this.fileType,
    this.fileData,
    this.filePath,
    required this.isMe,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String currentUsername) {
    int? idVal = json['id'];
    
    String senderVal = 'System';
    if (json['sender'] != null) {
      if (json['sender'] is Map) {
        senderVal = json['sender']['name'] ?? 'System';
      } else {
        senderVal = json['sender'].toString();
      }
    } else if (json['sender_name'] != null) {
      senderVal = json['sender_name'].toString();
    }

    DateTime? timeVal;
    if (json['created_at'] != null) {
      timeVal = DateTime.tryParse(json['created_at'].toString());
    }

    return ChatMessage(
      id: idVal,
      sender: senderVal,
      type: json['type'] ?? 'chat',
      text: json['text'],
      fileName: json['file_name'],
      fileType: json['file_type'],
      fileData: json['file_data'],
      filePath: json['file_path'],
      isMe: senderVal.toLowerCase() == currentUsername.toLowerCase(),
      createdAt: timeVal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'type': type,
      'text': text,
      'file_name': fileName,
      'file_type': fileType,
      'file_data': fileData,
      'file_path': filePath,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
