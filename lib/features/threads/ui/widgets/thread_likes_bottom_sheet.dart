import 'package:flutter/material.dart';
import 'package:fifgroup_android_ticketing/data/models/thread_like_model.dart';
import 'package:fifgroup_android_ticketing/data/repositories/thread_repository.dart';
import 'package:fifgroup_android_ticketing/core/constants/app_colors.dart';

class ThreadLikesBottomSheet extends StatefulWidget {
  final String threadUuid;
  final ThreadRepository repository;

  const ThreadLikesBottomSheet({
    super.key,
    required this.threadUuid,
    required this.repository,
  });

  @override
  State<ThreadLikesBottomSheet> createState() => _ThreadLikesBottomSheetState();
}

class _ThreadLikesBottomSheetState extends State<ThreadLikesBottomSheet> {
  final ScrollController _scrollController = ScrollController();
  final List<ThreadLikeModel> _likes = [];
  int _page = 1;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadLikes();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadLikes();
    }
  }

  Future<void> _loadLikes() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await widget.repository.fetchThreadLikes(
        widget.threadUuid,
        page: _page,
      );

      setState(() {
        _likes.addAll(response.data);
        _hasMore = response.meta.currentPage < response.meta.lastPage;
        _page++;
      });
    } catch (e) {
      debugPrint('Error loading likes: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Daftar Likes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Colors.black12),

            // Content
            Expanded(
              child: _likes.isEmpty && !_isLoading
                  ? const Center(
                      child: Text(
                        'Belum ada yang melike thread ini.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _likes.length + (_hasMore ? 1 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        if (index == _likes.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final like = _likes[index];
                        final initial = like.userName.isNotEmpty
                            ? (like.userName.length >= 2
                                ? like.userName.substring(0, 2).toUpperCase()
                                : like.userName.substring(0, 1).toUpperCase())
                            : 'U';

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Text(
                            like.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${like.userRole ?? "-"} · ${like.userLevel ?? "-"} · ${like.userLocation ?? "-"}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
