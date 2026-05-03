import 'dart:async';
import 'package:fifgroup_android_ticketing/core/services/realtime_event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_state.dart';
import '../cubit/global_chat_cubit.dart';
import 'global_chat_history_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'all';
  late SearchCubit _cubit;
  Timer? _debounce;

  StreamSubscription? _refreshSubscription;

  @override
  void initState() {
    super.initState();
    _cubit = SearchCubit()..loadInitial();
    _scrollController.addListener(_onScroll);

    // Auto-refresh saat signal dikirim dari MainPage (misal pindah tab)
    _refreshSubscription = RealtimeEventBus.instance.onSearchRefresh.listen((
      _,
    ) {
      if (mounted) {
        _cubit.loadInitial(
          searchQuery: _searchController.text,
          statusFilter: _selectedStatus,
        );
      }
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      if (currentScroll >= (maxScroll * 0.9)) {
        _cubit.loadMore();
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _cubit.onSearchChanged(query);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    _refreshSubscription?.cancel();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Pencarian Sesi',
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
            Expanded(
              child: BlocBuilder<SearchCubit, SearchState>(
                builder: (context, state) {
                  if (state is SearchInitial || state is SearchLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is SearchError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            state.message,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () =>
                                context.read<SearchCubit>().loadInitial(),
                            child: const Text("Coba Lagi"),
                          ),
                        ],
                      ),
                    );
                  }
                  if (state is SearchLoaded) {
                    if (state.sessions.isEmpty) {
                      return Center(
                        child: Text(
                          "Tidak ada sesi ditemukan.",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        await context.read<SearchCubit>().loadInitial(
                          searchQuery: state.searchQuery,
                          statusFilter: state.statusFilter,
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          return _buildSessionTile(
                            context,
                            state.sessions[index],
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
        ),
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
          hintText: 'Cari tiket, topik, no appl...',
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
          _buildFilterChip('Semua', 'all'),
          _buildFilterChip('Aktif', 'open'),
          _buildFilterChip('Selesai', 'closed'),
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
            _cubit.onStatusChanged(value);
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

  Widget _buildSessionTile(BuildContext context, SessionModel session) {
    final bool isOpen = session.status == 'OPEN';
    final statusColor = isOpen ? AppColors.success : Colors.grey;
    final statusLabel = isOpen ? 'OPEN' : 'CLOSED';

    // Determine the identifier line: no_appl if present, otherwise topic
    final String identifier = session.isHaveUniqueId
        ? (session.noAppl != null && session.noAppl!.isNotEmpty
              ? session.noAppl!
              : '-')
        : (session.topicName ?? '-');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (context) =>
                    GlobalChatCubit(sessionUuid: session.id)
                      ..loadInitialChats(),
                child: GlobalChatHistoryPage(session: session),
              ),
            ),
          );
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Ticket number + Status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${session.ticketNumber}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _showDetailPopup(context, session),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Topic / No Appl
              Row(
                children: [
                  Icon(
                    session.isHaveUniqueId
                        ? Icons.confirmation_number_outlined
                        : Icons.topic_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      identifier,
                      style: const TextStyle(
                        fontSize: 13,
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

              // Row 3: Description
              if (session.description != null &&
                  session.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    session.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Row 4: Requester & Resolver
              Row(
                children: [
                  Expanded(
                    child: _buildPersonChip(
                      Icons.person_outline,
                      session.requesterName ?? '-',
                      'Pembuat',
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPersonChip(
                      Icons.support_agent_outlined,
                      session.resolverName ?? 'Menunggu',
                      'Penjawab',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonChip(IconData icon, String name, String role) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
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

                _buildDetailRow('Nomor Tiket', '#${session.ticketNumber}'),
                _buildDetailRow('Status', session.status),
                _buildDetailRow('Kategori', session.categoryName ?? '-'),
                _buildDetailRow('Sub Kategori', session.subCategoryName ?? '-'),
                _buildDetailRow('Topik', session.topicName ?? '-'),
                if (session.isHaveUniqueId &&
                    session.noAppl != null &&
                    session.noAppl!.isNotEmpty)
                  _buildDetailRow('No. Appl', session.noAppl!),
                if (!session.isHaveUniqueId && session.topicName != null)
                  _buildDetailRow('Topik', session.topicName!),
                _buildDetailRow('Pembuat', session.requesterName ?? '-'),
                _buildDetailRow('Penjawab', session.resolverName ?? 'Menunggu'),
                _buildDetailRow('Deskripsi', session.description ?? '-'),
                if (session.createdAt != null)
                  _buildDetailRow(
                    'Dibuat',
                    '${session.createdAt!.day}/${session.createdAt!.month}/${session.createdAt!.year} '
                        '${session.createdAt!.hour.toString().padLeft(2, '0')}:${session.createdAt!.minute.toString().padLeft(2, '0')}',
                  ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider(
                            create: (context) =>
                                GlobalChatCubit(sessionUuid: session.id)
                                  ..loadInitialChats(),
                            child: GlobalChatHistoryPage(session: session),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('Lihat Chat History'),
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
