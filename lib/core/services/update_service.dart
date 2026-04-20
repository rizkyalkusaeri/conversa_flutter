import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  /// Mengecek ketersediaan update di Play Store.
  /// Membutuhkan [context] untuk menampilkan snackbar jika proses download selesai.
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // 1. Coba Flexible Update (Background download, user tetap bisa pakai app)
        if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          
          // Tampilkan snackbar jika download selesai
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Update telah siap dipasang.'),
                duration: const Duration(days: 1), // Tahan sampai user klik
                action: SnackBarAction(
                  label: 'PASANG',
                  onPressed: () async {
                    await InAppUpdate.completeFlexibleUpdate();
                  },
                ),
              ),
            );
          }
        } 
        // 2. Jika Flexible tidak tersedia, coba Immediate (Memblokir app sampai beres)
        else if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        }
      }
    } catch (e) {
      debugPrint('UpdateService Error: $e');
    }
  }

  /// Memanggil instalasi jika flexible update sudah didownload secara manual.
  static Future<void> completeFlexibleUpdate() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('UpdateService Complete Error: $e');
    }
  }
}
