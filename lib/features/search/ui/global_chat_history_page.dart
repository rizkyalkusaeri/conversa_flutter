import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_config.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';
import 'package:fifgroup_android_ticketing/data/models/chat_message_model.dart';
import '../cubit/global_chat_cubit.dart';
import '../cubit/global_chat_state.dart';
import '../../chat/ui/widgets/full_screen_image_viewer.dart';

class GlobalChatHistoryPage extends StatefulWidget {
  final SessionModel session;

  const GlobalChatHistoryPage({super.key, required this.session});

  @override
  State<GlobalChatHistoryPage> createState() => _GlobalChatHistoryPageState();
}

class _GlobalChatHistoryPageState extends State<GlobalChatHistoryPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      context.read<GlobalChatCubit>().loadMoreChats();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<GlobalChatCubit>().loadInitialChats(searchQuery: query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildReadOnlyBanner(),
          Expanded(
            child: BlocBuilder<GlobalChatCubit, GlobalChatState>(
              builder: (context, state) {
                if (state is GlobalChatLoading && state.isFirstLoad) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is GlobalChatError) {
                  return Center(child: Text(state.message));
                }

                if (state is GlobalChatLoaded) {
                  final chats = state.chats;

                  if (chats.isEmpty) {
                    return const Center(child: Text("Tidak ada pesan ditemukan"));
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Reversed to match chat UI
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: state.hasReachedMax ? chats.length : chats.length + 1,
                    itemBuilder: (context, index) {
                      if (index == chats.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }

                      final chat = chats[index];
                      return _buildMessageBubble(context, chat);
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
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
              decoration: const InputDecoration(
                hintText: 'Cari pesan...',
                border: InputBorder.none,
              ),
              onSubmitted: _onSearchChanged,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.session.ticketNumber,
                  style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  "HISTORY (READ ONLY)",
                  style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search, color: AppColors.textDark),
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
    );
  }

  Widget _buildReadOnlyBanner() {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade50,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.lock_clock_outlined, size: 14, color: Colors.amber),
          SizedBox(width: 8),
          Text(
            "Viewing previous conversation (Read-Only)",
            style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessageModel chat) {
    final timeStr = chat.createdAt != null ? DateFormat('h:mm a').format(chat.createdAt!) : "";
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              chat.senderName ?? 'User',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                child: Text(
                  chat.senderName?.substring(0, 1).toUpperCase() ?? "U",
                  style: const TextStyle(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (chat.attachmentUrl != null) ...[
                        _buildAttachment(context, chat),
                        if (chat.messageContent != null && chat.messageContent!.isNotEmpty) 
                          const SizedBox(height: 8),
                      ],
                      if (chat.messageContent != null && chat.messageContent!.isNotEmpty)
                        Text(
                          chat.messageContent!,
                          style: const TextStyle(color: AppColors.textDark, fontSize: 14, height: 1.4),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 40),
            child: Text(timeStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachment(BuildContext context, ChatMessageModel chat) {
    if (chat.messageType == 'IMAGE') {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenImageViewer(
                imageUrl: ApiConfig.imageUrl + chat.attachmentUrl!,
                heroTag: 'chat_image_${chat.id}',
              ),
            ),
          );
        },
        child: Hero(
          tag: 'chat_image_${chat.id}',
          child: CachedNetworkImage(
            imageUrl: ApiConfig.imageUrl + chat.attachmentUrl!,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey.shade200, height: 150),
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => launchUrl(Uri.parse(ApiConfig.imageUrl + chat.attachmentUrl!)),
        child: Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.withValues(alpha: 0.2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file, color: AppColors.textDark),
              const SizedBox(width: 8),
              Flexible(child: Text(chat.attachmentUrl?.split('/').last ?? 'View Document', overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      );
    }
  }
}
