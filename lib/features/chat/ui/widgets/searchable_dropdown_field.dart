import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/master_data_model.dart';

class SearchableDropdownField extends StatefulWidget {
  final MasterDataModel? selectedItem;
  final String hintText;
  final Future<List<MasterDataModel>> Function(String keyword) onSearch;
  final ValueChanged<MasterDataModel?> onChanged;
  final Widget? prefixIcon;

  const SearchableDropdownField({
    super.key,
    required this.selectedItem,
    required this.hintText,
    required this.onSearch,
    required this.onChanged,
    this.prefixIcon,
  });

  @override
  State<SearchableDropdownField> createState() => _SearchableDropdownFieldState();
}

class _SearchableDropdownFieldState extends State<SearchableDropdownField> {
  void _openSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchSheetContent(onSearch: widget.onSearch),
    ).then((selected) {
      if (selected != null && selected is MasterDataModel) {
        widget.onChanged(selected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openSearchSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            if (widget.prefixIcon != null) ...[
              widget.prefixIcon!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                widget.selectedItem?.text ?? widget.hintText,
                style: TextStyle(
                  color: widget.selectedItem == null ? const Color(0xFF9CA3AF) : AppColors.textDark,
                  fontSize: 15,
                  fontWeight: widget.selectedItem == null ? FontWeight.normal : FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4B5563)),
          ],
        ),
      ),
    );
  }
}

class _SearchSheetContent extends StatefulWidget {
  final Future<List<MasterDataModel>> Function(String keyword) onSearch;

  const _SearchSheetContent({required this.onSearch});

  @override
  State<_SearchSheetContent> createState() => _SearchSheetContentState();
}

class _SearchSheetContentState extends State<_SearchSheetContent> {
  final TextEditingController _searchController = TextEditingController();
  List<MasterDataModel> _results = [];
  bool _isLoading = true;
  Timer? _debounce;
  String _lastError = '';

  @override
  void initState() {
    super.initState();
    // Default awal load tanpa kata kunci
    _fetchResults('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    // Debounce hit API 500ms
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchResults(query);
    });
  }

  Future<void> _fetchResults(String query) async {
    setState(() {
      _isLoading = true;
      _lastError = '';
    });
    try {
      final data = await widget.onSearch(query);
      if (mounted) {
        setState(() {
          _results = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastError = 'Gagal mencari data. Cek koneksi Anda.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          // Search Input
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "Cari data...",
                hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // List View Builder
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lastError.isNotEmpty) {
      return Center(child: Text(_lastError, style: const TextStyle(color: Colors.red)));
    }
    if (_results.isEmpty) {
      return const Center(child: Text("Data tidak ditemukan.", style: TextStyle(color: Colors.grey)));
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: _results.length,
      separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100, height: 1),
      itemBuilder: (context, index) {
        final item = _results[index];
        return ListTile(
          title: Text(item.text, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textDark)),
          onTap: () {
            Navigator.pop(context, item);
          },
        );
      },
    );
  }
}
