import 'package:dio/dio.dart';
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
      emit(SessionListError(_friendlyError(e)));
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
