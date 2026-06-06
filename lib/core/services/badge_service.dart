import 'package:flutter/foundation.dart';

/// BadgeService — cache in-memory untuk jumlah sesi aktif.
///
/// Nilai ini digunakan sebagai `number` field pada notifikasi yang ditampilkan,
/// sehingga launcher icon menampilkan badge count sesuai jumlah sesi aktif.
///
/// Badge count mengikuti siklus notifikasi:
/// - Ada notifikasi di tray → badge tampil
/// - Notifikasi di-clear → badge hilang (perilaku yang diharapkan)
/// - Buka app → notifikasi di-clear → badge hilang
class BadgeService {
  BadgeService._();

  static int _currentCount = 0;

  /// Jumlah sesi aktif saat ini (in-memory).
  /// Digunakan oleh NotificationService sebagai nilai `number` pada notifikasi.
  static int get currentBadgeCount => _currentCount;

  /// Perbarui cache jumlah sesi aktif.
  /// Dipanggil oleh [ActiveSessionCountCubit.fetchCount()] setiap kali count berubah.
  static void setCount(int count) {
    _currentCount = count;
    debugPrint('BadgeService: Active session count updated → $count');
  }

  /// Reset count ke 0. Dipanggil saat logout.
  static void reset() {
    _currentCount = 0;
    debugPrint('BadgeService: Count reset → 0');
  }
}
