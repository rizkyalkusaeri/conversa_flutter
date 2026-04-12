import 'package:equatable/equatable.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';

abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchLoaded extends SearchState {
  final List<SessionModel> sessions;
  final bool hasReachedMax;
  final int currentPage;
  final String searchQuery;
  final String statusFilter;

  const SearchLoaded({
    required this.sessions,
    required this.hasReachedMax,
    this.currentPage = 1,
    this.searchQuery = '',
    this.statusFilter = 'all',
  });

  SearchLoaded copyWith({
    List<SessionModel>? sessions,
    bool? hasReachedMax,
    int? currentPage,
    String? searchQuery,
    String? statusFilter,
  }) {
    return SearchLoaded(
      sessions: sessions ?? this.sessions,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      currentPage: currentPage ?? this.currentPage,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }

  @override
  List<Object?> get props => [sessions, hasReachedMax, currentPage, searchQuery, statusFilter];
}

class SearchError extends SearchState {
  final String message;

  const SearchError(this.message);

  @override
  List<Object?> get props => [message];
}
