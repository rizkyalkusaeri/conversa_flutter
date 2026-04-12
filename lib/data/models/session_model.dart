class LatestChatModel {
  final int id;
  final String? message;
  final String? senderName;
  final DateTime? createdAt;

  LatestChatModel({
    required this.id,
    this.message,
    this.senderName,
    this.createdAt,
  });

  factory LatestChatModel.fromJson(Map<String, dynamic> json) {
    return LatestChatModel(
      id: json['id'] ?? 0,
      message: json['message'],
      senderName: json['sender']?['name'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}

class SessionModel {
  final String id;
  final String ticketNumber;
  final String? noAppl;
  final String? description;
  final String status;
  final String? categoryName;
  final String? subCategoryName;
  final String? topicName;
  final String? requesterName;
  final int? requesterId;
  final String? resolverName;
  final int? resolverId;
  final DateTime? createdAt;
  final DateTime? closedAt;
  final DateTime? closeRequestedAt;
  final int? closeRequestedBy;
  final DateTime? openRequestedAt;
  final int? openRequestedBy;
  final bool isHaveUniqueId;
  final int? rating;
  final String? feedback;
  final int unreadCount;
  final LatestChatModel? latestChat;

  SessionModel({
    required this.id,
    required this.ticketNumber,
    this.noAppl,
    this.description,
    required this.status,
    this.categoryName,
    this.subCategoryName,
    this.topicName,
    this.requesterName,
    this.requesterId,
    this.resolverName,
    this.resolverId,
    this.createdAt,
    this.closedAt,
    this.closeRequestedAt,
    this.closeRequestedBy,
    this.openRequestedAt,
    this.openRequestedBy,
    this.isHaveUniqueId = false,
    this.rating,
    this.feedback,
    required this.unreadCount,
    this.latestChat,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] ?? '',
      ticketNumber: json['ticket_number'] ?? '',
      noAppl: json['no_appl'],
      description: json['description'],
      status: json['status'] ?? 'UNKNOWN',
      categoryName: json['category_name'],
      subCategoryName: json['sub_category_name'],
      topicName: json['topic_name'],
      requesterName: json['requester']?['name'],
      requesterId: json['requester']?['id'],
      resolverName: json['resolver']?['name'],
      resolverId: json['resolver']?['id'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      closedAt: json['closed_at'] != null ? DateTime.tryParse(json['closed_at']) : null,
      closeRequestedAt: json['close_requested_at'] != null ? DateTime.tryParse(json['close_requested_at']) : null,
      closeRequestedBy: json['close_requested_by'],
      openRequestedAt: json['open_requested_at'] != null ? DateTime.tryParse(json['open_requested_at']) : null,
      openRequestedBy: json['open_requested_by'],
      isHaveUniqueId: json['is_have_unique_id'] == true || json['is_have_unique_id'] == 1,
      rating: json['rating'],
      feedback: json['feedback'],
      unreadCount: json['unread_count'] ?? 0,
      latestChat: json['latest_chat'] != null ? LatestChatModel.fromJson(json['latest_chat']) : null,
    );
  }
}
