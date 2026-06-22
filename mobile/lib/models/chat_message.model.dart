class ChatMessage {
  final String sender;
  final String type; // 'chat', 'file', 'system'
  final String? text;
  final String? fileName;
  final String? fileType;
  final String? fileData;
  final bool isMe;

  ChatMessage({
    required this.sender,
    required this.type,
    this.text,
    this.fileName,
    this.fileType,
    this.fileData,
    required this.isMe,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String currentUsername) {
    String senderVal = json['sender'] ?? 'System';
    return ChatMessage(
      sender: senderVal,
      type: json['type'] ?? 'chat',
      text: json['text'],
      fileName: json['file_name'],
      fileType: json['file_type'],
      fileData: json['file_data'],
      isMe: senderVal.toLowerCase() == currentUsername.toLowerCase(),
    );
  }
}
