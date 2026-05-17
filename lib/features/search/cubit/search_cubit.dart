import 'package:dio/dio.dart';
import 'package:bloc/bloc.dart';
import 'package:fifgroup_android_ticketing/data/repositories/session_repository.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  final SessionRepository _repository;

  SearchCubit({SessionRepository? repository})
      : _repository = repository ?? SessionRepository(),
        super(SearchInitial());

  Future<void> loadInitial({String searchQuery = '', String statusFilter = 'all'}) async {
    emit(SearchLoading());
    try {
      final response = await _repository.fetchGlobalSessions(
        1,
        status: statusFilter,
        search: searchQuery,
      );
      emit(SearchLoaded(
        sessions: response.data,
        hasReachedMax: response.meta.currentPage >= response.meta.lastPage,
        currentPage: 1,
        searchQuery: searchQuery,
        statusFilter: statusFilter,
      ));
    } catch (e) {
      emit(SearchError(_friendlyError(e)));
    }
  }

  Future<void> loadMore() async {
    final currentState = state;
    if (currentState is SearchLoaded && !currentState.hasReachedMax) {
      try {
        final nextPage = currentState.currentPage + 1;
        final response = await _repository.fetchGlobalSessions(
          nextPage,
          status: currentState.statusFilter,
          search: currentState.searchQuery,
        );

        emit(currentState.copyWith(
          sessions: List.of(currentState.sessions)..addAll(response.data),
          hasReachedMax: response.meta.currentPage >= response.meta.lastPage,
          currentPage: nextPage,
        ));
      } catch (e) {
        // Keep current state if loading next page fails
      }
    }
  }

  void onSearchChanged(String query) {
    final currentStatus = state is SearchLoaded
        ? (state as SearchLoaded).statusFilter
        : 'all';
    loadInitial(searchQuery: query, statusFilter: currentStatus);
  }

  void onStatusChanged(String status) {
    final currentSearch = state is SearchLoaded
        ? (state as SearchLoaded).searchQuery
        : '';
    loadInitial(searchQuery: currentSearch, statusFilter: status);
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
