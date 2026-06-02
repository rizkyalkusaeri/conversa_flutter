import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';

class BadgeService {
  BadgeService._();

  static int currentBadgeCount = 0;

  /// Memperbarui badge launcher dengan jumlah tertentu
  static Future<void> updateBadge(int count) async {
    currentBadgeCount = count;
    try {
      final isSupported = await AppBadgePlus.isSupported();
      if (isSupported) {
        await AppBadgePlus.updateBadge(count);
        debugPrint('BadgeService: Badge launcher diperbarui menjadi $count');
      } else {
        debugPrint('BadgeService: Badge launcher tidak didukung pada perangkat ini');
      }
    } catch (e) {
      debugPrint('BadgeService: Gagal memperbarui badge launcher: $e');
    }
  }

  /// Menghapus/mereset badge launcher menjadi 0
  static Future<void> clearBadge() async {
    currentBadgeCount = 0;
    try {
      final isSupported = await AppBadgePlus.isSupported();
      if (isSupported) {
        await AppBadgePlus.updateBadge(0);
        debugPrint('BadgeService: Badge launcher berhasil dihapus/direset');
      }
    } catch (e) {
      debugPrint('BadgeService: Gagal menghapus badge launcher: $e');
    }
  }
}
