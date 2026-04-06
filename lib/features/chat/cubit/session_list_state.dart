import 'package:equatable/equatable.dart';
import '../models/session_model.dart';

abstract class SessionListState extends Equatable {
  const SessionListState();

  @override
  List<Object?> get props => [];
}

class SessionListInitial extends SessionListState {}

class SessionListLoading extends SessionListState {}

class SessionListLoaded extends SessionListState {
  final List<SessionModel> sessions;
  final bool hasReachedMax;
  final int currentPage;

  const SessionListLoaded({
    required this.sessions,
    required this.hasReachedMax,
    this.currentPage = 1,
  });

  SessionListLoaded copyWith({
    List<SessionModel>? sessions,
    bool? hasReachedMax,
    int? currentPage,
  }) {
    return SessionListLoaded(
      sessions: sessions ?? this.sessions,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  @override
  List<Object?> get props => [sessions, hasReachedMax, currentPage];
}

class SessionListError extends SessionListState {
  final String message;

  const SessionListError(this.message);

  @override
  List<Object?> get props => [message];
}
