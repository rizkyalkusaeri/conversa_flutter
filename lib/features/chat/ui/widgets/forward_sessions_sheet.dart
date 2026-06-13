import 'package:flutter/material.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';
import 'package:fifgroup_android_ticketing/data/repositories/session_repository.dart';
import '../../../../core/constants/app_colors.dart';

class ForwardSessionsSheet extends StatefulWidget {
  final String currentSessionUuid;
  final int? currentUserId;

  const ForwardSessionsSheet({
    super.key,
    required this.currentSessionUuid,
    required this.currentUserId,
  });

  @override
  State<ForwardSessionsSheet> createState() => _ForwardSessionsSheetState();
}

class _ForwardSessionsSheetState extends State<ForwardSessionsSheet> {
  final SessionRepository _repository = SessionRepository();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<SessionModel> _allSessions = [];
  List<SessionModel> _filteredSessions = [];
  final Set<String> _selectedSessionUuids = {};
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
        final sessions = response.data
            .where((session) => session.id != widget.currentSessionUuid)
            .toList();
        setState(() {
          _allSessions = sessions;
          _filteredSessions = List.from(sessions);
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
                'Teruskan Pesan',
                style: TextStyle(
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
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari sesi (nama, tiket, topik)...',
              hintStyle:
                  TextStyle(color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.grey.shade400, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      color: Colors.grey.shade400,
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Session list
          Expanded(child: _buildContent()),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Batal',
                    style:
                        TextStyle(color: Colors.grey.shade700, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _selectedSessionUuids.isEmpty
                      ? null
                      : () => Navigator.pop(
                          context, _selectedSessionUuids.toList()),
                  child: Text(
                    _selectedSessionUuids.isEmpty
                        ? 'Teruskan'
                        : 'Teruskan (${_selectedSessionUuids.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
              style: const TextStyle(color: Colors.red, fontSize: 14),
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
              'Tidak ada sesi aktif lainnya',
              style: TextStyle(color: Colors.grey, fontSize: 14),
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
            Icon(Icons.search_off_rounded,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text(
              'Sesi tidak ditemukan',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Coba kata kunci lain',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
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

        final isSelected = _selectedSessionUuids.contains(session.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? AppColors.primary : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedSessionUuids.remove(session.id);
                } else {
                  _selectedSessionUuids.add(session.id);
                }
              });
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedSessionUuids.add(session.id);
                        } else {
                          _selectedSessionUuids.remove(session.id);
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opponentName,
                          style: const TextStyle(
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
                                color: Colors.grey.shade600,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (session.topicName != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                '•',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 11),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  session.topicName!,
                                  style: const TextStyle(
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
