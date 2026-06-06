import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bloc/bloc.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';
import 'package:fifgroup_android_ticketing/data/models/chat_message_model.dart';
import 'package:fifgroup_android_ticketing/data/repositories/chat_repository.dart';
import 'package:fifgroup_android_ticketing/data/services/session_service.dart';
import 'chat_detail_state.dart';

class ChatDetailCubit extends Cubit<ChatDetailState> {
  final ChatRepository _repository;
  final SessionService _sessionService;
  final SessionModel initialSession;
  late SessionModel currentSession;
  int _currentPage = 1;

  ChatDetailCubit({
    required this.initialSession,
    ChatRepository? repository,
    SessionService? sessionService,
  })  : _repository = repository ?? ChatRepository(),
        _sessionService = sessionService ?? SessionService(),
        currentSession = initialSession,
        super(ChatDetailInitial());

  Future<void> loadInitialChats({String searchQuery = ''}) async {
    emit(const ChatDetailLoading(isFirstLoad: true));
    try {
      _currentPage = 1;
      final response = await _repository.getChats(initialSession.id, _currentPage, search: searchQuery);
      emit(ChatDetailLoaded(
        session: currentSession,
        chats: response.data,
        hasReachedMax: response.meta.currentPage == response.meta.lastPage || response.data.isEmpty,
        searchQuery: searchQuery,
      ));
    } catch (e) {
      emit(ChatDetailError(_friendlyError(e)));
    }
  }

  Future<void> loadMoreChats() async {
    if (state is ChatDetailLoaded) {
      final currentState = state as ChatDetailLoaded;
      if (currentState.hasReachedMax) return;

      try {
        _currentPage++;
        final response = await _repository.getChats(initialSession.id, _currentPage, search: currentState.searchQuery);
        
        final hasReachedMax = response.meta.currentPage == response.meta.lastPage || response.data.isEmpty;
        
        emit(currentState.copyWith(
          chats: List.of(currentState.chats)..addAll(response.data),
          hasReachedMax: hasReachedMax,
        ));
      } catch (e) {
        // Rollback current page if failed
        _currentPage--;
        emit(ChatDetailError(_friendlyError(e)));
      }
    }
  }

  Future<void> sendMessage(String text, XFile? attachment) async {
    if (state is ChatDetailLoaded) {
      final currentState = state as ChatDetailLoaded;

      emit(currentState.copyWith(
        isSubmitting: true,
        isUploadingAttachment: attachment != null,
        submitError: null,
      ));

      try {
        final newMessage = await _repository.sendChat(
            initialSession.id, text, attachment);

        // Sisipkan pesan baru ke paling atas daftar (index 0 karena riwayat reverse scroll)
        final updatedChats = List.of(currentState.chats)..insert(0, newMessage);

        emit(currentState.copyWith(
          isSubmitting: false,
          isUploadingAttachment: false,
          chats: updatedChats,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          isSubmitting: false,
          isUploadingAttachment: false,
          submitError: _friendlyError(e),
          submitErrorTimestamp: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    }
  }

  void receiveMessage(ChatMessageModel newMessage) {
    if (state is ChatDetailLoaded) {
      final currentState = state as ChatDetailLoaded;
      
      // Jika pesan dengan ID ini sudah ada (karena optimistically ditambah via sendMessage), jangan tambah lagi
      if (currentState.chats.any((chat) => chat.id == newMessage.id)) {
        return;
      }
      
      // Karena kita sedang berada di halaman obrolan yang terbuka, anggap pesan otomatis terbaca
      final updatedMessage = ChatMessageModel(
        id: newMessage.id,
        messageContent: newMessage.messageContent,
        messageType: newMessage.messageType,
        systemMessageType: newMessage.systemMessageType,
        attachmentUrl: newMessage.attachmentUrl,
        isRead: true, // Force read locally
        createdAt: newMessage.createdAt,
        senderId: newMessage.senderId,
        senderName: newMessage.senderName,
      );

      final updatedChats = List.of(currentState.chats)..insert(0, updatedMessage);
      emit(currentState.copyWith(chats: updatedChats));

      // Beritahu backend juga bahwa pesan ini telah kita baca
      _repository.markAsRead(initialSession.id);
    }
  }

  void updateSession(SessionModel newSession) {
    currentSession = newSession;
    if (state is ChatDetailLoaded) {
      emit((state as ChatDetailLoaded).copyWith(session: currentSession));
    }
  }

  // Reload session dari API untuk mendapatkan status terbaru secara realtime
  Future<void> reloadSession() async {
    if (state is ChatDetailLoaded) {
      final currentState = state as ChatDetailLoaded;
      try {
        final updatedSession = await _sessionService.getSessionByUuid(initialSession.id);
        currentSession = updatedSession;
        emit(currentState.copyWith(session: currentSession));
      } catch (e) {
        // Jika gagal reload session, tidak perlu crash — biarkan UI tetap tampil
        debugPrint('reloadSession error: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helper: Ubah exception teknis menjadi pesan yang bersih untuk user
  // ---------------------------------------------------------------------------
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
    // Exception biasa — buang prefix "Exception: "
    final raw = e.toString();
    return raw.startsWith('Exception: ') ? raw.replaceFirst('Exception: ', '') : raw;
  }
}
