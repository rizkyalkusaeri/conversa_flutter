import 'package:bloc/bloc.dart';
import 'package:fifgroup_android_ticketing/data/repositories/thread_repository.dart';
import 'thread_list_state.dart';

class ThreadListCubit extends Cubit<ThreadListState> {
  final ThreadRepository _repository;
  String? _searchQuery;

  ThreadListCubit({ThreadRepository? repository})
      : _repository = repository ?? ThreadRepository(),
        super(ThreadListInitial());

  /// Load first page of threads (optionally with search)
  Future<void> loadInitial({String? search}) async {
    // Persist the search query so loadMore uses the same filter
    if (search != null) {
      _searchQuery = search.trim().isEmpty ? null : search.trim();
    }
    emit(ThreadListLoading());
    try {
      final response = await _repository.fetchThreads(
        page: 1,
        search: _searchQuery,
      );
      emit(
        ThreadListLoaded(
          threads: response.data,
          hasReachedMax:
              response.meta.currentPage >= response.meta.lastPage,
          currentPage: 1,
        ),
      );
    } catch (e) {
      emit(ThreadListError(
          e.toString().replaceFirst('Exception: ', '')));
    }
  }

  /// Load next page (infinite scroll) — carries the active search query
  Future<void> loadMore() async {
    final currentState = state;
    if (currentState is ThreadListLoaded && !currentState.hasReachedMax) {
      try {
        final nextPage = currentState.currentPage + 1;
        final response = await _repository.fetchThreads(
          page: nextPage,
          search: _searchQuery,
        );

        emit(
          currentState.copyWith(
            threads: List.of(currentState.threads)
              ..addAll(response.data),
            hasReachedMax:
                response.meta.currentPage >= response.meta.lastPage,
            currentPage: nextPage,
          ),
        );
      } catch (_) {
        // Keep the existing list state if next page fails
      }
    }
  }

  /// Trigger a search (resets to page 1)
  Future<void> search(String query) async {
    await loadInitial(search: query);
  }

  /// Clear search and reload
  Future<void> clearSearch() async {
    _searchQuery = null;
    await loadInitial();
  }

  /// Optimistic like toggle — update local state instantly, then call API
  Future<void> toggleLike(String threadUuid) async {
    final currentState = state;
    if (currentState is ThreadListLoaded) {
      // Optimistic update
      final updatedThreads = currentState.threads.map((t) {
        if (t.id == threadUuid) {
          return t.copyWithLikeToggled();
        }
        return t;
      }).toList();

      emit(currentState.copyWith(threads: updatedThreads));

      try {
        await _repository.toggleLikeThread(threadUuid);
      } catch (_) {
        // Revert on failure
        emit(currentState);
      }
    }
  }
}

