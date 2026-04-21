import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:fifgroup_android_ticketing/data/models/comment_model.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/api_config.dart';
import '../../../../features/chat/ui/widgets/full_screen_image_viewer.dart';
import 'package:fifgroup_android_ticketing/data/models/thread_model.dart';

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

            // Attachments
            if (comment.attachments.isNotEmpty)
              _buildAttachments(context, comment.attachments),

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

  Widget _buildAttachments(
    BuildContext context,
    List<ThreadAttachment> attachments,
  ) {
    return Padding(
      padding: EdgeInsets.only(left: isNested ? 36 : 40, top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Images
          if (attachments.any((a) => a.isImage))
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: attachments.where((a) => a.isImage).toList().asMap().entries.map((entry) {
                final idx = entry.key;
                final att = entry.value;
                // Use comment.id + index to guarantee a globally unique hero tag
                // (att.id is 0 for comment attachments since they're stored as JSON paths)
                final uniqueTag = 'comment_image_${comment.id}_$idx';
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => FullScreenImageViewer(
                              imageUrl: '${ApiConfig.imageUrl}${att.url}',
                              heroTag: uniqueTag,
                            ),
                      ),
                    );
                  },
                  child: Hero(
                    tag: uniqueTag,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: '${ApiConfig.imageUrl}${att.url}',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image),
                            ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

          if (attachments.any((a) => a.isImage) &&
              attachments.any((a) => !a.isImage))
            const SizedBox(height: 8),

          // Files
          if (attachments.any((a) => !a.isImage))
            ...attachments.where((a) => !a.isImage).map((att) {
              return GestureDetector(
                onTap: () => _launchURL('${ApiConfig.imageUrl}${att.url}'),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attach_file,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          att.originalName ?? 'File',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
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
