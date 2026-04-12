class CommentAuthor {
  final int? id;
  final String name;
  final String? role;

  CommentAuthor({this.id, required this.name, this.role});

  factory CommentAuthor.fromJson(Map<String, dynamic> json) {
    return CommentAuthor(
      id: json['id'],
      name: json['name'] ?? 'User',
      role: json['role'],
    );
  }
}

class CommentModel {
  final int id;
  final String content;
  final List<String> attachments;
  final CommentAuthor author;
  final int likesCount;
  final int repliesCount;
  final bool isLikedByMe;
  final DateTime? createdAt;
  final List<CommentModel> replies;

  CommentModel({
    required this.id,
    required this.content,
    required this.attachments,
    required this.author,
    required this.likesCount,
    required this.repliesCount,
    required this.isLikedByMe,
    this.createdAt,
    required this.replies,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? {};

    return CommentModel(
      id: json['id'] ?? 0,
      content: json['content'] ?? '',
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      author: CommentAuthor.fromJson(json['author'] ?? {}),
      likesCount: stats['likes_count'] ?? 0,
      repliesCount: stats['replies_count'] ?? 0,
      isLikedByMe: json['is_liked_by_me'] == true || json['is_liked_by_me'] == 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      replies: (json['replies'] as List<dynamic>?)
              ?.map((e) =>
                  CommentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Create a copy with toggled like state (for optimistic update)
  CommentModel copyWithLikeToggled() {
    return CommentModel(
      id: id,
      content: content,
      attachments: attachments,
      author: author,
      likesCount: isLikedByMe ? likesCount - 1 : likesCount + 1,
      repliesCount: repliesCount,
      isLikedByMe: !isLikedByMe,
      createdAt: createdAt,
      replies: replies,
    );
  }
}
