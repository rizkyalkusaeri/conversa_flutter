import 'package:equatable/equatable.dart';
import 'package:fifgroup_android_ticketing/data/models/thread_model.dart';

abstract class ThreadListState extends Equatable {
  const ThreadListState();

  @override
  List<Object?> get props => [];
}

class ThreadListInitial extends ThreadListState {}

class ThreadListLoading extends ThreadListState {}

class ThreadListLoaded extends ThreadListState {
  final List<ThreadModel> threads;
  final bool hasReachedMax;
  final int currentPage;

  const ThreadListLoaded({
    required this.threads,
    required this.hasReachedMax,
    this.currentPage = 1,
  });

  ThreadListLoaded copyWith({
    List<ThreadModel>? threads,
    bool? hasReachedMax,
    int? currentPage,
  }) {
    return ThreadListLoaded(
      threads: threads ?? this.threads,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  @override
  List<Object?> get props => [threads, hasReachedMax, currentPage];
}

class ThreadListError extends ThreadListState {
  final String message;

  const ThreadListError(this.message);

  @override
  List<Object?> get props => [message];
}
