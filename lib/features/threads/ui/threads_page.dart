// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/cubit/app_auth/app_auth_cubit.dart';
import '../../auth/cubit/app_auth/app_auth_state.dart';
import '../cubit/thread_list_cubit.dart';
import '../cubit/thread_list_state.dart';
import 'widgets/thread_card.dart';
import 'thread_detail_page.dart';
import 'create_thread_page.dart';

class ThreadsPage extends StatefulWidget {
  const ThreadsPage({super.key});

  @override
  State<ThreadsPage> createState() => _ThreadsPageState();
}

class _ThreadsPageState extends State<ThreadsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late ThreadListCubit _cubit;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _cubit = ThreadListCubit()..loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    _cubit.close();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _cubit.loadMore();
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _cubit.search(query);
    });
  }

  int? get _currentUserId {
    final authState = context.read<AppAuthCubit>().state;
    if (authState is AppAuthAuthenticated) {
      return authState.user.id;
    }
    return null;
  }

  String? get _currentUserRole {
    final authState = context.read<AppAuthCubit>().state;
    if (authState is AppAuthAuthenticated) {
      return authState.user.role;
    }
    return null;
  }

  bool get _canCreateThread {
    final role = _currentUserRole?.toUpperCase();
    return role == 'ADMIN' || role == 'HO';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(context),
        body: _buildBody(context),
        floatingActionButton: _canCreateThread
            ? FloatingActionButton(
                heroTag: 'create_thread_fab',
                onPressed: () => _navigateToCreateThread(context),
                backgroundColor: AppColors.primary,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Threads',
        style: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Cari thread...',
          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: BlocBuilder<ThreadListCubit, ThreadListState>(
            builder: (context, state) {
              if (state is ThreadListLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              if (state is ThreadListError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () =>
                              context.read<ThreadListCubit>().loadInitial(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (state is ThreadListLoaded) {
                if (state.threads.isEmpty) {
                  return _buildEmptyState(context);
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () =>
                      context.read<ThreadListCubit>().loadInitial(),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount:
                        state.threads.length + (state.hasReachedMax ? 0 : 1),
                    itemBuilder: (context, index) {
                      if (index >= state.threads.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      }

                      final thread = state.threads[index];
                      return ThreadCard(
                        thread: thread,
                        currentUserId: _currentUserId,
                        onTap: () => _navigateToDetail(context, thread.id),
                        onLike: () => context
                            .read<ThreadListCubit>()
                            .toggleLike(thread.id),
                        onEdit: (thread.author.id == _currentUserId)
                            ? () => _navigateToEditThread(context, thread)
                            : null,
                      );
                    },
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final hasSearch = _searchController.text.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch ? Icons.search_off : Icons.forum_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Tidak ada hasil untuk "${_searchController.text}"'
                  : 'Belum ada thread',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Coba kata kunci lain'
                  : 'Jadilah yang pertama memulai diskusi!',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, String threadUuid) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThreadDetailPage(threadUuid: threadUuid),
      ),
    );
    // Refresh list in case likes/comments changed
    if (mounted) {
      _cubit.loadInitial();
    }
  }

  void _navigateToCreateThread(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateThreadPage()),
    );
    if (result == true && mounted) {
      _cubit.loadInitial();
    }
  }

  void _navigateToEditThread(BuildContext context, dynamic thread) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateThreadPage(editThread: thread)),
    );
    if (result == true && mounted) {
      _cubit.loadInitial();
    }
  }
}
