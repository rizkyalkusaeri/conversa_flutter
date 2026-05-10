import 'dart:io';
import 'package:image_picker/image_picker.dart';

class FileValidator {
  static const int maxFileSizeBytes = 20 * 1024 * 1024; // 20MB
  static const String maxFileSizeLabel = '20MB';

  /// Validasi ukuran file. Throws [Exception] jika melebihi batas.
  static Future<void> validateSize(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File tidak ditemukan.');
    }
    
    final fileSize = await file.length();
    if (fileSize > maxFileSizeBytes) {
      throw Exception(
        'Ukuran file terlalu besar (${_formatBytes(fileSize)}). Maksimal $maxFileSizeLabel.',
      );
    }
  }

  /// Validasi ukuran dari XFile (image picker)
  static Future<void> validateXFile(XFile file) async {
    final fileSize = await file.length();
    if (fileSize > maxFileSizeBytes) {
      throw Exception(
        'Ukuran file terlalu besar (${_formatBytes(fileSize)}). Maksimal $maxFileSizeLabel.',
      );
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
