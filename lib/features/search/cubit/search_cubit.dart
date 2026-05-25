import 'package:dio/dio.dart';
import 'package:bloc/bloc.dart';
import 'package:fifgroup_android_ticketing/data/repositories/session_repository.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';
import 'package:fifgroup_android_ticketing/data/models/user_model.dart';
import 'package:fifgroup_android_ticketing/core/network/pagination_response.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  final SessionRepository _repository;

  SearchCubit({SessionRepository? repository})
      : _repository = repository ?? SessionRepository(),
        super(SearchInitial());

  Future<void> loadInitial({
    String searchQuery = '',
    String statusFilter = 'all',
    int? selectedUserId,
    String? selectedUserName,
    String? scope,
  }) async {
    emit(SearchLoading());
    try {
      final sessionsFuture = _repository.fetchGlobalSessions(
        1,
        status: statusFilter,
        search: searchQuery,
        userId: selectedUserId,
        scope: scope,
      );

      final usersFuture = _repository.fetchGlobalUsers(
        1,
        search: searchQuery,
      );

      final results = await Future.wait([sessionsFuture, usersFuture]);
      final sessionsResponse = results[0] as PaginationResponse<SessionModel>;
      final usersResponse = results[1] as PaginationResponse<UserModel>;

      emit(SearchLoaded(
        sessions: sessionsResponse.data,
        users: usersResponse.data,
        hasReachedMax: sessionsResponse.meta.currentPage >= sessionsResponse.meta.lastPage,
        usersHasReachedMax: usersResponse.meta.currentPage >= usersResponse.meta.lastPage,
        currentPage: 1,
        usersCurrentPage: 1,
        searchQuery: searchQuery,
        statusFilter: statusFilter,
        selectedUserId: selectedUserId,
        selectedUserName: selectedUserName,
        scope: scope,
      ));
    } catch (e) {
      emit(SearchError(_friendlyError(e)));
    }
  }

  Future<void> loadMoreSessions() async {
    final currentState = state;
    if (currentState is SearchLoaded && !currentState.hasReachedMax) {
      try {
        final nextPage = currentState.currentPage + 1;
        final response = await _repository.fetchGlobalSessions(
          nextPage,
          status: currentState.statusFilter,
          search: currentState.searchQuery,
          userId: currentState.selectedUserId,
          scope: currentState.scope,
        );

        emit(currentState.copyWith(
          sessions: List.of(currentState.sessions)..addAll(response.data),
          hasReachedMax: response.meta.currentPage >= response.meta.lastPage,
          currentPage: nextPage,
        ));
      } catch (e) {
        // Keep current state if loading fails
      }
    }
  }

  Future<void> loadMoreUsers() async {
    final currentState = state;
    if (currentState is SearchLoaded && !currentState.usersHasReachedMax) {
      try {
        final nextPage = currentState.usersCurrentPage + 1;
        final response = await _repository.fetchGlobalUsers(
          nextPage,
          search: currentState.searchQuery,
        );

        emit(currentState.copyWith(
          users: List.of(currentState.users)..addAll(response.data),
          usersHasReachedMax: response.meta.currentPage >= response.meta.lastPage,
          usersCurrentPage: nextPage,
        ));
      } catch (e) {
        // Keep current state if loading fails
      }
    }
  }

  void selectUserFilter(UserModel user) {
    final currentState = state;
    if (currentState is SearchLoaded) {
      loadInitial(
        searchQuery: currentState.searchQuery,
        statusFilter: currentState.statusFilter,
        selectedUserId: user.id,
        selectedUserName: user.fullName,
      );
    }
  }

  void selectSubordinatesFilter() {
    final currentState = state;
    if (currentState is SearchLoaded) {
      loadInitial(
        searchQuery: currentState.searchQuery,
        statusFilter: currentState.statusFilter,
        selectedUserId: null,
        selectedUserName: 'Sesi Saya & Bawahan',
        scope: 'self_and_subordinates',
      );
    }
  }

  void clearUserFilter() {
    final currentState = state;
    if (currentState is SearchLoaded) {
      emit(currentState.copyWith(clearUserFilter: true));
      loadInitial(
        searchQuery: currentState.searchQuery,
        statusFilter: currentState.statusFilter,
      );
    }
  }

  void onSearchChanged(String query) {
    if (state is SearchLoaded) {
      final loaded = state as SearchLoaded;
      loadInitial(
        searchQuery: query,
        statusFilter: loaded.statusFilter,
        selectedUserId: loaded.selectedUserId,
        selectedUserName: loaded.selectedUserName,
        scope: loaded.scope,
      );
    } else {
      loadInitial(searchQuery: query);
    }
  }

  void onStatusChanged(String status) {
    if (state is SearchLoaded) {
      final loaded = state as SearchLoaded;
      loadInitial(
        searchQuery: loaded.searchQuery,
        statusFilter: status,
        selectedUserId: loaded.selectedUserId,
        selectedUserName: loaded.selectedUserName,
        scope: loaded.scope,
      );
    }
  }

  static String _friendlyError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
        case DioExceptionType.badResponse:
          final code = e.response?.statusCode;
          if (code == 401) return 'Sesi telah berakhir. Silakan login kembali.';
          if (code == 403) return 'Anda tidak memiliki akses.';
          if (code == 404) return 'Data tidak ditemukan.';
          if (code != null && code >= 500) return 'Server sedang bermasalah. Coba beberapa saat lagi.';
          return 'Terjadi kesalahan dari server.';
        case DioExceptionType.cancel:
          return 'Permintaan dibatalkan.';
        default:
          return 'Terjadi kesalahan jaringan.';
      }
    }
    final raw = e.toString();
    return raw.startsWith('Exception: ') ? raw.replaceFirst('Exception: ', '') : raw;
  }
}
