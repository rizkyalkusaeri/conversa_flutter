import 'package:cached_network_image/cached_network_image.dart';
import 'package:fifgroup_android_ticketing/features/chat/ui/widgets/full_screen_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_config.dart';
import '../../auth/cubit/app_auth/app_auth_cubit.dart';
import '../../auth/cubit/app_auth/app_auth_state.dart';
import '../cubit/thread_detail_cubit.dart';
import '../cubit/thread_detail_state.dart';
import 'package:fifgroup_android_ticketing/data/models/thread_model.dart';
import 'package:fifgroup_android_ticketing/data/models/comment_model.dart';
import 'widgets/comment_tile.dart';
import 'create_thread_page.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../chat/ui/widgets/image_preview_dialog.dart';
import 'package:intl/intl.dart';

class ThreadDetailPage extends StatefulWidget {
  final String threadUuid;

  const ThreadDetailPage({super.key, required this.threadUuid});

  @override
  State<ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends State<ThreadDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  ThreadDetailCubit? _cubit; // Store reference to avoid context lookup in scroll listener
  int? _replyToCommentId;
  String? _replyToAuthorName;
  final List<File> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    // Trigger load more when 250px from bottom
    if (currentScroll >= maxScroll - 250) {
      final cubitState = _cubit?.state;
      if (cubitState is ThreadDetailLoaded &&
          cubitState.hasMoreComments &&
          !cubitState.isLoadingMoreComments) {
        _cubit?.loadComments(widget.threadUuid);
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  int? get _currentUserId {
    final authState = context.read<AppAuthCubit>().state;
    if (authState is AppAuthAuthenticated) {
      return authState.user.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        _cubit = ThreadDetailCubit()..loadThread(widget.threadUuid);
        return _cubit!;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Thread',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: BlocBuilder<ThreadDetailCubit, ThreadDetailState>(
          builder: (context, state) {
            if (state is ThreadDetailLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (state is ThreadDetailError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.grey.shade400,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context
                          .read<ThreadDetailCubit>()
                          .loadThread(widget.threadUuid),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            ThreadModel? thread;
            List<CommentModel> comments = [];
            bool isCommenting = false;
            bool isLoadingMore = false;
            bool hasMore = true;

            if (state is ThreadDetailLoaded) {
              thread = state.thread;
              comments = state.comments;
              isLoadingMore = state.isLoadingMoreComments;
              hasMore = state.hasMoreComments;
            } else if (state is ThreadDetailCommentPosting) {
              thread = state.thread;
              comments = state.comments;
              isCommenting = true;
            }

            if (thread == null) return const SizedBox.shrink();

            return Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () => context
                        .read<ThreadDetailCubit>()
                        .loadThread(widget.threadUuid),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Thread content
                          _buildThreadContent(context, thread),

                          // Divider
                          Container(height: 8, color: Colors.grey.shade50),

                          // Comments header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'Komentar (${thread.commentsCount})',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),

                          // Comments list (from paginated state)
                          if (comments.isNotEmpty)
                            ...comments.map(
                              (comment) => CommentTile(
                                comment: comment,
                                onLike: () => context
                                    .read<ThreadDetailCubit>()
                                    .toggleLikeComment(comment.id),
                                onReply: () {
                                  setState(() {
                                    _replyToCommentId = comment.id;
                                    _replyToAuthorName = comment.author.name;
                                  });
                                  _commentFocus.requestFocus();
                                },
                                onLikeReply: (replyId) => context
                                    .read<ThreadDetailCubit>()
                                    .toggleLikeComment(replyId),
                              ),
                            )
                          else if (!isLoadingMore)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Text(
                                  'Belum ada komentar.\nJadilah yang pertama berkomentar!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),

                          // Load-more footer
                          if (isLoadingMore)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else if (!hasMore && comments.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'Semua komentar sudah ditampilkan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),

                // Comment input bar
                _buildCommentInput(context, isCommenting),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildThreadContent(BuildContext context, ThreadModel thread) {
    final initials = _getInitials(thread.author.name);
    final isOwner =
        _currentUserId != null && thread.author.id == _currentUserId;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          thread.author.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (thread.visibleToLevels.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Builder(builder: (context) {
                            const maxDisplay = 5; // Detail page boleh lebih banyak
                            final displayList = thread.visibleToLevels.take(maxDisplay).toList();
                            final remainingCount = thread.visibleToLevels.length - maxDisplay;

                            return Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                ...displayList.map((level) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(25),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    level,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )),
                                if (remainingCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '+$remainingCount',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
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
                    const SizedBox(height: 2),
                    Text(
                      _formatDateTime(thread.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isOwner)
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  onPressed: () => _navigateToEdit(context, thread),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Content
          Text(
            thread.content,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textDark,
              height: 1.6,
            ),
          ),

          // Attachments
          if (thread.attachments.where((a) => a.isImage).isNotEmpty) ...[
            const SizedBox(height: 16),
            ...thread.attachments
                .where((a) => a.isImage)
                .map(
                  (att) => GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImageViewer(
                            imageUrl: '${ApiConfig.imageUrl}${att.url}',
                            heroTag: 'threads_image_${att.id}',
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: '${ApiConfig.imageUrl}${att.url}',
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            height: 150,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],

          // Non-image attachments
          if (thread.attachments.where((a) => !a.isImage).isNotEmpty) ...[
            const SizedBox(height: 12),
            ...thread.attachments
                .where((a) => !a.isImage)
                .map(
                  (att) => GestureDetector(
                    onTap: () =>
                        _openAttachment('${ApiConfig.imageUrl}${att.url}'),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_file,
                            size: 18,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              att.originalName ?? 'File',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],

          const SizedBox(height: 16),

          // Stats bar
          Row(
            children: [
              InkWell(
                onTap: () =>
                    context.read<ThreadDetailCubit>().toggleLikeThread(),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        thread.isLikedByMe
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                        size: 20,
                        color: thread.isLikedByMe
                            ? AppColors.primary
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        thread.likesCount.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: thread.isLikedByMe
                              ? AppColors.primary
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    thread.commentsCount.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(BuildContext context, bool isPosting) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(30),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selected files preview
            _buildSelectedFilesPreview(),

            // Reply indicator
            if (_replyToCommentId != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: AppColors.primaryContainer,
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Membalas $_replyToAuthorName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _replyToCommentId = null;
                          _replyToAuthorName = null;
                        });
                      },
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

            // Input row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.attach_file,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    onPressed: _showAttachmentOptions,
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocus,
                        decoration: const InputDecoration(
                          hintText: 'Tulis komentar...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                        maxLines: 3,
                        minLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: isPosting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                      onPressed: isPosting
                          ? null
                          : () => _submitComment(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitComment(BuildContext context) {
    final content = _commentController.text.trim();
    if (content.isEmpty && _selectedFiles.isEmpty) return;

    context.read<ThreadDetailCubit>().postComment(
      widget.threadUuid,
      content: content,
      parentId: _replyToCommentId,
      attachments: _selectedFiles.isNotEmpty ? List.from(_selectedFiles) : null,
    );

    _commentController.clear();
    _commentFocus.unfocus();
    setState(() {
      _replyToCommentId = null;
      _replyToAuthorName = null;
      _selectedFiles.clear();
    });
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppColors.primary,
              ),
              title: const Text('Galeri Gambar'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImages();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file,
                color: AppColors.primary,
              ),
              title: const Text('Dokumen'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFiles();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    var status = await Permission.camera.status;
    if (status.isDenied) status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Akses kamera ditolak permanen. Silakan aktifkan di pengaturan.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!status.isGranted) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (image != null) {
      if (!mounted) return;
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => ImagePreviewDialog(
          imagePath: image.path,
          onSend: () => Navigator.pop(ctx, true),
          onRetake: () => Navigator.pop(ctx, false),
        ),
      );
      if (result == true) {
        setState(() => _selectedFiles.add(File(image.path)));
      } else if (result == false) {
        _takePhoto();
      }
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 80);
    if (images.isNotEmpty) {
      setState(() => _selectedFiles.addAll(images.map((x) => File(x.path))));
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'jpeg',
        'png',
        'jpg',
        'pdf',
        'xls',
        'xlsx',
        'doc',
        'docx',
      ],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(
        () => _selectedFiles.addAll(
          result.files.where((f) => f.path != null).map((f) => File(f.path!)),
        ),
      );
    }
  }

  Widget _buildSelectedFilesPreview() {
    if (_selectedFiles.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedFiles.length,
        itemBuilder: (context, index) {
          final file = _selectedFiles[index];
          final isImage = [
            'jpg',
            'jpeg',
            'png',
            'gif',
            'webp',
          ].contains(file.path.toLowerCase().split('.').last);
          return Container(
            margin: const EdgeInsets.only(right: 12),
            width: 80,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: isImage
                      ? Image.file(
                          file,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.description, color: Colors.grey),
                          ),
                        ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: InkWell(
                    onTap: () => setState(() => _selectedFiles.removeAt(index)),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _navigateToEdit(BuildContext context, ThreadModel thread) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateThreadPage(editThread: thread)),
    );
    if (result == true && mounted) {
      // ignore: use_build_context_synchronously
      context.read<ThreadDetailCubit>().loadThread(widget.threadUuid);
    }
  }

  Future<void> _openAttachment(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka attachment')),
      );
    }
  }

  String _getInitials(String name) {
    final parts = name.split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : 'U';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('dd MMM yyyy, HH:mm').format(dt);
  }
}
