import 'package:equatable/equatable.dart';
import 'package:fifgroup_android_ticketing/data/models/thread_model.dart';
import 'package:fifgroup_android_ticketing/data/models/comment_model.dart';

abstract class ThreadDetailState extends Equatable {
  const ThreadDetailState();

  @override
  List<Object?> get props => [];
}

class ThreadDetailInitial extends ThreadDetailState {}

class ThreadDetailLoading extends ThreadDetailState {}

class ThreadDetailLoaded extends ThreadDetailState {
  final ThreadModel thread;
  final List<CommentModel> comments;
  final int currentPage;
  final bool hasMoreComments;
  final bool isLoadingMoreComments;

  const ThreadDetailLoaded({
    required this.thread,
    this.comments = const [],
    this.currentPage = 1,
    this.hasMoreComments = true,
    this.isLoadingMoreComments = false,
  });

  ThreadDetailLoaded copyWith({
    ThreadModel? thread,
    List<CommentModel>? comments,
    int? currentPage,
    bool? hasMoreComments,
    bool? isLoadingMoreComments,
  }) {
    return ThreadDetailLoaded(
      thread: thread ?? this.thread,
      comments: comments ?? this.comments,
      currentPage: currentPage ?? this.currentPage,
      hasMoreComments: hasMoreComments ?? this.hasMoreComments,
      isLoadingMoreComments: isLoadingMoreComments ?? this.isLoadingMoreComments,
    );
  }

  @override
  List<Object?> get props => [thread, comments, currentPage, hasMoreComments, isLoadingMoreComments];
}

class ThreadDetailError extends ThreadDetailState {
  final String message;

  const ThreadDetailError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Transient state for comment posting
class ThreadDetailCommentPosting extends ThreadDetailState {
  final ThreadModel thread;
  final List<CommentModel> comments;

  const ThreadDetailCommentPosting({required this.thread, required this.comments});

  @override
  List<Object?> get props => [thread, comments];
}
