import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/widgets/multi_select_bottom_sheet.dart';
import '../../../../core/widgets/paged_multi_select_bottom_sheet.dart';
import '../../../../core/widgets/selected_chips_row.dart';

/// Model lokal untuk data jabatan (level) di form thread.
class LevelItem {
  final int id;
  final String name;
  const LevelItem({required this.id, required this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LevelItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Model lokal untuk data user di form thread.
class UserItem {
  final int id;
  final String fullName;
  const UserItem({required this.id, required this.fullName});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Widget selector dua-tingkat: Jabatan → User Spesifik.
///
/// Fitur utama:
/// - Memuat daftar jabatan dari API GET /master/levels
/// - Saat jabatan dipilih, memuat user dari GET /master/users-by-level
/// - Auto-clear pilihan user saat jabatan di-clear
/// - Disabled state pada user selector jika belum ada jabatan dipilih
///
/// Widget ini dapat digunakan di halaman Create Thread maupun Edit Thread.
///
/// Contoh penggunaan:
/// ```dart
/// ThreadTargetSelector(
///   initialLevelIds: widget.editThread?.selectedLevelIds ?? [],
///   initialUserIds: widget.editThread?.selectedUserIds ?? [],
///   onLevelsChanged: (ids) => setState(() => _selectedLevelIds = ids),
///   onUsersChanged: (ids) => setState(() => _selectedUserIds = ids),
/// )
/// ```
class ThreadTargetSelector extends StatefulWidget {
  final List<int> initialLevelIds;
  final List<int> initialUserIds;
  final ValueChanged<List<int>> onLevelsChanged;
  final ValueChanged<List<int>> onUsersChanged;

  const ThreadTargetSelector({
    super.key,
    this.initialLevelIds = const [],
    this.initialUserIds = const [],
    required this.onLevelsChanged,
    required this.onUsersChanged,
  });

  @override
  State<ThreadTargetSelector> createState() => _ThreadTargetSelectorState();
}

class _ThreadTargetSelectorState extends State<ThreadTargetSelector> {
  final Dio _dio = DioClient.getInstance;

  // Data untuk dropdown
  List<LevelItem> _allLevels = [];
  List<UserItem> _availableUsers = [];

  // Pilihan yang sedang aktif
  List<LevelItem> _selectedLevels = [];
  List<UserItem> _selectedUsers = [];

  // State loading
  bool _isLoadingLevels = false;
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  // ─── Data Loading ───────────────────────────────────────────────────────────

  Future<void> _loadLevels() async {
    setState(() => _isLoadingLevels = true);
    try {
      final response = await _dio.get(
        '/master/levels',
        queryParameters: {'limit': 100},
      );
      final items = response.data['data'] as List<dynamic>? ?? [];
      setState(() {
        _allLevels = items
            .map(
              (e) => LevelItem(
                id: e['id'] as int,
                name: e['name'] as String? ?? '',
              ),
            )
            .toList();

        // Pre-populate jika ada initialLevelIds (mode edit)
        if (widget.initialLevelIds.isNotEmpty) {
          _selectedLevels = _allLevels
              .where((l) => widget.initialLevelIds.contains(l.id))
              .toList();
        }
      });

      // Jika ada initialLevelIds, load users for pre-populate
      if (widget.initialLevelIds.isNotEmpty) {
        await _loadUsersForLevels(
          widget.initialLevelIds,
          preSelectedIds: widget.initialUserIds,
        );
      }
    } catch (e) {
      debugPrint('ThreadTargetSelector: Gagal load levels — $e');
    } finally {
      if (mounted) setState(() => _isLoadingLevels = false);
    }
  }

  Future<void> _loadUsersForLevels(
    List<int> levelIds, {
    List<int> preSelectedIds = const [],
  }) async {
    if (levelIds.isEmpty) {
      setState(() {
        _availableUsers = [];
        _selectedUsers = [];
      });
      return;
    }

    setState(() => _isLoadingUsers = true);
    try {
      final queryParams = <String, dynamic>{};

      // Jika ada preSelectedIds (mode edit), kita HANYA load user-user tersebut
      // agar tidak overload memuat ribuan user dari level terkait.
      if (preSelectedIds.isNotEmpty) {
        for (int i = 0; i < preSelectedIds.length; i++) {
          queryParams['user_ids[$i]'] = preSelectedIds[i];
        }
      } else {
        // Jika tidak ada pre-selected, kita load page pertama saja (atau tidak usah load
        // karena sekarang pakai infinite scroll di picker).
        // Tapi kita tetap butuh _selectedUsers tetap konsisten.
        _selectedUsers = _selectedUsers
            .where((u) => widget.initialUserIds.contains(u.id)) // dummy safety
            .toList();
        return;
      }

      final response = await _dio.get(
        '/master/users-by-level',
        queryParameters: queryParams,
      );
      final items = response.data['data'] as List<dynamic>? ?? [];

      setState(() {
        final loadedUsers = items
            .map(
              (e) => UserItem(
                id: e['id'] as int,
                fullName: e['full_name'] as String? ?? '',
              ),
            )
            .toList();

        if (preSelectedIds.isNotEmpty) {
          _selectedUsers = loadedUsers;
          // Kita juga masukkan ke availableUsers agar chips bisa tampil
          _availableUsers = loadedUsers;
        }
      });
    } catch (e) {
      debugPrint('ThreadTargetSelector: Gagal load users — $e');
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  // ─── Event Handlers ─────────────────────────────────────────────────────────

  void _onLevelsConfirmed(List<LevelItem> levels) {
    setState(() {
      _selectedLevels = levels;
      // Auto-clear user saat jabatan berubah
      _selectedUsers = [];
    });

    widget.onLevelsChanged(levels.map((l) => l.id).toList());
    widget.onUsersChanged([]);

    // Kita tidak perlu loadUsersForLevels di sini karena picker sudah handle paged load
  }

  void _onRemoveLevel(LevelItem level) {
    final updated = List<LevelItem>.from(_selectedLevels)..remove(level);
    _onLevelsConfirmed(updated);
  }

  void _onUsersConfirmed(List<UserItem> users) {
    setState(() {
      _selectedUsers = users;
      // Tambahkan ke available agar chips tidak hilang jika belum ada
      for (var u in users) {
        if (!_availableUsers.any((au) => au.id == u.id)) {
          _availableUsers.add(u);
        }
      }
    });
    widget.onUsersChanged(users.map((u) => u.id).toList());
  }

  void _onRemoveUser(UserItem user) {
    final updated = List<UserItem>.from(_selectedUsers)..remove(user);
    setState(() => _selectedUsers = updated);
    widget.onUsersChanged(updated.map((u) => u.id).toList());
  }

  // ─── Bottom Sheets ──────────────────────────────────────────────────────────

  Future<void> _openLevelPicker() async {
    if (_isLoadingLevels || _allLevels.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiSelectBottomSheet<LevelItem>(
        title: 'Pilih Jabatan',
        searchHint: 'Cari jabatan...',
        options: _allLevels,
        initialSelected: _selectedLevels,
        labelBuilder: (l) => l.name,
        onConfirm: _onLevelsConfirmed,
      ),
    );
  }

  Future<void> _openUserPicker() async {
    if (_selectedLevels.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PagedMultiSelectBottomSheet<UserItem>(
        title: 'Pilih User Spesifik',
        searchHint: 'Cari nama...',
        initialSelected: _selectedUsers,
        labelBuilder: (u) => u.fullName,
        onLoad: (page, search) async {
          final levelIds = _selectedLevels.map((l) => l.id).toList();
          final queryParams = <String, dynamic>{
            'page': page,
            'search': search,
            'limit': 20,
          };
          for (int i = 0; i < levelIds.length; i++) {
            queryParams['level_ids[$i]'] = levelIds[i];
          }

          final response = await _dio.get(
            '/master/users-by-level',
            queryParameters: queryParams,
          );

          final items = (response.data['data'] as List<dynamic>)
              .map(
                (e) => UserItem(
                  id: e['id'] as int,
                  fullName: e['full_name'] as String? ?? '',
                ),
              )
              .toList();

          final meta = response.data['meta'];
          final hasMore = meta['current_page'] < meta['last_page'];

          return PagedResult(items: items, hasMore: hasMore);
        },
        onConfirm: _onUsersConfirmed,
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─ Header divider
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Visibilitas Thread',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
        ),

        // ─ Section 1: Jabatan
        _buildSectionCard(
          icon: Icons.badge_outlined,
          title: '🏷️  Jabatan Yang Dapat Melihat',
          subtitle:
              'Kosongkan agar semua user dapat melihat & menerima notifikasi',
          child: _isLoadingLevels
              ? const _LoadingChips()
              : SelectedChipsRow<LevelItem>(
                  label: '',
                  emptyHint: 'Semua jabatan (thread publik)',
                  selected: _selectedLevels,
                  labelBuilder: (l) => l.name,
                  onAddTap: _openLevelPicker,
                  onRemove: _onRemoveLevel,
                  addLabel: 'Tambah Jabatan',
                ),
        ),

        const SizedBox(height: 10),

        // ─ Section 2: User Spesifik
        _buildSectionCard(
          icon: Icons.person_outline,
          title: '👤  User Spesifik  (opsional)',
          subtitle: _selectedLevels.isEmpty
              ? null
              : 'Kosongkan = notifikasi ke semua user jabatan terpilih',
          child: _isLoadingUsers
              ? const _LoadingChips()
              : SelectedChipsRow<UserItem>(
                  label: '',
                  emptyHint: 'Semua user jabatan terpilih',
                  selected: _selectedUsers,
                  labelBuilder: (u) => u.fullName,
                  onAddTap: _openUserPicker,
                  onRemove: _onRemoveUser,
                  disabled: _selectedLevels.isEmpty,
                  addLabel: 'Tambah User',
                ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Widget placeholder saat data sedang dimuat.
class _LoadingChips extends StatelessWidget {
  const _LoadingChips();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary.withAlpha(150),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Memuat...',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
