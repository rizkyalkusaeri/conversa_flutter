import 'package:fifgroup_android_ticketing/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// Bottom sheet multi-select generik yang dapat digunakan kembali.
///
/// Menampilkan daftar pilihan dengan search bar dan checkbox multi-select.
/// Type-safe menggunakan generics — dapat digunakan untuk jabatan, user,
/// kategori, atau data lainnya.
///
/// Contoh penggunaan:
/// ```dart
/// await showModalBottomSheet(
///   context: context,
///   builder: (_) => MultiSelectBottomSheet<LevelModel>(
///     title: 'Pilih Jabatan',
///     searchHint: 'Cari jabatan...',
///     options: allLevels,
///     initialSelected: selectedLevels,
///     labelBuilder: (l) => l.name,
///     onConfirm: (selected) => setState(() => _selectedLevels = selected),
///   ),
/// );
/// ```
class MultiSelectBottomSheet<T> extends StatefulWidget {
  final String title;
  final String searchHint;
  final List<T> options;
  final List<T> initialSelected;
  final String Function(T item) labelBuilder;
  final ValueChanged<List<T>> onConfirm;

  const MultiSelectBottomSheet({
    super.key,
    required this.title,
    this.searchHint = 'Cari...',
    required this.options,
    required this.initialSelected,
    required this.labelBuilder,
    required this.onConfirm,
  });

  @override
  State<MultiSelectBottomSheet<T>> createState() =>
      _MultiSelectBottomSheetState<T>();
}

class _MultiSelectBottomSheetState<T> extends State<MultiSelectBottomSheet<T>> {
  late List<T> _selected;
  late List<T> _filtered;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
    _filtered = List.from(widget.options);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? List.from(widget.options)
          : widget.options
                .where(
                  (item) => widget
                      .labelBuilder(item)
                      .toLowerCase()
                      .contains(query.toLowerCase()),
                )
                .toList();
    });
  }

  bool _isSelected(T item) {
    return _selected.any((s) => s == item);
  }

  void _toggle(T item) {
    setState(() {
      if (_isSelected(item)) {
        _selected.removeWhere((s) => s == item);
      } else {
        _selected.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    if (_selected.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _selected.clear()),
                        child: const Text(
                          'Hapus Semua',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearch,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: Colors.grey.shade500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),

              const Divider(height: 1),

              // Options list
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada pilihan',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
                          final selected = _isSelected(item);
                          return InkWell(
                            onTap: () => _toggle(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.labelBuilder(item),
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: selected
                                            ? AppColors.primary
                                            : AppColors.textDark,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.primary
                                            : Colors.grey.shade400,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: selected
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Confirm button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onConfirm(List.from(_selected));
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Selesai${_selected.isNotEmpty ? " (${_selected.length})" : ""}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
