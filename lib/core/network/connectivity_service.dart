import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:flutter/foundation.dart';

enum ConnectivityStatus { online, offline }

/// Single source of truth untuk status konektivitas internet.
///
/// Cara kerja:
///   1. [connectivity_plus] mendeteksi perubahan interface jaringan (WiFi on/off).
///   2. [internet_connection_checker_plus] melakukan TCP ping untuk konfirmasi
///      internet nyata — membedakan "WiFi nyala tapi captive portal / no internet"
///      vs "benar-benar online".
///
/// Gunakan [onStatusChange] untuk reactive listening di widget atau service lain.
/// Gunakan [isOnline] untuk pengecekan sinkron kapanpun dibutuhkan.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  // ---------------------------------------------------------------------------
  // Internal State
  // ---------------------------------------------------------------------------
  ConnectivityStatus _currentStatus = ConnectivityStatus.online;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  final _statusController = StreamController<ConnectivityStatus>.broadcast();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Stream perubahan status konektivitas. Broadcast — aman untuk multi-subscriber.
  Stream<ConnectivityStatus> get onStatusChange => _statusController.stream;

  /// Status konektivitas saat ini (sinkron).
  ConnectivityStatus get currentStatus => _currentStatus;

  /// `true` jika internet tersedia saat ini.
  bool get isOnline => _currentStatus == ConnectivityStatus.online;

  // ---------------------------------------------------------------------------
  // Init & Dispose
  // ---------------------------------------------------------------------------

  /// Inisialisasi service. Panggil SATU KALI dari [main()] sebelum [runApp()].
  Future<void> init() async {
    // Cek kondisi awal tanpa menunggu lama — non-blocking
    unawaited(_checkAndUpdate());

    // Listen perubahan interface jaringan secara reaktif
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (results) async {
        // Jika tidak ada interface aktif sama sekali → langsung offline
        if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
          _updateStatus(ConnectivityStatus.offline);
          return;
        }
        // Ada interface aktif → konfirmasi dengan TCP ping
        await _checkAndUpdate();
      },
    );
  }

  /// Periksa apakah ada internet sungguhan (TCP ping, bukan hanya interface check).
  /// Async — gunakan untuk one-shot check sebelum operasi penting.
  Future<bool> hasRealInternet() async {
    try {
      return await InternetConnection().hasInternetAccess;
    } catch (e) {
      debugPrint('[ConnectivityService] hasRealInternet error: $e');
      return false;
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    if (!_statusController.isClosed) {
      _statusController.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _checkAndUpdate() async {
    final hasInternet = await hasRealInternet();
    _updateStatus(
      hasInternet ? ConnectivityStatus.online : ConnectivityStatus.offline,
    );
  }

  void _updateStatus(ConnectivityStatus newStatus) {
    if (_currentStatus == newStatus) return; // Tidak ada perubahan, skip emit
    _currentStatus = newStatus;
    debugPrint('[ConnectivityService] Status: $newStatus');
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }
}
