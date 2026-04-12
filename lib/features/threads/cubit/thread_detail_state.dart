import 'package:equatable/equatable.dart';
import 'package:fifgroup_android_ticketing/data/models/thread_model.dart';

abstract class ThreadDetailState extends Equatable {
  const ThreadDetailState();

  @override
  List<Object?> get props => [];
}

class ThreadDetailInitial extends ThreadDetailState {}

class ThreadDetailLoading extends ThreadDetailState {}

class ThreadDetailLoaded extends ThreadDetailState {
  final ThreadModel thread;

  const ThreadDetailLoaded({required this.thread});

  ThreadDetailLoaded copyWith({ThreadModel? thread}) {
    return ThreadDetailLoaded(thread: thread ?? this.thread);
  }

  @override
  List<Object?> get props => [thread];
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

  const ThreadDetailCommentPosting({required this.thread});

  @override
  List<Object?> get props => [thread];
}
