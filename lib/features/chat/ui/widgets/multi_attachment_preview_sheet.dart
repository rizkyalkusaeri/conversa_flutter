import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/app_colors.dart';

const int _kMaxFiles = 5;
const int _kMaxFileSizeBytes = 20 * 1024 * 1024; // 20 MB

/// Bottom sheet untuk preview dan konfirmasi multiple attachment sebelum dikirim.
/// Mendukung gambar (thumbnail), video, dan dokumen.
/// User dapat menghapus item individual atau menambah file sebelum mengirim semua.
class MultiAttachmentPreviewSheet extends StatefulWidget {
  final List<XFile> initialFiles;
  final String? sourceType; // 'gallery' | 'document' | 'camera'

  const MultiAttachmentPreviewSheet({
    super.key,
    required this.initialFiles,
    this.sourceType,
  });

  @override
  State<MultiAttachmentPreviewSheet> createState() =>
      _MultiAttachmentPreviewSheetState();
}

class _MultiAttachmentPreviewSheetState
    extends State<MultiAttachmentPreviewSheet> {
  late List<_AttachmentItem> _items;

  static const _imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif'};
  static const _videoExts = {'mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'};

  @override
  void initState() {
    super.initState();
    // _toItemSync hanya cek ekstensi — tidak ada I/O sama sekali
    _items = widget.initialFiles.map(_toItemSync).toList();
    // Load ukuran file secara async agar main thread tidak terblokir
    _loadFileSizes(0);
  }

  /// Buat item dengan type saja; sizeBytes = 0 & loadingSize = true.
  /// Tidak ada I/O sinkron di sini.
  _AttachmentItem _toItemSync(XFile file) {
    final ext = file.path.toLowerCase().split('.').last;
    final type = _imageExts.contains(ext)
        ? _FileType.image
        : _videoExts.contains(ext)
            ? _FileType.video
            : _FileType.document;
    return _AttachmentItem(file: file, type: type, sizeBytes: 0, oversized: false, loadingSize: true);
  }

  /// Load ukuran file satu per satu mulai index [startIndex], async.
  Future<void> _loadFileSizes(int startIndex) async {
    for (int i = startIndex; i < _items.length; i++) {
      if (!mounted) return;
      try {
        final size = await File(_items[i].file.path).length();
        if (!mounted) return;
        setState(() {
          _items[i] = _items[i].withSize(size);
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _items[i] = _items[i].withSize(0);
        });
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
    if (_items.isEmpty) Navigator.pop(context, null);
  }

  Future<void> _addMoreFiles() async {
    final messenger = ScaffoldMessenger.of(context);
    final remaining = _kMaxFiles - _items.length;
    if (remaining <= 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Maksimal $_kMaxFiles file per pengiriman.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    List<XFile> newFiles = [];

    if (widget.sourceType == 'document') {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
      );
      if (result != null) {
        newFiles = result.files
            .where((f) => f.path != null)
            .map((f) => XFile(f.path!, name: f.name))
            .toList();
      }
    } else {
      // Default: gallery
      final picker = ImagePicker();
      newFiles = await picker.pickMultipleMedia();
    }

    if (!mounted) return;

    if (newFiles.isEmpty) return;

    // Batasi agar total tidak melebihi max
    final canAdd = newFiles.take(remaining).toList();
    final skipped = newFiles.length - canAdd.length;
    final insertFrom = _items.length;

    setState(() {
      _items.addAll(canAdd.map(_toItemSync));
    });
    // Load ukuran file baru secara async
    _loadFileSizes(insertFrom);

    if (skipped > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$skipped file diabaikan karena melebihi batas $_kMaxFiles file.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _sendAll() {
    final validItems = _items.where((it) => !it.oversized).toList();
    final invalidCount = _items.length - validItems.length;

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua file melebihi batas 20MB. Tidak ada yang dikirim.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (invalidCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$invalidCount file diabaikan karena melebihi batas 20MB.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    Navigator.pop(context, validItems.map((it) => it.file).toList());
  }

  @override
  Widget build(BuildContext context) {
    final isLoadingSizes = _items.any((it) => it.loadingSize);
    final validCount = _items.where((it) => !it.oversized && !it.loadingSize).length;
    final hasOversized = _items.any((it) => it.oversized);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_items.length} File Dipilih',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Spacer(),
                if (hasOversized)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 12, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Ada file >20MB',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

          // File list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                indent: 72,
                color: Color(0xFFF3F4F6),
              ),
              itemBuilder: (ctx, index) {
                final item = _items[index];
                return _AttachmentTile(
                  item: item,
                  formatSize: _formatSize,
                  onRemove: () => _removeItem(index),
                );
              },
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

          // Action buttons
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Row(
              children: [
                // Tambah file — icon button kompak dengan badge sisa slot
                if (_items.length < _kMaxFiles) ...[
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primary, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          onPressed: _addMoreFiles,
                          icon: const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          tooltip: 'Tambah file (${_kMaxFiles - _items.length} slot tersisa)',
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '+${_kMaxFiles - _items.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                ],

                // Kirim button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (isLoadingSizes || validCount == 0) ? null : _sendAll,
                    icon: isLoadingSizes
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: Text(
                      isLoadingSizes
                          ? 'Memeriksa...'
                          : validCount < _items.length
                              ? 'Kirim $validCount File (${_items.length - validCount} diabaikan)'
                              : 'Kirim Semua ($validCount)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data helpers
// ─────────────────────────────────────────────────────────────────────────────

enum _FileType { image, video, document }

class _AttachmentItem {
  final XFile file;
  final _FileType type;
  final int sizeBytes;
  final bool oversized;
  final bool loadingSize; // true saat ukuran file belum dimuat

  const _AttachmentItem({
    required this.file,
    required this.type,
    required this.sizeBytes,
    required this.oversized,
    this.loadingSize = false,
  });

  /// Kembalikan salinan item dengan sizeBytes yang sudah dimuat.
  _AttachmentItem withSize(int bytes) => _AttachmentItem(
    file: file,
    type: type,
    sizeBytes: bytes,
    oversized: bytes > _kMaxFileSizeBytes,
    loadingSize: false,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual tile widget
// ─────────────────────────────────────────────────────────────────────────────

class _AttachmentTile extends StatelessWidget {
  final _AttachmentItem item;
  final String Function(int) formatSize;
  final VoidCallback onRemove;

  const _AttachmentTile({
    required this.item,
    required this.formatSize,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Thumbnail / icon
          _buildThumbnail(),
          const SizedBox(width: 12),

          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (item.loadingSize)
                      Container(
                        width: 48,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    else
                      Text(
                        formatSize(item.sizeBytes),
                        style: TextStyle(
                          fontSize: 11,
                          color: item.oversized
                              ? Colors.red.shade600
                              : Colors.grey.shade500,
                        ),
                      ),
                    if (item.oversized) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border:
                              Border.all(color: Colors.red.shade200, width: 0.5),
                        ),
                        child: Text(
                          'Melebihi 20MB',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Remove button
          IconButton(
            onPressed: onRemove,
            icon: Icon(
              Icons.close_rounded,
              color: Colors.grey.shade400,
              size: 20,
            ),
            splashRadius: 18,
            tooltip: 'Hapus',
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    final borderRadius = BorderRadius.circular(8);

    if (item.type == _FileType.image) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.file(
          File(item.file.path),
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _iconBox(
            Icons.broken_image_outlined,
            Colors.grey.shade400,
            Colors.grey.shade100,
          ),
        ),
      );
    }

    if (item.type == _FileType.video) {
      return _iconBox(
        Icons.videocam_rounded,
        Colors.blue.shade400,
        Colors.blue.shade50,
      );
    }

    // Document
    return _iconBox(
      Icons.insert_drive_file_rounded,
      AppColors.primary,
      AppColors.primary.withValues(alpha: 0.1),
    );
  }

  Widget _iconBox(IconData icon, Color iconColor, Color bgColor) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: iconColor, size: 26),
    );
  }
}
