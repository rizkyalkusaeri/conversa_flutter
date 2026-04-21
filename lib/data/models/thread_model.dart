import 'package:fifgroup_android_ticketing/data/models/comment_model.dart';

class ThreadAuthor {
  final int? id;
  final String name;
  final String? role;

  ThreadAuthor({this.id, required this.name, this.role});

  factory ThreadAuthor.fromJson(Map<String, dynamic> json) {
    return ThreadAuthor(
      id: json['id'],
      name: json['name'] ?? 'User',
      role: json['role'],
    );
  }
}

class ThreadAttachment {
  final int id;
  final String? originalName;
  final String? fileType;
  final String? url;

  ThreadAttachment({
    required this.id,
    this.originalName,
    this.fileType,
    this.url,
  });

  factory ThreadAttachment.fromJson(Map<String, dynamic> json) {
    return ThreadAttachment(
      id: json['id'] ?? 0,
      originalName: json['original_name'],
      fileType: json['file_type'],
      url: json['url'],
    );
  }

  bool get isImage {
    if (fileType == null) return false;
    return fileType!.startsWith('image/');
  }
}

class ThreadModel {
  final String id;
  final String content;
  final String? status;
  final DateTime? createdAt;
  final ThreadAuthor author;
  final int likesCount;
  final int commentsCount;
  final bool isLikedByMe;
  final List<ThreadAttachment> attachments;
  final List<CommentModel>? comments;

  ThreadModel({
    required this.id,
    required this.content,
    this.status,
    this.createdAt,
    required this.author,
    required this.likesCount,
    required this.commentsCount,
    required this.isLikedByMe,
    required this.attachments,
    this.comments,
  });

  factory ThreadModel.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? {};

    return ThreadModel(
      id: json['id']?.toString() ?? '',
      content: json['content'] ?? '',
      status: json['status'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      author: ThreadAuthor.fromJson(json['author'] ?? {}),
      likesCount: stats['likes_count'] ?? 0,
      commentsCount: stats['comments_count'] ?? 0,
      isLikedByMe: json['is_liked_by_me'] == true || json['is_liked_by_me'] == 1,
      attachments: (json['attachments'] as List<dynamic>?)?.map((e) {
            if (e is Map<String, dynamic>) {
              return ThreadAttachment.fromJson(e);
            }
            final url = e.toString();
            final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp']
                .any((ext) => url.toLowerCase().endsWith(ext));
            return ThreadAttachment(
              id: 0,
              url: url,
              fileType: isImage ? 'image/unknown' : 'application/octet-stream',
              originalName: url.split('/').last,
            );
          }).toList() ??
          [],
      comments: json['comments'] != null
          ? (json['comments'] as List<dynamic>)
              .map((e) =>
                  CommentModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  /// Create a copy with toggled like state (for optimistic update)
  ThreadModel copyWithLikeToggled() {
    return ThreadModel(
      id: id,
      content: content,
      status: status,
      createdAt: createdAt,
      author: author,
      likesCount: isLikedByMe ? likesCount - 1 : likesCount + 1,
      commentsCount: commentsCount,
      isLikedByMe: !isLikedByMe,
      attachments: attachments,
      comments: comments,
    );
  }
}
