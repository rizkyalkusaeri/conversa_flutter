import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/cubit/app_auth/app_auth_cubit.dart';
import '../../auth/cubit/app_auth/app_auth_state.dart';
import '../cubit/session_list_cubit.dart';
import '../cubit/session_list_state.dart';
import '../cubit/create_session_cubit.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';
import 'create_session_sheet.dart';
import 'chat_detail_page.dart';
import '../cubit/chat_detail_cubit.dart';
import '../cubit/session_action_cubit.dart';
import '../cubit/session_action_state.dart';
import '../../../core/services/realtime_event_bus.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late SessionListCubit _cubit;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _selectedStatus = 'active';
  StreamSubscription<void>? _sessionRefreshSub;

  @override
  void initState() {
    super.initState();
    _cubit = SessionListCubit(statusFilter: 'active')..loadInitial();

    // Subscribe ke RealtimeEventBus untuk refresh saat ada SessionCreated/SessionUpdated
    _sessionRefreshSub = RealtimeEventBus.instance.onSessionRefresh.listen((_) {
      final query = _searchController.text;
      _cubit.loadInitial(searchQuery: query);
    });
  }

  @override
  void dispose() {
    _sessionRefreshSub?.cancel();
    _cubit.close();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _cubit.loadInitial(searchQuery: query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authRole = context.select<AppAuthCubit, String?>((cubit) {
      final state = cubit.state;
      if (state is AppAuthAuthenticated) return state.user.role;
      return null;
    });

    bool isCabang = authRole == 'Cabang';

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            "Sessions",
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            _buildFilters(),
            const Expanded(child: SessionListView()),
          ],
        ),
        floatingActionButton: isCabang
            ? FloatingActionButton(
                heroTag: 'chat_fab',
                onPressed: () => _showCreateSessionModal(context),
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add_comment, color: Colors.white),
              )
            : null,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Cari tiket/deskripsi...',
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

  Widget _buildFilters() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip('Active', 'active'),
          _buildFilterChip('Closed/Requested', 'closed'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedStatus = value);
            _cubit.loadInitial(
              searchQuery: _searchController.text,
              newStatusFilter: value,
            );
          }
        },
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.grey.shade200,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        showCheckmark: false,
      ),
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
        _cubit.loadInitial(searchQuery: _searchController.text);
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
    // CATATAN: Listener Echo untuk SessionCreated/SessionUpdated TIDAK dipasang di sini.
    // Channel 'user.$userId' dikelola secara global oleh MainPage.
    // SessionListView menerima update melalui RealtimeEventBus.onSessionRefresh
    // yang di-trigger oleh MainPage saat event tiba.
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
    // PENTING: Jangan panggil EchoService.leave('user.$userId') di sini!
    // Channel user.$userId adalah milik MainPage — me-leave-nya dari child
    // widget akan memutus semua listener realtime global.
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SessionActionCubit(),
      child: BlocListener<SessionActionCubit, SessionActionState>(
        listener: (context, actionState) {
          if (actionState is SessionActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Operasi berhasil'),
                backgroundColor: Colors.green,
              ),
            );
            // Refresh list
            final state = context.read<SessionListCubit>().state;
            final query = (state is SessionListLoaded) ? state.searchQuery : '';
            context.read<SessionListCubit>().loadInitial(searchQuery: query);
          } else if (actionState is SessionActionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(actionState.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<SessionListCubit, SessionListState>(
          builder: (context, state) {
            if (state is SessionListInitial || state is SessionListLoading) {
              return const Center(child: CircularProgressIndicator());
            }
        if (state is SessionListError) {
          return Center(
            child: Text(
              state.message,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (state is SessionListLoaded) {
          if (state.sessions.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                await context.read<SessionListCubit>().loadInitial(
                  searchQuery: state.searchQuery,
                  newStatusFilter: context.read<SessionListCubit>().statusFilter,
                );
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            "Tidak ada sesi saat ini.",
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Tarik ke bawah untuk memperbarui.",
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              await context.read<SessionListCubit>().loadInitial(
                 searchQuery: state.searchQuery,
                 newStatusFilter: context.read<SessionListCubit>().statusFilter,
              );
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _scrollController,
              itemCount: state.hasReachedMax
                  ? state.sessions.length
                  : state.sessions.length + 1,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFF5F5F5)),
              itemBuilder: (context, index) {
                if (index >= state.sessions.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return _buildSessionTile(context, state.sessions[index]);
              },
            ),
          );
        }
        return const SizedBox.shrink();
      },
      ),
      ),
    );
  }

  Widget _buildSessionTile(BuildContext context, SessionModel session) {
    final bool isOpen = session.status == 'OPEN';
    final bool isReqClose = session.status == 'REQ_CLOSE';
    final statusColor = isOpen ? AppColors.success : (isReqClose ? Colors.amber : Colors.grey);
    final statusLabel = isReqClose ? 'MENUNGGU RESPONS' : session.status.toUpperCase();

    final String identifier = session.isHaveUniqueId
        ? (session.noAppl != null && session.noAppl!.isNotEmpty ? session.noAppl! : '-')
        : (session.topicName ?? '-');

    // Determine opponent
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
    
    String initials = "U";
    if (displayName.isNotEmpty && displayName != 'Unknown') {
      final parts = displayName.split(" ").where((e) => e.isNotEmpty).toList();
      initials = parts.isNotEmpty ? parts[0].substring(0, 1).toUpperCase() : "";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          final cubit = context.read<SessionListCubit>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (context) =>
                        ChatDetailCubit(initialSession: session)..loadInitialChats(),
                  ),
                  BlocProvider(
                    create: (context) => SessionActionCubit(),
                  ),
                ],
                child: ChatDetailPage(session: session),
              ),
            ),
          ).then((_) {
            if (mounted) {
              final query = (cubit.state is SessionListLoaded)
                 ? (cubit.state as SessionListLoaded).searchQuery
                 : '';
              cubit.loadInitial(searchQuery: query);
            }
          });
        },
        onLongPress: () => _showDetailPopup(context, session),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Name + Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (session.status == 'CLOSED' || session.status == 'Selesai') ...[
                              if (session.openRequestedAt == null)
                                InkWell(
                                  onTap: () {
                                    context.read<SessionActionCubit>().reopenSession(session.id);
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.refresh,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                  ),
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.hourglass_empty,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                ),
                              const SizedBox(width: 4),
                            ],
                            InkWell(
                              onTap: () => _showDetailPopup(context, session),
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            if (session.unreadCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  "${session.unreadCount}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ]
                          ]
                        ),
                      ]
                    ),
                    const SizedBox(height: 6),
                    // Row 2: Ticket Number & Topic
                    Row(
                      children: [
                        Text(
                          '#${session.ticketNumber}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          session.isHaveUniqueId
                              ? Icons.confirmation_number_outlined
                              : Icons.topic_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            identifier,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Row 3: Message / Description
                    if ((session.latestChat?.message ?? session.description) != null &&
                        (session.latestChat?.message ?? session.description)!.isNotEmpty)
                      Text(
                        (session.latestChat?.message ?? session.description)!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ]
                )
              )
            ]
          )
        ),
      ),
    );
  }

  void _showDetailPopup(BuildContext context, SessionModel session) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Session Detail',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                _buildDetailRow('Ticket Number', '#${session.ticketNumber}'),
                _buildDetailRow('Status', session.status),
                _buildDetailRow('Category', session.categoryName ?? '-'),
                _buildDetailRow('Sub Category', session.subCategoryName ?? '-'),
                _buildDetailRow('Topic', session.topicName ?? '-'),
                if (session.noAppl != null && session.noAppl!.isNotEmpty)
                  _buildDetailRow('No. Appl', session.noAppl!),
                _buildDetailRow('Requester', session.requesterName ?? '-'),
                _buildDetailRow('Resolver', session.resolverName ?? 'Menunggu'),
                _buildDetailRow('Description', session.description ?? '-'),
                if (session.createdAt != null)
                  _buildDetailRow(
                    'Created',
                    '${session.createdAt!.day}/${session.createdAt!.month}/${session.createdAt!.year} '
                        '${session.createdAt!.hour.toString().padLeft(2, '0')}:${session.createdAt!.minute.toString().padLeft(2, '0')}',
                  ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final cubit = context.read<SessionListCubit>();
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider(
                            create: (context) =>
                                ChatDetailCubit(initialSession: session)..loadInitialChats(),
                            child: ChatDetailPage(session: session),
                          ),
                        ),
                      ).then((_) {
                        if (mounted) {
                          final query = (cubit.state is SessionListLoaded)
                             ? (cubit.state as SessionListLoaded).searchQuery
                             : '';
                          cubit.loadInitial(searchQuery: query);
                        }
                      });
                    },
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('Buka Chat Room'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}
