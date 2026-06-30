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
  final List<String> seenBy;

  // Reply fields
  final int? replyToId;
  final String? replyToSender;
  final String? replyToText;
  final String? replyToType;
  final String? replyToFileName;

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
    this.seenBy = const [],
    this.replyToId,
    this.replyToSender,
    this.replyToText,
    this.replyToType,
    this.replyToFileName,
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

    // Parse seen_by list
    final List<String> seenByList = [];
    if (json['seen_by'] != null && json['seen_by'] is List) {
      for (final u in json['seen_by']) {
        if (u is Map && u['name'] != null) {
          seenByList.add(u['name'].toString());
        } else if (u is String) {
          seenByList.add(u);
        }
      }
    }

    // Parse reply_to from nested object
    int? replyToIdVal;
    String? replyToSenderVal;
    String? replyToTextVal;
    String? replyToTypeVal;
    String? replyToFileNameVal;

    if (json['reply_to'] != null && json['reply_to'] is Map) {
      final rt = json['reply_to'] as Map<String, dynamic>;
      replyToIdVal = rt['id'];
      replyToSenderVal = rt['sender_name']?.toString();
      replyToTextVal = rt['text']?.toString();
      replyToTypeVal = rt['type']?.toString();
      replyToFileNameVal = rt['file_name']?.toString();
    } else if (json['reply_to_id'] != null) {
      replyToIdVal = json['reply_to_id'];
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
      seenBy: seenByList,
      replyToId: replyToIdVal,
      replyToSender: replyToSenderVal,
      replyToText: replyToTextVal,
      replyToType: replyToTypeVal,
      replyToFileName: replyToFileNameVal,
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
      'seen_by': seenBy,
      'reply_to_id': replyToId,
      'reply_to': replyToSender != null ? {
        'id': replyToId,
        'sender_name': replyToSender,
        'text': replyToText,
        'type': replyToType,
        'file_name': replyToFileName,
      } : null,
    };
  }
}

