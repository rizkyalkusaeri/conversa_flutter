import 'package:bloc/bloc.dart';
import '../repository/session_repository.dart';
import 'session_list_state.dart';

class SessionListCubit extends Cubit<SessionListState> {
  final SessionRepository _repository;
  final String statusFilter; // 'active' atau 'closed'

  SessionListCubit({
    SessionRepository? repository,
    required this.statusFilter,
  })  : _repository = repository ?? SessionRepository(),
        super(SessionListInitial());

  Future<void> loadInitial() async {
    emit(SessionListLoading());
    try {
      final response = await _repository.fetchSessions(statusFilter, 1);
      emit(SessionListLoaded(
        sessions: response.data,
        hasReachedMax: response.meta.currentPage >= response.meta.lastPage,
        currentPage: 1,
      ));
    } catch (e) {
      emit(SessionListError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> loadMore() async {
    final currentState = state;
    if (currentState is SessionListLoaded && !currentState.hasReachedMax) {
      try {
        final nextPage = currentState.currentPage + 1;
        final response = await _repository.fetchSessions(statusFilter, nextPage);
        
        emit(currentState.copyWith(
          sessions: List.of(currentState.sessions)..addAll(response.data),
          hasReachedMax: response.meta.currentPage >= response.meta.lastPage,
          currentPage: nextPage,
        ));
      } catch (e) {
        // Biarkan state yang ada jika loading next page gagal (Supaya list tidak hilang)
        print("Gagal fetch page: $e");
      }
    }
  }
}
