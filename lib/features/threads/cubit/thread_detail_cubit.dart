import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:fifgroup_android_ticketing/data/models/thread_model.dart';
import 'package:fifgroup_android_ticketing/data/repositories/thread_repository.dart';
import 'package:fifgroup_android_ticketing/data/models/comment_model.dart';
import 'package:fifgroup_android_ticketing/core/utils/file_validator.dart';
import 'thread_detail_state.dart';

class ThreadDetailCubit extends Cubit<ThreadDetailState> {
  final ThreadRepository _repository;

  ThreadDetailCubit({ThreadRepository? repository})
    : _repository = repository ?? ThreadRepository(),
      super(ThreadDetailInitial());

  /// Load thread detail (without comments). Comments are loaded separately.
  Future<void> loadThread(String uuid) async {
    emit(ThreadDetailLoading());
    try {
      final thread = await _repository.fetchThreadDetail(uuid);
      emit(ThreadDetailLoaded(thread: thread));
      // Immediately load first page of comments
      await loadComments(uuid, refresh: true);
    } catch (e) {
      emit(ThreadDetailError(_friendlyError(e)));
    }
  }

  /// Load (or load-more) paginated comments for a thread.
  /// [refresh] = true resets the list and starts from page 1.
  Future<void> loadComments(String threadUuid, {bool refresh = false}) async {
    final currentState = state;
    if (currentState is! ThreadDetailLoaded) return;

    // Prevent duplicate loads
    if (!refresh && currentState.isLoadingMoreComments) return;
    if (!refresh && !currentState.hasMoreComments) return;

    final nextPage = refresh ? 1 : currentState.currentPage + 1;

    emit(currentState.copyWith(isLoadingMoreComments: true));

    try {
      final response = await _repository.fetchComments(
        threadUuid,
        page: nextPage,
      );

      final newComments = refresh
          ? response.data
          : [...currentState.comments, ...response.data];

      final hasMore = response.meta.currentPage < response.meta.lastPage;

      emit(
        currentState.copyWith(
          comments: newComments,
          currentPage: response.meta.currentPage,
          hasMoreComments: hasMore,
          isLoadingMoreComments: false,
        ),
      );
    } catch (e) {
      // Restore the state without loading indicator on error
      emit(currentState.copyWith(isLoadingMoreComments: false));
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
    if (currentState is ThreadDetailLoaded) {
      final updatedComments = _toggleCommentLike(
        currentState.comments,
        commentId,
      );
      emit(currentState.copyWith(comments: updatedComments));

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
    List<File>? attachments,
  }) async {
    final currentState = state;
    if (currentState is ThreadDetailLoaded) {
      emit(
        ThreadDetailCommentPosting(
          thread: currentState.thread,
          comments: currentState.comments,
        ),
      );

      try {
        // Bangun FormData secara eksplisit agar key 'attachments[]'
        // terdaftar dengan benar oleh Dio (fromMap kurang reliable untuk List<MultipartFile>)
        final formData = FormData();
        formData.fields.add(MapEntry('content', content));
        if (parentId != null) {
          formData.fields.add(MapEntry('parent_id', parentId.toString()));
        }

        if (attachments != null && attachments.isNotEmpty) {
          for (final file in attachments) {
            await FileValidator.validateSize(file.path);
            formData.files.add(
              MapEntry(
                'attachments[]',
                await MultipartFile.fromFile(
                  file.path,
                  filename: file.path.split(Platform.pathSeparator).last,
                ),
              ),
            );
          }
        }

        await _repository.postComment(threadUuid, formData);

        // Refresh comments from page 1 to get the new comment
        final thread = await _repository.fetchThreadDetail(threadUuid);

        // Emit loaded state first, then reload comments
        emit(ThreadDetailLoaded(thread: thread));
        await loadComments(threadUuid, refresh: true);
      } catch (e) {
        // Report error to UI
        emit(
          ThreadDetailCommentError(
            thread: currentState.thread,
            comments: currentState.comments,
            errorMessage: _friendlyError(e),
          ),
        );
      }
    }
  }

  void restoreLoadedState(ThreadModel thread, List<CommentModel> comments) {
    emit(ThreadDetailLoaded(thread: thread, comments: comments));
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
