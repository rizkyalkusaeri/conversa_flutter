class ChatMessageModel {
  final int id;
  final String? messageContent;
  final String? messageType; // TEXT, IMAGE, DOCUMENT, SYSTEM
  final String? systemMessageType;
  final String? attachmentUrl;
  final bool isRead;
  final DateTime? createdAt;
  final int? senderId;
  final String? senderName;

  ChatMessageModel({
    required this.id,
    this.messageContent,
    this.messageType,
    this.systemMessageType,
    this.attachmentUrl,
    required this.isRead,
    this.createdAt,
    this.senderId,
    this.senderName,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'],
      messageContent: json['message_content'],
      messageType: json['message_type'],
      systemMessageType: json['system_message_type'],
      attachmentUrl: json['attachment_url'],
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      senderId: json['sender']?['id'] ?? json['sender_id'],
      senderName: json['sender']?['name'] ?? json['sender_name'],
    );
  }
}
