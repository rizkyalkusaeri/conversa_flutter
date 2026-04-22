import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Hasil kembalian untuk load data per halaman
class PagedResult<T> {
  final List<T> items;
  final bool hasMore;

  const PagedResult({required this.items, required this.hasMore});
}

/// Callback untuk memuat data per halaman.
typedef PagedLoadFn<T> = Future<PagedResult<T>> Function(
  int page,
  String search,
);

/// Bottom sheet multi-select dengan dukungan Infinite Scroll / Pagination.
/// Cocok untuk data yang sangat besar (seperti daftar user).
class PagedMultiSelectBottomSheet<T> extends StatefulWidget {
  final String title;
  final String searchHint;
  final List<T> initialSelected;
  final String Function(T item) labelBuilder;
  final PagedLoadFn<T> onLoad;
  final ValueChanged<List<T>> onConfirm;

  const PagedMultiSelectBottomSheet({
    super.key,
    required this.title,
    this.searchHint = 'Cari...',
    required this.initialSelected,
    required this.labelBuilder,
    required this.onLoad,
    required this.onConfirm,
  });

  @override
  State<PagedMultiSelectBottomSheet<T>> createState() =>
      _PagedMultiSelectBottomSheetState<T>();
}

class _PagedMultiSelectBottomSheetState<T>
    extends State<PagedMultiSelectBottomSheet<T>> {
  final List<T> _items = [];
  late List<T> _selected;
  final TextEditingController _searchController = TextEditingController();
  
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _items.clear();
        _hasMore = true;
      });
    }

    if (!_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final result = await widget.onLoad(_currentPage, _searchController.text);
      if (mounted) {
        setState(() {
          _items.addAll(result.items);
          _hasMore = result.hasMore;
          _currentPage++;
        });
      }
    } catch (e) {
      debugPrint('PagedMultiSelect: Error loading data — $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadData(refresh: true);
    });
  }

  bool _isSelected(T item) {
    // Note: T harus mengimplementasikan operator == untuk perbandingan ID
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
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        // Tambahkan listener untuk infinite scroll
        scrollController.addListener(() {
          if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 200) {
            _loadData();
          }
        });

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
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade500),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),

              const Divider(height: 1),

              // Options list
              Expanded(
                child: _items.isEmpty && !_isLoading
                    ? Center(
                        child: Text(
                          'Tidak ada data ditemukan',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _items.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _items.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            );
                          }

                          final item = _items[index];
                          final selected = _isSelected(item);
                          return InkWell(
                            onTap: () => _toggle(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.labelBuilder(item),
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: selected ? AppColors.primary : AppColors.textDark,
                                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  _buildCheckbox(selected),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Selesai${_selected.isNotEmpty ? " (${_selected.length})" : ""}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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

  Widget _buildCheckbox(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : Colors.grey.shade400,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
    );
  }
}
