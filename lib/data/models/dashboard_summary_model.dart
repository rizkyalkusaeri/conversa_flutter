class RecentThreadModel {
  final int id;
  final String title;
  final String createdAt;
  final String authorName;

  RecentThreadModel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.authorName,
  });

  factory RecentThreadModel.fromJson(Map<String, dynamic> json) {
    return RecentThreadModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      createdAt: json['created_at'] ?? '',
      authorName: json['author_name'] ?? 'Unknown',
    );
  }
}

class DashboardSummaryModel {
  final int activeSessionsCount;
  final int resolvedSessionsCount;
  final int unreadChatsCount;
  final List<RecentThreadModel> recentThreads;

  DashboardSummaryModel({
    required this.activeSessionsCount,
    required this.resolvedSessionsCount,
    required this.unreadChatsCount,
    required this.recentThreads,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    return DashboardSummaryModel(
      activeSessionsCount: json['active_sessions_count'] ?? 0,
      resolvedSessionsCount: json['resolved_sessions_count'] ?? 0,
      unreadChatsCount: json['unread_chats_count'] ?? 0,
      recentThreads: (json['recent_threads'] as List<dynamic>?)
              ?.map((e) => RecentThreadModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
