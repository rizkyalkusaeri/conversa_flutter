import 'package:flutter/material.dart';
import '../../features/threads/ui/thread_detail_page.dart';

/// Global NavigatorKey untuk navigasi dari luar widget tree.
///
/// Digunakan terutama saat tap notifikasi FCM dari state background
/// atau terminated, di mana BuildContext widget belum/tidak tersedia.
///
/// Setup:
/// 1. Daftarkan ke `MaterialApp.navigatorKey` di `main.dart`
/// 2. Panggil `NavigationService.navigateToThread(uuid)` dari FCM handler
class NavigationService {
  NavigationService._();

  /// Key global yang terhubung ke root Navigator aplikasi.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Navigate ke [ThreadDetailPage] berdasarkan UUID thread.
  ///
  /// Aman dipanggil dari luar widget tree (misal: FCM tap handler,
  /// background isolate yang sudah kembali ke main isolate).
  static Future<void> navigateToThread(String threadUuid) async {
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) {
      debugPrint(
        'NavigationService: navigator belum ready, skip navigate ke thread $threadUuid',
      );
      return;
    }

    debugPrint('NavigationService: navigating to thread $threadUuid');
    await navigatorState.push(
      MaterialPageRoute<void>(
        builder: (_) => ThreadDetailPage(threadUuid: threadUuid),
      ),
    );
  }
}
