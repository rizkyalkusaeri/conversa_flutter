import 'package:equatable/equatable.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';
import 'package:fifgroup_android_ticketing/data/models/user_model.dart';

abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchLoaded extends SearchState {
  final List<SessionModel> sessions;
  final List<UserModel> users;
  final bool hasReachedMax;
  final bool usersHasReachedMax;
  final int currentPage;
  final int usersCurrentPage;
  final String searchQuery;
  final String statusFilter;
  final int? selectedUserId;
  final String? selectedUserName;
  final String? scope;

  const SearchLoaded({
    required this.sessions,
    this.users = const [],
    required this.hasReachedMax,
    this.usersHasReachedMax = false,
    this.currentPage = 1,
    this.usersCurrentPage = 1,
    this.searchQuery = '',
    this.statusFilter = 'all',
    this.selectedUserId,
    this.selectedUserName,
    this.scope,
  });

  SearchLoaded copyWith({
    List<SessionModel>? sessions,
    List<UserModel>? users,
    bool? hasReachedMax,
    bool? usersHasReachedMax,
    int? currentPage,
    int? usersCurrentPage,
    String? searchQuery,
    String? statusFilter,
    int? selectedUserId,
    String? selectedUserName,
    String? scope,
    bool clearUserFilter = false,
  }) {
    return SearchLoaded(
      sessions: sessions ?? this.sessions,
      users: users ?? this.users,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      usersHasReachedMax: usersHasReachedMax ?? this.usersHasReachedMax,
      currentPage: currentPage ?? this.currentPage,
      usersCurrentPage: usersCurrentPage ?? this.usersCurrentPage,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      selectedUserId: clearUserFilter ? null : (selectedUserId ?? this.selectedUserId),
      selectedUserName: clearUserFilter ? null : (selectedUserName ?? this.selectedUserName),
      scope: clearUserFilter ? null : (scope ?? this.scope),
    );
  }

  @override
  List<Object?> get props => [
        sessions,
        users,
        hasReachedMax,
        usersHasReachedMax,
        currentPage,
        usersCurrentPage,
        searchQuery,
        statusFilter,
        selectedUserId,
        selectedUserName,
        scope,
      ];
}

class SearchError extends SearchState {
  final String message;

  const SearchError(this.message);

  @override
  List<Object?> get props => [message];
}
