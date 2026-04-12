import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:fifgroup_android_ticketing/data/repositories/thread_repository.dart';
import 'package:fifgroup_android_ticketing/data/models/thread_model.dart';
import 'package:fifgroup_android_ticketing/data/models/comment_model.dart';
import 'thread_detail_state.dart';

class ThreadDetailCubit extends Cubit<ThreadDetailState> {
  final ThreadRepository _repository;

  ThreadDetailCubit({ThreadRepository? repository})
    : _repository = repository ?? ThreadRepository(),
      super(ThreadDetailInitial());

  /// Load thread detail with comments
  Future<void> loadThread(String uuid) async {
    emit(ThreadDetailLoading());
    try {
      final thread = await _repository.fetchThreadDetail(uuid);
      emit(ThreadDetailLoaded(thread: thread));
    } catch (e) {
      emit(ThreadDetailError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  /// Toggle like on the thread
  Future<void> toggleLikeThread() async {
    final currentState = state;
    if (currentState is ThreadDetailLoaded) {
      // Optimistic update
      final toggled = currentState.thread.copyWithLikeToggled();
      emit(currentState.copyWith(thread: toggled));

      try {
        await _repository.toggleLikeThread(currentState.thread.id);
      } catch (_) {
        // Revert
        emit(currentState);
      }
    }
  }

  /// Toggle like on a comment (optimistic)
  Future<void> toggleLikeComment(int commentId) async {
    final currentState = state;
    if (currentState is ThreadDetailLoaded &&
        currentState.thread.comments != null) {
      // Deep update comment like status
      final updatedComments = _toggleCommentLike(
        currentState.thread.comments!,
        commentId,
      );

      final updatedThread = ThreadModel(
        id: currentState.thread.id,
        content: currentState.thread.content,
        status: currentState.thread.status,
        createdAt: currentState.thread.createdAt,
        author: currentState.thread.author,
        likesCount: currentState.thread.likesCount,
        commentsCount: currentState.thread.commentsCount,
        isLikedByMe: currentState.thread.isLikedByMe,
        attachments: currentState.thread.attachments,
        comments: updatedComments,
      );

      emit(currentState.copyWith(thread: updatedThread));

      try {
        await _repository.toggleLikeComment(commentId);
      } catch (_) {
        emit(currentState);
      }
    }
  }

  /// Post a new comment
  Future<void> postComment(
    String threadUuid, {
    required String content,
    int? parentId,
  }) async {
    final currentState = state;
    if (currentState is ThreadDetailLoaded) {
      emit(ThreadDetailCommentPosting(thread: currentState.thread));

      try {
        final formData = FormData.fromMap({
          'content': content,
          'parent_id': ?parentId,
        });

        await _repository.postComment(threadUuid, formData);

        // Reload thread to get fresh comments
        await loadThread(threadUuid);
      } catch (e) {
        // Restore loaded state and surface the error via a brief reload
        emit(currentState);
      }
    }
  }

  /// Recursively toggle like on a comment by id
  List<CommentModel> _toggleCommentLike(
    List<CommentModel> comments,
    int targetId,
  ) {
    return comments.map((c) {
      if (c.id == targetId) {
        return c.copyWithLikeToggled();
      }
      if (c.replies.isNotEmpty) {
        return CommentModel(
          id: c.id,
          content: c.content,
          attachments: c.attachments,
          author: c.author,
          likesCount: c.likesCount,
          repliesCount: c.repliesCount,
          isLikedByMe: c.isLikedByMe,
          createdAt: c.createdAt,
          replies: _toggleCommentLike(c.replies, targetId),
        );
      }
      return c;
    }).toList();
  }
}
