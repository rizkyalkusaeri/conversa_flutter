import 'package:bloc/bloc.dart';
import 'package:fifgroup_android_ticketing/data/repositories/session_repository.dart';
import 'session_list_state.dart';

class SessionListCubit extends Cubit<SessionListState> {
  final SessionRepository _repository;
  String statusFilter; // 'active' atau 'closed'

  SessionListCubit({SessionRepository? repository, required this.statusFilter})
    : _repository = repository ?? SessionRepository(),
      super(SessionListInitial());

  Future<void> loadInitial({String searchQuery = '', String? newStatusFilter}) async {
    if (newStatusFilter != null) {
      statusFilter = newStatusFilter;
    }
    emit(SessionListLoading());
    try {
      final response = await _repository.fetchSessions(statusFilter, 1, search: searchQuery);
      emit(
        SessionListLoaded(
          sessions: response.data,
          hasReachedMax: response.meta.currentPage >= response.meta.lastPage,
          currentPage: 1,
          searchQuery: searchQuery,
        ),
      );
    } catch (e) {
      emit(SessionListError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> loadMore() async {
    final currentState = state;
    if (currentState is SessionListLoaded && !currentState.hasReachedMax) {
      try {
        final nextPage = currentState.currentPage + 1;
        final response = await _repository.fetchSessions(
          statusFilter,
          nextPage,
          search: currentState.searchQuery,
        );

        emit(
          currentState.copyWith(
            sessions: List.of(currentState.sessions)..addAll(response.data),
            hasReachedMax: response.meta.currentPage >= response.meta.lastPage,
            currentPage: nextPage,
          ),
        );
      } catch (e) {
        // Biarkan state yang ada jika loading next page gagal (Supaya list tidak hilang)
        // print("Gagal fetch page: $e");
      }
    }
  }
}
