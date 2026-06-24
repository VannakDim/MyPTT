class ChatMessage {
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
    String senderVal = json['sender'] ?? json['sender_name'] ?? 'System';
    DateTime? timeVal;
    if (json['created_at'] != null) {
      timeVal = DateTime.tryParse(json['created_at'].toString());
    }

    return ChatMessage(
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
}
