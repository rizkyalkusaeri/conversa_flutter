import 'package:fifgroup_android_ticketing/core/network/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'widgets/full_screen_image_viewer.dart';
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
import '../../../core/network/echo_service.dart';
import '../../../core/services/realtime_event_bus.dart';

class ChatDetailPage extends StatefulWidget {
  final SessionModel session;

  const ChatDetailPage({super.key, required this.session});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> with WidgetsBindingObserver {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int? _currentUserId;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

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

  // Reconnect WebSocket saat app kembali dari background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint("ChatDetailPage resumed — resubscribing Echo listeners...");
      // Reload chat untuk mendapat pesan yang mungkin terlewat
      context.read<ChatDetailCubit>().loadInitialChats();
      context.read<ChatDetailCubit>().reloadSession();
    }
  }

  void _setupListeners() {
    // Tandai sesi ini sebagai aktif → MainPage tidak akan kirim notifikasi untuk sesi ini
    RealtimeEventBus.instance.setActiveSession(widget.session.id);

    // Scroll listener: load more saat mendekati ujung atas (list is reversed)
    _scrollController.addListener(() {
      if (!mounted) return;
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.9) {
        context.read<ChatDetailCubit>().loadMoreChats();
      }
    });

    // Listen MessageSent → update UI saja (TIDAK ada notifikasi, user sudah lihat)
    EchoService.listen('chat.${widget.session.id}', '.MessageSent', (data) {
      if (data != null && mounted) {
        try {
          final newChat = ChatMessageModel.fromJson(data);
          context.read<ChatDetailCubit>().receiveMessage(newChat);
        } catch (e) {
          debugPrint("Failed to parse incoming chat: $e");
        }
      }
    });

    // Listen SessionUpdated → reload status sesi secara realtime
    if (_currentUserId != null) {
      EchoService.listen('user.$_currentUserId', '.SessionUpdated', (data) {
        if (data != null && mounted) {
          final eventSessionUuid = data['session_uuid'];
          if (eventSessionUuid != null && eventSessionUuid.toString() == widget.session.id) {
            debugPrint("Echo: SessionUpdated for current session (${widget.session.id}), reloading...");
            context.read<ChatDetailCubit>().loadInitialChats();
            context.read<ChatDetailCubit>().reloadSession();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    // Hapus tracking sesi aktif saat keluar dari halaman
    RealtimeEventBus.instance.clearActiveSession();
    WidgetsBinding.instance.removeObserver(this);
    EchoService.leave('chat.${widget.session.id}');
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
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppColors.primary,
              ),
              title: const Text('Galeri Gambar'),
              onTap: () async {
                final cubit = context.read<ChatDetailCubit>();
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final List<XFile> images = await picker.pickMultiImage();
                if (images.isNotEmpty) {
                  for (var image in images) {
                    cubit.sendMessage("", image);
                  }
                }
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
                Navigator.pop(ctx);
                FilePickerResult? result = await FilePicker.pickFiles(
                  allowMultiple: true,
                );
                if (result != null) {
                  for (var file in result.files) {
                    if (file.path != null) {
                      cubit.sendMessage("", XFile(file.path!, name: file.name));
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
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
        child: Column(
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
                      child: Text(
                        state.message,
                        style: const TextStyle(color: Colors.red),
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
                        itemCount: chats.length + (state.hasReachedMax ? 0 : 1),
                        itemBuilder: (context, index) {
                          if (index == chats.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }

                          final chat = chats[index];
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
            _buildMessageComposer(),
          ],
        ),
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
                  "Session #${session.ticketNumber.substring(0, 8)}",
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
        if (showReject)
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            tooltip: 'Tolak',
            onPressed: () {
              context.read<SessionActionCubit>().rejectClose(session.id);
            },
          ),
        if (showComplete)
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            tooltip: 'Selesaikan',
            onPressed: () async {
              final result = await showDialog<SessionModel>(
                context: context,
                builder: (ctx) => BlocProvider.value(
                  value: context.read<SessionActionCubit>(),
                  child: CompleteSessionDialog(session: session),
                ),
              );
              if (result != null) {
                _handleActionSuccess(result);
              }
            },
          ),
        if (showRequestClose)
          IconButton(
            icon: const Icon(Icons.access_time_filled, color: Colors.amber),
            tooltip: 'Minta Selesai',
            onPressed: () {
              context.read<SessionActionCubit>().requestClose(session.id);
            },
          ),
        if (status == 'CLOSED') ...[
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
              Stack(
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
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: const Text(
                  "Lihat Detail",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel chat, bool isMe) {
    String timeStr = "";
    if (chat.createdAt != null) {
      timeStr = DateFormat('h:mm a').format(chat.createdAt!);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
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
              if (!isMe) ...[
                CircleAvatar(
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
                          onTap: () {
                            if (chat.messageType == 'IMAGE') {
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
                            } else {
                              _openAttachment(
                                ApiConfig.imageUrl + chat.attachmentUrl!,
                              );
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: (chat.messageType == 'IMAGE')
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

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
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
                  child: const Icon(Icons.add, color: Colors.grey, size: 22),
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
        );
      },
    );
  }
}
