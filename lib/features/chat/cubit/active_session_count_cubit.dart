import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:fifgroup_android_ticketing/data/repositories/session_repository.dart';
import 'package:fifgroup_android_ticketing/core/services/realtime_event_bus.dart';
import 'active_session_count_state.dart';

class ActiveSessionCountCubit extends Cubit<ActiveSessionCountState> {
  final SessionRepository _repository;
  StreamSubscription<void>? _refreshSubscription;

  ActiveSessionCountCubit({SessionRepository? repository})
      : _repository = repository ?? SessionRepository(),
        super(ActiveSessionCountInitial()) {
    // Listen to realtime events to automatically refresh the active session count
    _refreshSubscription =
        RealtimeEventBus.instance.onSessionRefresh.listen((_) {
      fetchCount();
    });
  }

  Future<void> fetchCount() async {
    emit(ActiveSessionCountLoading());
    try {
      // Fetch the first page of active sessions to get the meta.total count
      // Using limit=1 would be more efficient if the backend supports it, 
      // but fetchSessions defaults limit to 20 inside SessionService.
      final response = await _repository.fetchSessions('active', 1);
      emit(ActiveSessionCountLoaded(response.meta.total));
    } catch (e) {
      emit(ActiveSessionCountError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  @override
  Future<void> close() {
    _refreshSubscription?.cancel();
    return super.close();
  }
}
