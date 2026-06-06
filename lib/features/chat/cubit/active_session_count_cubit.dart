import 'dart:async';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:fifgroup_android_ticketing/data/repositories/session_repository.dart';
import 'package:fifgroup_android_ticketing/core/services/realtime_event_bus.dart';
import 'package:fifgroup_android_ticketing/core/services/badge_service.dart';
import 'active_session_count_state.dart';

class ActiveSessionCountCubit extends Cubit<ActiveSessionCountState> {
  final SessionRepository _repository;
  StreamSubscription<void>? _refreshSubscription;

  ActiveSessionCountCubit({SessionRepository? repository})
      : _repository = repository ?? SessionRepository(),
        super(ActiveSessionCountInitial()) {
    _refreshSubscription =
        RealtimeEventBus.instance.onSessionRefresh.listen((_) {
      fetchCount();
    });
  }

  Future<int> fetchCount() async {
    emit(ActiveSessionCountLoading());
    try {
      final response = await _repository.fetchSessions('active', 1);
      final count = response.meta.total;

      // Simpan ke in-memory cache
      BadgeService.setCount(count);

      // Set badge launcher secara eksplisit via app_badge_plus.
      // Ini terpisah dari notifikasi sehingga badge TIDAK dipengaruhi
      // jumlah notifikasi di tray — badge = jumlah sesi aktif yang sesungguhnya.
      _applyBadge(count);

      emit(ActiveSessionCountLoaded(count));
      return count;
    } catch (e) {
      emit(ActiveSessionCountError(e.toString().replaceFirst('Exception: ', '')));
      return 0;
    }
  }

  /// Set badge launcher menggunakan app_badge_plus.
  /// Fire-and-forget (tidak di-await) agar tidak memblokir UI.
  static void _applyBadge(int count) {
    AppBadgePlus.isSupported().then((supported) {
      if (supported) {
        AppBadgePlus.updateBadge(count).then((_) {
          debugPrint('Badge launcher → $count');
        }).catchError((e) {
          debugPrint('Badge update error: $e');
        });
      }
    }).catchError((e) {
      debugPrint('Badge isSupported error: $e');
    });
  }

  @override
  Future<void> close() {
    _refreshSubscription?.cancel();
    return super.close();
  }
}
