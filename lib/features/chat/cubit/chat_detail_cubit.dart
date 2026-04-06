import 'package:image_picker/image_picker.dart';
import 'package:bloc/bloc.dart';
import '../models/session_model.dart';
import '../repository/chat_repository.dart';
import 'chat_detail_state.dart';

class ChatDetailCubit extends Cubit<ChatDetailState> {
  final ChatRepository _repository;
  final SessionModel initialSession;
  int _currentPage = 1;

  ChatDetailCubit({
    required this.initialSession,
    ChatRepository? repository,
  })  : _repository = repository ?? ChatRepository(),
        super(ChatDetailInitial());

  Future<void> loadInitialChats() async {
    emit(const ChatDetailLoading(isFirstLoad: true));
    try {
      _currentPage = 1;
      final response = await _repository.getChats(initialSession.id, _currentPage);
      emit(ChatDetailLoaded(
        session: initialSession,
        chats: response.data,
        hasReachedMax: response.meta.currentPage == response.meta.lastPage || response.data.isEmpty,
      ));
    } catch (e) {
      emit(ChatDetailError(e.toString()));
    }
  }

  Future<void> loadMoreChats() async {
    if (state is ChatDetailLoaded) {
      final currentState = state as ChatDetailLoaded;
      if (currentState.hasReachedMax) return;

      try {
        _currentPage++;
        final response = await _repository.getChats(initialSession.id, _currentPage);
        
        final hasReachedMax = response.meta.currentPage == response.meta.lastPage || response.data.isEmpty;
        
        emit(currentState.copyWith(
          chats: List.of(currentState.chats)..addAll(response.data),
          hasReachedMax: hasReachedMax,
        ));
      } catch (e) {
        // Rollback current page if failed
        _currentPage--;
        emit(ChatDetailError(e.toString()));
      }
    }
  }

  Future<void> sendMessage(String text, XFile? attachment) async {
    if (state is ChatDetailLoaded) {
      final currentState = state as ChatDetailLoaded;
      
      emit(currentState.copyWith(isSubmitting: true, submitError: null));

      try {
        final newMessage = await _repository.sendChat(initialSession.id, text, attachment);
        
        // Sisipkan pesan baru ke paling atas daftar (index 0 karena riwayat reverse scroll)
        final updatedChats = List.of(currentState.chats)..insert(0, newMessage);
        
        emit(currentState.copyWith(
          isSubmitting: false,
          chats: updatedChats,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          isSubmitting: false,
          submitError: e.toString().replaceFirst('Exception: ', ''),
        ));
      }
    }
  }
}
