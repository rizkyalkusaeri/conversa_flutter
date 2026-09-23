import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  /// Memeriksa pembaruan di Google Play Store secara asinkron.
  /// Jika pembaruan tersedia, secara otomatis menampilkan dialog native Android
  /// untuk memulai update (Immediate atau Flexible).
  static Future<void> checkForUpdate() async {
    // In-app updates hanya didukung di platform Android.
    if (!Platform.isAndroid) {
      debugPrint('UpdateService: In-app updates hanya didukung di Android.');
      return;
    }

    try {
      debugPrint('UpdateService: Memulai pengecekan update di Google Play Store...');
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        debugPrint('UpdateService: Update tersedia! Versi baru terdeteksi di Play Store.');

        // 1. Jika Immediate Update diizinkan oleh Google Play, tampilkan dialog layar penuh yang memblokir
        if (info.immediateUpdateAllowed) {
          debugPrint('UpdateService: Melakukan Immediate Update (Force Update)...');
          await InAppUpdate.performImmediateUpdate();
          return;
        }

        // 2. Jika Flexible Update diizinkan, download di background dan minta restart setelah selesai
        if (info.flexibleUpdateAllowed) {
          debugPrint('UpdateService: Melakukan Flexible Update (Background)...');
          final state = await InAppUpdate.startFlexibleUpdate();
          debugPrint('UpdateService: Status Flexible Update = $state');

          // Setelah download sukses, jalankan proses instalasi (restart app)
          debugPrint('UpdateService: Menyelesaikan update, memulai instalasi...');
          await InAppUpdate.completeFlexibleUpdate();
        }
      } else {
        debugPrint('UpdateService: Aplikasi sudah menggunakan versi terbaru.');
      }
    } catch (e, stack) {
      debugPrint('UpdateService: Gagal memeriksa update Google Play — $e');
      debugPrint('UpdateService: Stacktrace — $stack');
    }
  }
}
