class ChatMessageModel {
  final int id;
  final String? messageContent;
  final String? messageType; // TEXT, IMAGE, DOCUMENT, SYSTEM
  final String? systemMessageType;
  final String? attachmentUrl;
  final String? attachmentName;
  final bool isRead;
  final DateTime? createdAt;
  final int? senderId;
  final String? senderName;
  final int? parentId;
  final ChatMessageModel? parent;

  ChatMessageModel({
    required this.id,
    this.messageContent,
    this.messageType,
    this.systemMessageType,
    this.attachmentUrl,
    this.attachmentName,
    required this.isRead,
    this.createdAt,
    this.senderId,
    this.senderName,
    this.parentId,
    this.parent,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is double) return val.toInt();
      return int.tryParse(val.toString());
    }

    return ChatMessageModel(
      id: parseInt(json['id']) ?? 0,
      messageContent: json['message_content'],
      messageType: json['message_type'],
      systemMessageType: json['system_message_type'],
      attachmentUrl: json['attachment_url'],
      attachmentName: json['attachment_name'],
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']).toLocal() : null,
      senderId: parseInt(json['sender']?['id'] ?? json['sender_id']),
      senderName: json['sender']?['name'] ?? json['sender_name'],
      parentId: parseInt(json['parent_id']),
      parent: json['parent'] != null ? ChatMessageModel.fromJson(json['parent'] as Map<String, dynamic>) : null,
    );
  }

  bool get isImage => messageType == 'IMAGE';
  bool get isVideo => messageType == 'VIDEO';
}
