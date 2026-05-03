import 'dart:async';

/// Simple event bus untuk mengirim signal realtime antar widget
/// tanpa keharusan membagi BuildContext atau Cubit secara langsung.
class RealtimeEventBus {
  RealtimeEventBus._();
  static final RealtimeEventBus instance = RealtimeEventBus._();

  // ---------------------------------------------------------------------------
  // Active Session Tracking
  // ---------------------------------------------------------------------------
  // Track UUID sesi yang sedang aktif dibuka di ChatDetailPage.
  // MainPage menggunakannya untuk menghindari notifikasi ganda saat user
  // sudah berada di dalam chat tersebut.
  String? activeSessionUuid;

  void setActiveSession(String uuid) {
    activeSessionUuid = uuid;
  }

  void clearActiveSession() {
    activeSessionUuid = null;
  }

  // ---------------------------------------------------------------------------
  // Stream: Session List Refresh
  // ---------------------------------------------------------------------------
  // Dipicu saat ada SessionCreated atau SessionUpdated dari Echo/MainPage.
  // ChatPage (SessionListView) subscribe ini untuk refresh daftar sesi.
  final _sessionRefreshController = StreamController<void>.broadcast();
  Stream<void> get onSessionRefresh => _sessionRefreshController.stream;

  void notifySessionRefresh() {
    if (!_sessionRefreshController.isClosed) {
      _sessionRefreshController.add(null);
    }
  }

  // ---------------------------------------------------------------------------
  // Stream: Session Updated (dengan data)
  // ---------------------------------------------------------------------------
  // Dipicu saat MainPage menerima event .SessionUpdated dari Echo.
  // Membawa session_uuid agar ChatDetailPage bisa filter apakah sesi
  // yang sedang dibuka adalah sesi yang diupdate.
  //
  // Payload: Map berisi minimal {'session_uuid': String}
  final _sessionUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onSessionUpdated =>
      _sessionUpdatedController.stream;

  void notifySessionUpdated(Map<String, dynamic> data) {
    if (!_sessionUpdatedController.isClosed) {
      _sessionUpdatedController.add(data);
    }
  }

  // ---------------------------------------------------------------------------
  // Stream: Thread List Refresh
  // ---------------------------------------------------------------------------
  // Dipicu saat user pindah tab ke Threads atau saat ada thread baru.
  final _threadRefreshController = StreamController<void>.broadcast();
  Stream<void> get onThreadRefresh => _threadRefreshController.stream;

  void notifyThreadRefresh() {
    if (!_threadRefreshController.isClosed) {
      _threadRefreshController.add(null);
    }
  }

  // ---------------------------------------------------------------------------
  // Stream: Search Refresh
  // ---------------------------------------------------------------------------
  // Dipicu saat user pindah tab ke Pencarian.
  final _searchRefreshController = StreamController<void>.broadcast();
  Stream<void> get onSearchRefresh => _searchRefreshController.stream;

  void notifySearchRefresh() {
    if (!_searchRefreshController.isClosed) {
      _searchRefreshController.add(null);
    }
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------
  void dispose() {
    _sessionRefreshController.close();
    _sessionUpdatedController.close();
    _threadRefreshController.close();
    _searchRefreshController.close();
  }
}
