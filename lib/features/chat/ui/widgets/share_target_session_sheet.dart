import 'package:flutter/material.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';
import 'package:fifgroup_android_ticketing/data/repositories/session_repository.dart';
import '../../../../core/constants/app_colors.dart';

/// Bottom sheet untuk memilih satu sesi aktif tujuan share content.
class ShareTargetSessionSheet extends StatefulWidget {
  final int? currentUserId;

  const ShareTargetSessionSheet({
    super.key,
    required this.currentUserId,
  });

  @override
  State<ShareTargetSessionSheet> createState() => _ShareTargetSessionSheetState();
}

class _ShareTargetSessionSheetState extends State<ShareTargetSessionSheet> {
  final SessionRepository _repository = SessionRepository();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<SessionModel> _allSessions = [];
  List<SessionModel> _filteredSessions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadActiveSessions();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSessions = List.from(_allSessions);
      } else {
        _filteredSessions = _allSessions.where((session) {
          final ticketMatch = session.ticketNumber.toLowerCase().contains(query);
          final requesterMatch =
              (session.requesterName ?? '').toLowerCase().contains(query);
          final resolverMatch =
              (session.resolverName ?? '').toLowerCase().contains(query);
          final topicMatch =
              (session.topicName ?? '').toLowerCase().contains(query);
          return ticketMatch || requesterMatch || resolverMatch || topicMatch;
        }).toList();
      }
    });
  }

  Future<void> _loadActiveSessions() async {
    try {
      final response = await _repository.fetchSessions('active', 1);
      if (mounted) {
        setState(() {
          _allSessions = response.data;
          _filteredSessions = List.from(response.data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat sesi aktif. Silakan coba lagi.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kirim Ke Sesi',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            _isLoading
                ? 'Memuat sesi aktif...'
                : '${_allSessions.length} sesi aktif tersedia',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),

          // Search field
          TextField(
            controller: _searchController,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Cari sesi (nama, tiket, topik)...',
              hintStyle: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.grey.shade400,
                fontSize: 13,
              ),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.grey.shade400, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      color: Colors.grey.shade400,
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Session list
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadActiveSessions();
              },
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_allSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text(
              'Tidak ada sesi aktif',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_filteredSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text(
              'Sesi tidak ditemukan',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredSessions.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final session = _filteredSessions[index];

        String opponentName = 'Menunggu Responder';
        if (session.requesterId == widget.currentUserId) {
          if (session.resolverName != null) opponentName = session.resolverName!;
        } else {
          if (session.requesterName != null) opponentName = session.requesterName!;
        }

        String initials = "U";
        if (opponentName.isNotEmpty && opponentName != 'Menunggu Responder') {
          final parts = opponentName.split(" ").where((e) => e.isNotEmpty).toList();
          initials = parts.isNotEmpty ? parts[0].substring(0, 1).toUpperCase() : "";
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.pop(context, session);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
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
                        Text(
                          opponentName,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '#${session.ticketNumber.substring(0, session.ticketNumber.length.clamp(0, 8))}',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.grey.shade600,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (session.topicName != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                '•',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  session.topicName!,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
