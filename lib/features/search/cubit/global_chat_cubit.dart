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
      emit(GlobalChatError(e.toString()));
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
        emit(GlobalChatError(e.toString()));
      }
    }
  }
}
