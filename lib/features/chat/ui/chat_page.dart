import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/cubit/app_auth/app_auth_cubit.dart';
import '../../auth/models/user_model.dart';
import '../../auth/cubit/app_auth/app_auth_state.dart';
import '../cubit/session_list_cubit.dart';
import '../cubit/session_list_state.dart';
import '../cubit/create_session_cubit.dart';
import '../models/session_model.dart';
import 'create_session_sheet.dart';
import 'chat_detail_page.dart';
import '../cubit/chat_detail_cubit.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SessionListCubit _activeCubit;
  late SessionListCubit _closedCubit;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _activeCubit = SessionListCubit(statusFilter: 'active')..loadInitial();
    _closedCubit = SessionListCubit(statusFilter: 'closed')..loadInitial();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _activeCubit.close();
    _closedCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mengecek dari AppAuthCubit apakah rol cabang. 
    // Kita anggap default bukan cabang jika null
    bool isCabang = false;
    final appAuthState = context.read<AppAuthCubit>().state;
    if (appAuthState.runtimeType.toString() == 'AppAuthAuthenticated') {
       // Ignore typing hack
       // We'll extract based on assumption or use read method
    }
    // Atau cara aman:
    // Pengecekan role agar yg bisa create hanya 'Cabang' (beradasarkan policy laravel):
    // Tapi kita belum bind AppAuthState di Chat. Kita akan tembak lgsg dari context:
    final authRole = context.select<AppAuthCubit, String?>((cubit) {
      final state = cubit.state;
      if (state is AppAuthAuthenticated) return state.user.role;
      return null;
    });

    isCabang = authRole == 'Cabang';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Sessions",
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textDark),
            onPressed: () {},
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: "Active"),
            Tab(text: "Requested / Closed"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Active Tab
          BlocProvider.value(
            value: _activeCubit,
            child: const SessionListView(),
          ),
          // Closed/Requested Tab
          BlocProvider.value(
            value: _closedCubit,
            child: const SessionListView(),
          ),
        ],
      ),
      // Tombol Tulis hanya dirender jika role === CABANG
      floatingActionButton: isCabang
          ? FloatingActionButton(
              onPressed: () => _showCreateSessionModal(context),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_comment, color: Colors.white),
            )
          : null,
    );
  }

  void _showCreateSessionModal(BuildContext context) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return BlocProvider(
          create: (c) => CreateSessionCubit()..loadInitialMasterData(),
          child: const CreateSessionSheet(),
        );
      },
    ).then((didCreate) {
      if (didCreate == true) {
        _activeCubit.loadInitial();
        _closedCubit.loadInitial();
      }
    });
  }
}

class SessionListView extends StatefulWidget {
  const SessionListView({super.key});

  @override
  State<SessionListView> createState() => _SessionListViewState();
}

class _SessionListViewState extends State<SessionListView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      if (currentScroll >= (maxScroll * 0.9)) {
        context.read<SessionListCubit>().loadMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionListCubit, SessionListState>(
      builder: (context, state) {
        if (state is SessionListInitial || state is SessionListLoading) {
           return const Center(child: CircularProgressIndicator());
        }
        if (state is SessionListError) {
           return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
        }
        if (state is SessionListLoaded) {
           if (state.sessions.isEmpty) {
              return Center(child: Text("Tidak ada interaksi saat ini.", style: TextStyle(color: Colors.grey.shade500)));
           }
           return RefreshIndicator(
             onRefresh: () async {
                await context.read<SessionListCubit>().loadInitial();
             },
             child: ListView.separated(
               physics: const AlwaysScrollableScrollPhysics(),
               controller: _scrollController,
               itemCount: state.hasReachedMax ? state.sessions.length : state.sessions.length + 1,
               separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF5F5F5)),
               itemBuilder: (context, index) {
                  if (index >= state.sessions.length) {
                     return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                     );
                  }
                  return _buildSessionTile(context, state.sessions[index]);
               },
             ),
           );
        }
        return const SizedBox.shrink();
      }
    );
  }

  Widget _buildSessionTile(BuildContext context, SessionModel session) {
    // Determine the name to show based on login User
    final appAuthState = context.read<AppAuthCubit>().state;
    String currentUserName = "";
    if (appAuthState is AppAuthAuthenticated) {
      currentUserName = appAuthState.user.fullName;
    }

    String displayName = 'Unknown';
    if (currentUserName == session.requesterName) {
       displayName = session.resolverName ?? 'Menunggu Responder';
    } else {
       displayName = session.requesterName ?? 'Unknown';
    }
    
    String snippet = session.latestChat?.message ?? session.description ?? 'No messages yet...';

    // Format waktu
    String timeStr = "";
    if (session.latestChat?.createdAt != null) {
      final w = session.latestChat!.createdAt!;
      timeStr = "${w.hour.toString().padLeft(2,'0')}:${w.minute.toString().padLeft(2,'0')}";
    }

    // Ekstrak Inisial untuk avatar fallback
    String initials = "U";
    if (displayName.isNotEmpty && displayName != 'Unknown') {
      final parts = displayName.split(" ").where((e) => e.isNotEmpty).toList();
      initials = parts.isNotEmpty ? parts[0].substring(0, 1).toUpperCase() : "";
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.secondary.withOpacity(0.2),
            child: Text(initials, style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
          ),
          if (session.status == 'OPEN')
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              ),
            )
        ],
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              displayName.split(" / ")[0], 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (session.ticketNumber.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
              child: Text(session.ticketNumber.substring(0, 8), style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 8),
          Text(timeStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            "${session.categoryName ?? 'Ticketing'}  •  ${session.subCategoryName ?? 'General'}",
            style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  snippet,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              if (session.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Text("${session.unreadCount}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          )
        ],
      ),
      onTap: () {
         Navigator.push(
           context,
           MaterialPageRoute(
             builder: (_) => BlocProvider(
               create: (context) => ChatDetailCubit(initialSession: session)..loadInitialChats(),
               child: ChatDetailPage(session: session),
             ),
           )
         );
      },
    );
  }
}
