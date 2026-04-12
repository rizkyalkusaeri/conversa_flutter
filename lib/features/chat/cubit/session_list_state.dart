import 'package:equatable/equatable.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';

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
  final String searchQuery;

  const SessionListLoaded({
    required this.sessions,
    required this.hasReachedMax,
    this.currentPage = 1,
    this.searchQuery = '',
  });

  SessionListLoaded copyWith({
    List<SessionModel>? sessions,
    bool? hasReachedMax,
    int? currentPage,
    String? searchQuery,
  }) {
    return SessionListLoaded(
      sessions: sessions ?? this.sessions,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      currentPage: currentPage ?? this.currentPage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [sessions, hasReachedMax, currentPage, searchQuery];
}

class SessionListError extends SessionListState {
  final String message;

  const SessionListError(this.message);

  @override
  List<Object?> get props => [message];
}
