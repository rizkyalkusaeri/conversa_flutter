import 'package:dio/dio.dart';
import 'package:bloc/bloc.dart';
import 'package:fifgroup_android_ticketing/data/repositories/chat_repository.dart';
import 'global_chat_state.dart';

class GlobalChatCubit extends Cubit<GlobalChatState> {
  final ChatRepository _repository;
  final String sessionUuid;
  int _currentPage = 1;

  GlobalChatCubit({
    required this.sessionUuid,
    ChatRepository? repository,
  })  : _repository = repository ?? ChatRepository(),
        super(GlobalChatInitial());

  Future<void> loadInitialChats({String searchQuery = ''}) async {
    emit(const GlobalChatLoading(isFirstLoad: true));
    try {
      _currentPage = 1;
      final response = await _repository.getGlobalChats(sessionUuid, _currentPage, search: searchQuery);
      emit(GlobalChatLoaded(
        chats: response.data,
        hasReachedMax: response.meta.currentPage == response.meta.lastPage || response.data.isEmpty,
        searchQuery: searchQuery,
      ));
    } catch (e) {
      emit(GlobalChatError(_friendlyError(e)));
    }
  }

  Future<void> loadMoreChats() async {
    if (state is GlobalChatLoaded) {
      final currentState = state as GlobalChatLoaded;
      if (currentState.hasReachedMax) return;

      try {
        _currentPage++;
        final response = await _repository.getGlobalChats(sessionUuid, _currentPage, search: currentState.searchQuery);
        
        final hasReachedMax = response.meta.currentPage == response.meta.lastPage || response.data.isEmpty;
        
        emit(currentState.copyWith(
          chats: List.of(currentState.chats)..addAll(response.data),
          hasReachedMax: hasReachedMax,
        ));
      } catch (e) {
        // Rollback current page if failed
        _currentPage--;
        emit(GlobalChatError(_friendlyError(e)));
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
