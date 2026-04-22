import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_config.dart';
import 'package:fifgroup_android_ticketing/data/models/thread_model.dart';
import 'package:intl/intl.dart';

class ThreadCard extends StatelessWidget {
  final ThreadModel thread;
  final int? currentUserId;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback? onEdit;

  const ThreadCard({
    super.key,
    required this.thread,
    required this.currentUserId,
    required this.onTap,
    required this.onLike,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar + Author + Time + Menu
            _buildHeader(context),
            const SizedBox(height: 10),

            // Content text
            Text(
              thread.content,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.5,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),

            // Attachments (images)
            if (_imageAttachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildAttachmentGrid(),
            ],

            const SizedBox(height: 12),

            // Action bar: Like + Comment
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  List<ThreadAttachment> get _imageAttachments =>
      thread.attachments.where((a) => a.isImage).toList();

  Widget _buildHeader(BuildContext context) {
    final initials = _getInitials(thread.author.name);
    final isOwner = currentUserId != null && thread.author.id == currentUserId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primaryContainer,
          child: Text(
            initials,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Author info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      thread.author.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '• ${_formatTimeAgo(thread.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              if (thread.visibleToLevels.isNotEmpty) ...[
                const SizedBox(height: 4),
                Builder(builder: (context) {
                  const maxDisplay = 3;
                  final displayList = thread.visibleToLevels.take(maxDisplay).toList();
                  final remainingCount = thread.visibleToLevels.length - maxDisplay;

                  return Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ...displayList.map((level) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          level,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      )),
                      if (remainingCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '+$remainingCount lainnya',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  );
                }),
              ],
            ],
          ),
        ),

        // Menu (edit — only for owner)
        if (isOwner && onEdit != null)
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit!();
            },
            icon: Icon(Icons.more_horiz, color: Colors.grey.shade400, size: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18, color: AppColors.textDark),
                    SizedBox(width: 8),
                    Text('Edit Thread'),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }


  Widget _buildAttachmentGrid() {
    final images = _imageAttachments;

    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildNetworkImage(images[0].url!, height: 200),
      );
    }

    // Multiple images: show first 2 with +N overlay
    return SizedBox(
      height: 160,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
              child: _buildNetworkImage(images[0].url!, height: 160),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(12),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildNetworkImage(images[1].url!, height: 160),
                  if (images.length > 2)
                    Container(
                      color: Colors.black45,
                      child: Center(
                        child: Text(
                          '+${images.length - 2}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkImage(String relativeUrl, {double? height}) {
    final fullUrl = '${ApiConfig.imageUrl}$relativeUrl';
    return Image.network(
      fullUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        height: height,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        // Like
        _buildActionButton(
          icon: thread.isLikedByMe ? Icons.thumb_up : Icons.thumb_up_outlined,
          label: thread.likesCount.toString(),
          color: thread.isLikedByMe ? AppColors.primary : Colors.grey.shade500,
          onTap: onLike,
        ),
        const SizedBox(width: 20),

        // Comments
        _buildActionButton(
          icon: Icons.chat_bubble_outline,
          label: thread.commentsCount.toString(),
          color: Colors.grey.shade500,
          onTap: onTap,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return DateFormat('dd MMM yyyy').format(dateTime);
  }
}
