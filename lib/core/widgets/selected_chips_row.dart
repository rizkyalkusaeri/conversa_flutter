import 'package:fifgroup_android_ticketing/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// Widget baris chips horizontal yang menampilkan item yang sudah dipilih.
///
/// Menampilkan setiap item sebagai chip yang bisa di-dismiss (×).
/// Di akhir baris terdapat tombol "+ Tambah" untuk membuka selector.
/// Mendukung disabled state (saat parent belum memilih prerequisite).
///
/// Widget ini bersifat reusable dan dapat digunakan untuk menampilkan
/// jabatan terpilih, user terpilih, kategori terpilih, dll.
///
/// Contoh penggunaan:
/// ```dart
/// SelectedChipsRow<LevelModel>(
///   label: 'Jabatan',
///   emptyHint: 'Semua jabatan',
///   selected: _selectedLevels,
///   labelBuilder: (l) => l.name,
///   onAddTap: () => _openLevelPicker(),
///   onRemove: (l) => setState(() => _selectedLevels.remove(l)),
/// )
/// ```
class SelectedChipsRow<T> extends StatelessWidget {
  final String label;
  final String? subtitle;
  final String emptyHint;
  final List<T> selected;
  final String Function(T item) labelBuilder;
  final VoidCallback onAddTap;
  final ValueChanged<T> onRemove;
  final bool disabled;
  final String addLabel;

  const SelectedChipsRow({
    super.key,
    required this.label,
    this.subtitle,
    required this.emptyHint,
    required this.selected,
    required this.labelBuilder,
    required this.onAddTap,
    required this.onRemove,
    this.disabled = false,
    this.addLabel = 'Tambah',
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Chips row
          SizedBox(
            height: 38,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // Chips item terpilih
                  ...selected.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildChip(item),
                    ),
                  ),

                  // Tombol "Tambah"
                  _buildAddButton(context),
                ],
              ),
            ),
          ),

          // Hint jika kosong
          if (selected.isEmpty && !disabled)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                emptyHint,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          if (disabled)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Pilih jabatan terlebih dahulu',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChip(T item) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            labelBuilder(item),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: disabled ? null : () => onRemove(item),
            child: const Icon(Icons.close, size: 15, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onAddTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: disabled
                ? Colors.grey.shade300
                : AppColors.primary.withAlpha(120),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add,
              size: 15,
              color: disabled ? Colors.grey.shade400 : AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              addLabel,
              style: TextStyle(
                fontSize: 13,
                color: disabled ? Colors.grey.shade400 : AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
