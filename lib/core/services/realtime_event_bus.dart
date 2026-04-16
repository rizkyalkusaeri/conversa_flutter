import 'dart:async';

/// Simple event bus untuk mengirim signal realtime antar widget
/// tanpa keharusan membagi BuildContext atau Cubit secara langsung.
class RealtimeEventBus {
  RealtimeEventBus._();
  static final RealtimeEventBus instance = RealtimeEventBus._();

  // Track UUID sesi yang sedang aktif dibuka di ChatDetailPage
  // MainPage menggunakannya untuk menghindari notifikasi ganda
  String? activeSessionUuid;

  void setActiveSession(String uuid) {
    activeSessionUuid = uuid;
  }

  void clearActiveSession() {
    activeSessionUuid = null;
  }

  // Stream untuk refresh session list (SessionCreated / SessionUpdated)
  final _sessionRefreshController = StreamController<void>.broadcast();
  Stream<void> get onSessionRefresh => _sessionRefreshController.stream;

  void notifySessionRefresh() {
    if (!_sessionRefreshController.isClosed) {
      _sessionRefreshController.add(null);
    }
  }

  void dispose() {
    _sessionRefreshController.close();
  }
}
