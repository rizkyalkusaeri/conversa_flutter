import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:fifgroup_android_ticketing/data/models/comment_model.dart';
import 'package:intl/intl.dart';

class CommentTile extends StatelessWidget {
  final CommentModel comment;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final Function(int commentId) onLikeReply;
  final bool isNested;

  const CommentTile({
    super.key,
    required this.comment,
    required this.onLike,
    required this.onReply,
    required this.onLikeReply,
    this.isNested = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isNested ? 40 : 0,
        bottom: 4,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: isNested ? 14 : 16,
                  backgroundColor: isNested
                      ? Colors.grey.shade200
                      : AppColors.primaryContainer,
                  child: Text(
                    _getInitials(comment.author.name),
                    style: TextStyle(
                      color: isNested
                          ? Colors.grey.shade600
                          : AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: isNested ? 10 : 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.author.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isNested ? 12 : 13,
                            color: AppColors.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (comment.author.role != null) ...[
                        const SizedBox(width: 6),
                        _buildRoleBadge(comment.author.role!),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        _formatTimeAgo(comment.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: EdgeInsets.only(
                  left: isNested ? 36 : 40, top: 6),
              child: Text(
                comment.content,
                style: TextStyle(
                  fontSize: isNested ? 13 : 14,
                  color: AppColors.textDark,
                  height: 1.4,
                ),
              ),
            ),

            // Actions: Like + Reply
            Padding(
              padding: EdgeInsets.only(
                  left: isNested ? 32 : 36, top: 6),
              child: Row(
                children: [
                  InkWell(
                    onTap: onLike,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            comment.isLikedByMe
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                            size: 14,
                            color: comment.isLikedByMe
                                ? AppColors.primary
                                : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            comment.likesCount.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: comment.isLikedByMe
                                  ? AppColors.primary
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isNested) ...[
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: onReply,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.reply,
                                size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Nested replies
            if (comment.replies.isNotEmpty && !isNested) ...[
              const SizedBox(height: 4),
              ...comment.replies.map(
                (reply) => CommentTile(
                  comment: reply,
                  onLike: () => onLikeReply(reply.id),
                  onReply: () {},
                  onLikeReply: onLikeReply,
                  isNested: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    final isAdmin = role.toUpperCase() == 'ADMIN';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppColors.primary.withAlpha(25)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: isAdmin ? AppColors.primary : Colors.grey.shade600,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : 'U';
  }

  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';

    return DateFormat('dd MMM').format(dateTime);
  }
}
