import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:fifgroup_android_ticketing/core/network/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'widgets/full_screen_image_viewer.dart';
import 'widgets/rating_dialog.dart';
import 'widgets/forward_sessions_sheet.dart';
import 'widgets/multi_attachment_preview_sheet.dart';
import 'package:flutter/services.dart';
import 'package:fifgroup_android_ticketing/data/repositories/chat_repository.dart';
import 'package:fifgroup_android_ticketing/data/services/session_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/cubit/app_auth/app_auth_cubit.dart';
import '../../auth/cubit/app_auth/app_auth_state.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';
import 'package:fifgroup_android_ticketing/data/models/chat_message_model.dart';
import '../cubit/chat_detail_cubit.dart';
import '../cubit/chat_detail_state.dart';
import '../cubit/session_action_cubit.dart';
import '../cubit/session_action_state.dart';
import 'widgets/complete_session_dialog.dart';
import 'widgets/image_preview_dialog.dart';
import 'widgets/confirmation_dialog.dart';
import '../../../core/network/echo_service.dart';
import '../../../core/services/realtime_event_bus.dart';
import 'package:fifgroup_android_ticketing/features/profile/ui/widgets/user_profile_popup.dart';
import '../../../core/widgets/video_attachment_widget.dart';

class ChatDetailPage extends StatefulWidget {
  final SessionModel session;

  const ChatDetailPage({super.key, required this.session});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage>
    with WidgetsBindingObserver {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int? _currentUserId;
  bool _isSearching = false;
  bool _isExternalPickerOpen =
      false; // Cegah reload saat kembali dari FilePicker
  final TextEditingController _searchController = TextEditingController();

  // Subscription untuk session updated dari MainPage via EventBus
  StreamSubscription<Map<String, dynamic>>? _sessionUpdatedSub;

  bool _isSelecting = false;
  final Set<int> _selectedMessageIds = {};
  bool _isForwarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final authState = context.read<AppAuthCubit>().state;
    if (authState is AppAuthAuthenticated) {
      _currentUserId = authState.user.id;
    }
    _setupListeners();
  }

  // Reload pesan yang mungkin terlewat saat app kembali dari background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Abaikan jika kembali dari FilePicker/ImagePicker/kamera (bukan dari background app).
      // Flag di-reset di sini — bukan setelah await picker — agar tidak ada race condition.
      if (_isExternalPickerOpen) {
        _isExternalPickerOpen = false;
        return;
      }
      debugPrint('ChatDetailPage resumed — reloading chats & session...');
      // Hanya reload session status; pesan baru sudah ditangani realtime via Echo.
      // loadInitialChats() tidak dipanggil di sini agar list tidak kedip tanpa alasan.
      context.read<ChatDetailCubit>().reloadSession();
    }
  }

  void _setupListeners() {
    // Tandai sesi ini sebagai aktif di EventBus
    // → MainPage TIDAK akan tampilkan notifikasi untuk sesi ini
    RealtimeEventBus.instance.setActiveSession(widget.session.id);

    // Scroll listener: load more saat mendekati ujung atas (list is reversed)
    _scrollController.addListener(() {
      if (!mounted) return;
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.9) {
        context.read<ChatDetailCubit>().loadMoreChats();
      }
    });

    // Listen MessageSent dari channel SPESIFIK sesi ini via Echo
    // AMAN: channel 'chat.$sessionId' bukan channel user global
    EchoService.listen('chat.${widget.session.id}', '.MessageSent', (data) {
      if (data != null && mounted) {
        try {
          final newChat = ChatMessageModel.fromJson(data);
          context.read<ChatDetailCubit>().receiveMessage(newChat);
        } catch (e) {
          debugPrint('Failed to parse incoming chat: $e');
        }
      }
    });

    // Listen SessionUpdated via RealtimeEventBus (di-forward oleh MainPage)
    // TIDAK subscribe langsung ke Echo channel user.$userId
    // untuk menghindari duplikat listener
    _sessionUpdatedSub = RealtimeEventBus.instance.onSessionUpdated.listen((
      data,
    ) {
      if (!mounted) return;
      final eventSessionUuid = data['session_uuid']?.toString();
      if (eventSessionUuid != null && eventSessionUuid == widget.session.id) {
        debugPrint(
          'EventBus: SessionUpdated untuk sesi aktif (${widget.session.id}), reloading...',
        );
        context.read<ChatDetailCubit>().reloadSession();
        context.read<ChatDetailCubit>().loadInitialChats();
      }
    });
  }

  @override
  void dispose() {
    // Hapus tracking sesi aktif saat keluar dari halaman
    RealtimeEventBus.instance.clearActiveSession();
    WidgetsBinding.instance.removeObserver(this);
    // Leave hanya channel spesifik sesi ini — bukan channel user global!
    EchoService.leave('chat.${widget.session.id}');
    _sessionUpdatedSub?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleActionSuccess(SessionModel updatedSession) {
    // Optionally update local session here by passing it back to parent or updating Cubit
    // For now we just show a snackbar. Cubit reload or list refresh on Pop might be needed
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Operasi berhasil'),
        backgroundColor: Colors.green,
      ),
    );
    // Update session local so UI reacts instantly
    context.read<ChatDetailCubit>().updateSession(updatedSession);
    // Reload chats to fetch the new system messages immediately
    context.read<ChatDetailCubit>().loadInitialChats();
  }

  void _onSearchChanged(String query) {
    context.read<ChatDetailCubit>().loadInitialChats(searchQuery: query);
  }

  Future<void> _pickAttachment(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Lampiran',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200, width: 0.5),
                    ),
                    child: Text(
                      'Maksimal 20MB',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            ListTile(
              leading: const Icon(
                Icons.perm_media_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Galeri Media (Foto & Video)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickGalleryMedia(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Ambil Foto'),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: AppColors.primary),
              title: const Text('Ambil Video'),
              onTap: () {
                Navigator.pop(ctx);
                _takeVideo();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file,
                color: AppColors.primary,
              ),
              title: const Text('Dokumen'),
              onTap: () async {
                final cubit = context.read<ChatDetailCubit>();
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                Navigator.pop(ctx);
                _isExternalPickerOpen = true;
                FilePickerResult? result = await FilePicker.pickFiles(
                  allowMultiple: true,
                );
                // Flag akan di-reset di didChangeAppLifecycleState saat resumed
                if (result == null || result.files.isEmpty) {
                  _isExternalPickerOpen = false; // Tidak ada lifecycle jika picker dibatalkan
                  return;
                }

                // Konversi ke XFile & batasi ke 5
                List<XFile> picked = result.files
                    .where((f) => f.path != null)
                    .map((f) => XFile(f.path!, name: f.name))
                    .take(5)
                    .toList();

                if (result.files.length > 5) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Hanya 5 file pertama yang dipilih (batas maksimal).',
                      ),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }

                if (!mounted) return;
                // Tampilkan preview sheet
                final List<XFile>? confirmed =
                    await showModalBottomSheet<List<XFile>>(
                  context: navigator.context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => MultiAttachmentPreviewSheet(
                    initialFiles: picked,
                    sourceType: 'document',
                  ),
                );

                if (confirmed != null && confirmed.isNotEmpty) {
                  cubit.sendMultipleAttachments(confirmed);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    final cubit = context.read<ChatDetailCubit>();
    final messenger = ScaffoldMessenger.of(context);

    // Request Permission
    var status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
    }

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
      imageQuality: 70, // Optimize size
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
        cubit.sendMessage("", image);
      } else if (result == false) {
        // Retake
        _takePhoto();
      }
    }
  }

  Future<void> _takeVideo() async {
    final cubit = context.read<ChatDetailCubit>();
    final messenger = ScaffoldMessenger.of(context);

    var status = await Permission.camera.status;
    if (status.isDenied) status = await Permission.camera.request();
    if (!status.isGranted) return;

    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.camera);

    if (video != null) {
      if (!mounted) return;
      // Validasi ukuran video
      final size = await File(video.path).length();
      if (size > 20 * 1024 * 1024) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Video terlalu besar. Maksimal 20MB.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      cubit.sendMessage("", video);
    }
  }

  Future<void> _pickGalleryMedia(BuildContext context) async {
    final cubit = context.read<ChatDetailCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final picker = ImagePicker();

    // Pilih multiple media (foto & video) sekaligus
    _isExternalPickerOpen = true;
    final List<XFile> mediaList = await picker.pickMultipleMedia();
    // Flag akan di-reset di didChangeAppLifecycleState saat resumed

    if (!mounted) return;
    if (mediaList.isEmpty) {
      _isExternalPickerOpen = false; // Tidak ada lifecycle jika picker dibatalkan
      return;
    }

    // Batasi ke 5 file
    List<XFile> picked = mediaList.take(5).toList();
    if (mediaList.length > 5) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Hanya 5 media pertama yang dipilih (batas maksimal).',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }

    // Tampilkan preview sheet multi-file
    final List<XFile>? confirmed = await showModalBottomSheet<List<XFile>>(
      context: navigator.context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiAttachmentPreviewSheet(
        initialFiles: picked,
        sourceType: 'gallery',
      ),
    );

    if (!mounted) return;
    if (confirmed != null && confirmed.isNotEmpty) {
      cubit.sendMultipleAttachments(confirmed);
    }
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    context.read<ChatDetailCubit>().sendMessage(text, null);
    _msgController.clear();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // const _EncryptionNotice(),
                Expanded(
                  child: BlocConsumer<ChatDetailCubit, ChatDetailState>(
                    listener: (context, state) {
                      if (state is ChatDetailLoaded && state.submitError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.submitError!),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      if (state is ChatDetailLoading && state.isFirstLoad) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (state is ChatDetailError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_off_rounded,
                                  size: 56,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  state.message,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                OutlinedButton.icon(
                                  onPressed: () => context
                                      .read<ChatDetailCubit>()
                                      .loadInitialChats(),
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text('Coba Lagi'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: BorderSide(color: AppColors.primary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (state is ChatDetailLoaded) {
                        final chats = state.chats;

                        if (chats.isEmpty) {
                          return const Center(
                            child: Text(
                              'Belum ada pesan. Mulai percakapan sekarang.',
                            ),
                          );
                        }

                        return BlocListener<SessionActionCubit, SessionActionState>(
                          listener: (context, actionState) {
                            if (actionState is SessionActionSuccess) {
                              _handleActionSuccess(actionState.session);
                            } else if (actionState is SessionActionError) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(actionState.message),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          child: ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            // +1 for uploading bubble (only when uploading a file), +1 for load-more spinner
                            itemCount:
                                chats.length +
                                (state.isUploadingAttachment ? 1 : 0) +
                                (state.hasReachedMax ? 0 : 1),
                            itemBuilder: (context, index) {
                              // Uploading bubble — at top (index 0 since list is reversed)
                              if (state.isUploadingAttachment && index == 0) {
                                return _buildUploadingBubble();
                              }

                              // Offset index when uploading bubble is shown
                              final adjustedIndex = state.isUploadingAttachment
                                  ? index - 1
                                  : index;

                              // Load-more spinner at bottom
                              if (adjustedIndex == chats.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }

                              final chat = chats[adjustedIndex];
                              final isMe = chat.senderId == _currentUserId;

                              return _buildMessageBubble(chat, isMe);
                            },
                          ),
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ),
                if (_isSelecting) const SizedBox.shrink() else _buildMessageComposer(),
              ],
            ),
            if (_isForwarding)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Meneruskan pesan...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Bubble sementara yang muncul di chat list saat file sedang diunggah
  Widget _buildUploadingBubble() {
    // Ambil progress dari state untuk tampilkan "Mengunggah 2/5..."
    String uploadLabel = 'Mengunggah...';
    final currentState = context.read<ChatDetailCubit>().state;
    if (currentState is ChatDetailLoaded && currentState.uploadingCount > 1) {
      final current = currentState.uploadedCount + 1;
      final total = currentState.uploadingCount;
      uploadLabel = 'Mengunggah $current/$total...';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  uploadLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    SessionModel session = widget.session;

    // Attempt to get the latest session state if loaded
    final state = context.watch<ChatDetailCubit>().state;
    if (state is ChatDetailLoaded) {
      session = state.session;
    }

    String opponentName = 'Menunggu Responder';
    if (session.requesterId == _currentUserId) {
      if (session.resolverName != null) opponentName = session.resolverName!;
    } else {
      if (session.requesterName != null) opponentName = session.requesterName!;
    }

    final initials = opponentName.isNotEmpty
        ? opponentName.substring(0, 1).toUpperCase()
        : "U";

    final isRequester = session.requesterId == _currentUserId;
    final isResolver = session.resolverId == _currentUserId;
    final isCredit = session.isHaveUniqueId;
    final status = session.status;
    final closeRequestedBy = session.closeRequestedBy;
    final isOpposing =
        closeRequestedBy != null && closeRequestedBy != _currentUserId;

    bool showRequestClose = false;
    bool showComplete = false;
    bool showReject = false;
    bool showCancelRequest = false;

    if (status == 'OPEN') {
      if (!isCredit && isResolver) showRequestClose = true;
      if (isCredit && (isRequester || isResolver)) showRequestClose = true;
      if (!isCredit && isRequester) showComplete = true;
    } else if (status == 'REQ_CLOSE') {
      if (!isCredit && isRequester) {
        showComplete = true;
        showReject = true;
      }
      if (isCredit && isOpposing) {
        showComplete = true;
        showReject = true;
      }
      // The user who sent the close request can cancel it (mutually exclusive with showComplete/showReject)
      final iAmCloseRequester = closeRequestedBy != null && closeRequestedBy == _currentUserId;
      if (iAmCloseRequester) {
        showCancelRequest = true;
      }
    }

    if (_isSelecting) {
      return AppBar(
        backgroundColor: AppColors.primary,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            setState(() {
              _isSelecting = false;
              _selectedMessageIds.clear();
            });
          },
        ),
        title: Text(
          '${_selectedMessageIds.length} terpilih',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.forward_rounded, color: Colors.white),
            tooltip: 'Teruskan',
            onPressed: _selectedMessageIds.isEmpty ? null : _showForwardBottomSheet,
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
        onPressed: () => Navigator.pop(context),
      ),
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textDark),
              decoration: const InputDecoration(
                hintText: 'Cari pesan...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
              onSubmitted: _onSearchChanged,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Sesi #${session.ticketNumber.substring(0, 8)}",
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  session.status == 'REQ_CLOSE'
                      ? 'MENUNGGU RESPONS'
                      : session.status.toUpperCase(),
                  style: TextStyle(
                    color: session.status == 'REQ_CLOSE'
                        ? Colors.amber
                        : AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
      centerTitle: true,
      actions: [
        if (showCancelRequest)
          IconButton(
            icon: const Icon(Icons.cancel_schedule_send, color: Colors.orange),
            tooltip: 'Batalkan Minta Selesai',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => const ConfirmationDialog(
                  title: 'Batalkan Permintaan Selesai',
                  message: 'Apakah Anda yakin ingin membatalkan permintaan penyelesaian sesi ini? Percakapan akan kembali aktif.',
                  confirmLabel: 'Ya, Batalkan',
                  cancelLabel: 'Tidak',
                  icon: Icons.cancel_schedule_send,
                  iconColor: Colors.orange,
                ),
              );
              if (!mounted) return;
              if (confirm == true) {
                context.read<SessionActionCubit>().cancelClose(session.id);
              }
            },
          ),
        if (showReject)
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            tooltip: 'Tolak',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => const ConfirmationDialog(
                  title: 'Tolak Permintaan Selesai',
                  message: 'Apakah Anda yakin ingin menolak permintaan penyelesaian sesi ini?',
                  confirmLabel: 'Ya, Tolak',
                  cancelLabel: 'Batal',
                  icon: Icons.cancel,
                  iconColor: Colors.red,
                ),
              );
              if (!mounted) return;
              if (confirm == true) {
                context.read<SessionActionCubit>().rejectClose(session.id);
              }
            },
          ),
        if (showComplete)
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            tooltip: 'Selesaikan',
            onPressed: () async {
              if (session.isFeedbackRequired) {
                final result = await showDialog<SessionModel>(
                  context: context,
                  builder: (ctx) => BlocProvider.value(
                    value: context.read<SessionActionCubit>(),
                    child: CompleteSessionDialog(session: session),
                  ),
                );
                if (!mounted) return;
                if (result != null) {
                  _handleActionSuccess(result);
                }
              } else {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => const ConfirmationDialog(
                    title: 'Selesaikan Sesi',
                    message: 'Apakah Anda yakin ingin menyelesaikan sesi ini? Status tiket akan berubah menjadi CLOSED.',
                    confirmLabel: 'Ya, Selesaikan',
                    cancelLabel: 'Batal',
                    icon: Icons.check_circle,
                    iconColor: Colors.green,
                  ),
                );
                if (!mounted) return;
                if (confirm == true) {
                  context.read<SessionActionCubit>().completeSession(session.id);
                }
              }
            },
          ),
        if (showRequestClose)
          IconButton(
            icon: const Icon(Icons.access_time_filled, color: Colors.amber),
            tooltip: 'Minta Selesai',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => const ConfirmationDialog(
                  title: 'Minta Selesai Sesi',
                  message: 'Apakah Anda yakin ingin meminta penyelesaian sesi ini?',
                  confirmLabel: 'Ya, Kirim',
                  cancelLabel: 'Batal',
                  icon: Icons.access_time_filled,
                  iconColor: Colors.amber,
                ),
              );
              if (!mounted) return;
              if (confirm == true) {
                context.read<SessionActionCubit>().requestClose(session.id);
              }
            },
          ),
        if (status == 'CLOSED') ...[
          // Tombol rating jika belum diberi penilaian dan user adalah requester & feedback diperlukan
          if (isRequester && session.rating == null && session.isFeedbackRequired)
            IconButton(
              icon: const Icon(
                Icons.star_border_rounded,
                color: Colors.amber,
                size: 28,
              ),
              tooltip: 'Beri Penilaian',
              onPressed: () async {
                final result = await showDialog<SessionModel>(
                  context: context,
                  builder: (ctx) => BlocProvider.value(
                    value: context.read<SessionActionCubit>(),
                    child: RatingDialog(session: session),
                  ),
                );
                if (result != null) {
                  _handleActionSuccess(result);
                }
              },
            ),
          if (session.openRequestedAt == null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.blue),
              tooltip: 'Request Reopen',
              onPressed: () {
                context.read<SessionActionCubit>().reopenSession(session.id);
              },
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.hourglass_empty, color: Colors.amber),
            ),
        ],
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close : Icons.search,
            color: AppColors.textDark,
          ),
          onPressed: () {
            setState(() {
              if (_isSearching) {
                _isSearching = false;
                _searchController.clear();
                _onSearchChanged('');
              } else {
                _isSearching = true;
              }
            });
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  final opponentId = (session.requesterId == _currentUserId)
                      ? session.resolverId
                      : session.requesterId;
                  if (opponentId != null) {
                    UserProfilePopup.show(context, opponentId);
                  }
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      opponentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "${session.categoryName} • ${session.subCategoryName}",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showForwardBottomSheet() async {
    final List<String>? selectedSessionUuids = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ForwardSessionsSheet(
        currentSessionUuid: widget.session.id,
        currentUserId: _currentUserId,
      ),
    );

    if (selectedSessionUuids == null || selectedSessionUuids.isEmpty) return;

    setState(() => _isForwarding = true);

    try {
      final repository = ChatRepository();
      await repository.forwardChats(
        _selectedMessageIds.toList(),
        selectedSessionUuids,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesan berhasil diteruskan!'),
          backgroundColor: Colors.green,
        ),
      );

      final singleTargetUuid = selectedSessionUuids.length == 1 ? selectedSessionUuids.first : null;

      setState(() {
        _isSelecting = false;
        _selectedMessageIds.clear();
        _isForwarding = false;
      });

      if (singleTargetUuid != null) {
        // Fetch target session details to open it
        final session = await SessionService().getSessionByUuid(singleTargetUuid);
        if (!mounted) return;

        // Replace current detail page route with target page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => ChatDetailCubit(initialSession: session)..loadInitialChats(),
                ),
                BlocProvider(create: (_) => SessionActionCubit()),
              ],
              child: ChatDetailPage(session: session),
            ),
          ),
        );
      } else {
        // Reload messages of current chat
        context.read<ChatDetailCubit>().loadInitialChats();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isForwarding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal meneruskan pesan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMessageBubble(ChatMessageModel chat, bool isMe) {
    String timeStr = "";
    if (chat.createdAt != null) {
      timeStr = DateFormat('h:mm a').format(chat.createdAt!);
    }

    final isSelected = _selectedMessageIds.contains(chat.id);
    final isSystem = chat.messageType == 'SYSTEM';

    return InkWell(
      onTap: _isSelecting && !isSystem
          ? () {
              setState(() {
                if (_selectedMessageIds.contains(chat.id)) {
                  _selectedMessageIds.remove(chat.id);
                  if (_selectedMessageIds.isEmpty) {
                    _isSelecting = false;
                  }
                } else {
                  _selectedMessageIds.add(chat.id);
                }
              });
            }
          : null,
      onLongPress: !isSystem
          ? () {
              HapticFeedback.lightImpact();
              setState(() {
                _isSelecting = true;
                _selectedMessageIds.add(chat.id);
              });
            }
          : null,
      child: Container(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: isMe ? 0 : 4,
                right: isMe ? 4 : 0,
                bottom: 4,
              ),
              child: Text(
                isMe ? "Me" : (chat.senderName ?? 'User'),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isSelecting && !isSystem) ...[
                  Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedMessageIds.add(chat.id);
                        } else {
                          _selectedMessageIds.remove(chat.id);
                          if (_selectedMessageIds.isEmpty) {
                            _isSelecting = false;
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              if (!isMe) ...[
                GestureDetector(
                  onTap: _isSelecting
                      ? null
                      : () {
                          if (chat.senderId != null) {
                            UserProfilePopup.show(context, chat.senderId!);
                          }
                        },
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                    child: Text(
                      chat.senderName?.substring(0, 1).toUpperCase() ?? "U",
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (chat.attachmentUrl != null) ...[
                        GestureDetector(
                          onTap: _isSelecting
                              ? null
                              : () {
                                  if (chat.isImage) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FullScreenImageViewer(
                                          imageUrl:
                                              ApiConfig.imageUrl +
                                              chat.attachmentUrl!,
                                          heroTag: 'chat_image_${chat.id}',
                                        ),
                                      ),
                                    );
                                  } else if (chat.isVideo) {
                                    // Video Tap action (bisa diisi jika ingin fullscreen player khusus)
                                  } else {
                                    _openAttachment(
                                      ApiConfig.imageUrl + chat.attachmentUrl!,
                                    );
                                  }
                                },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: chat.isImage
                                ? Hero(
                                    tag: 'chat_image_${chat.id}',
                                    child: CachedNetworkImage(
                                      imageUrl:
                                          ApiConfig.imageUrl +
                                          chat.attachmentUrl!,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        height: 150,
                                        width: double.infinity,
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                            height: 150,
                                            width: double.infinity,
                                            color: Colors.grey.shade200,
                                            child: const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey,
                                                  size: 40,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  "Gagal memuat gambar",
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                    ),
                                  )
                                : chat.isVideo
                                ? IgnorePointer(
                                    ignoring: _isSelecting,
                                    child: VideoAttachmentWidget(
                                      videoUrl:
                                          ApiConfig.imageUrl +
                                          chat.attachmentUrl!,
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(12),
                                    color: Colors.grey.withValues(alpha: 0.2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.insert_drive_file,
                                          color: AppColors.textDark,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            chat.attachmentUrl
                                                    ?.split('/')
                                                    .last ??
                                                'Lihat Dokumen',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        if (chat.messageContent != null &&
                            chat.messageContent!.isNotEmpty)
                          const SizedBox(height: 8),
                      ],
                      if (chat.messageContent != null &&
                          chat.messageContent!.isNotEmpty)
                        Text(
                          chat.messageContent!,
                          style: TextStyle(
                            color: isMe ? Colors.white : AppColors.textDark,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (isMe) const SizedBox(width: 8),
            ],
          ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      chat.isRead ? Icons.done_all : Icons.check,
                      size: 14,
                      color: chat.isRead
                          ? AppColors.primary
                          : Colors.grey.shade400,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return BlocBuilder<ChatDetailCubit, ChatDetailState>(
      builder: (context, state) {
        SessionModel currentSession = widget.session;
        if (state is ChatDetailLoaded) {
          currentSession = state.session;
        }

        bool isClosed = [
          'CLOSED',
          'Selesai',
          'REQ_CLOSE',
        ].contains(currentSession.status);

        if (isClosed) {
          String message = "Sesi ini telah ditutup. Tidak bisa mengirim pesan.";
          if (currentSession.status == 'REQ_CLOSE') {
            message =
                "Permintaan penutupan sesi sedang diproses. Menunggu persetujuan Admin.";
          }
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade200,
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _pickAttachment(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.grey,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _msgController,
                              decoration: const InputDecoration(
                                hintText: "Type a message...",
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              maxLines: null,
                            ),
                          ),
                          const Icon(
                            Icons.emoji_emotions_outlined,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  BlocBuilder<ChatDetailCubit, ChatDetailState>(
                    builder: (context, state) {
                      bool isSubmitting = false;
                      if (state is ChatDetailLoaded) {
                        isSubmitting = state.isSubmitting;
                      }

                      return GestureDetector(
                        onTap: isSubmitting ? null : _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
