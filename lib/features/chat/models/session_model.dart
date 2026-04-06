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
  final String? requesterName;
  final int? requesterId;
  final String? resolverName;
  final int? resolverId;
  final DateTime? createdAt;
  final DateTime? closedAt;
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
    this.requesterName,
    this.requesterId,
    this.resolverName,
    this.resolverId,
    this.createdAt,
    this.closedAt,
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
      requesterName: json['requester']?['name'],
      requesterId: json['requester']?['id'],
      resolverName: json['resolver']?['name'],
      resolverId: json['resolver']?['id'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      closedAt: json['closed_at'] != null ? DateTime.tryParse(json['closed_at']) : null,
      rating: json['rating'],
      feedback: json['feedback'],
      unreadCount: json['unread_count'] ?? 0,
      latestChat: json['latest_chat'] != null ? LatestChatModel.fromJson(json['latest_chat']) : null,
    );
  }
}
