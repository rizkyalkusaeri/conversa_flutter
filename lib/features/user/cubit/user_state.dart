part of 'user_cubit.dart';

@immutable
sealed class UserState {}

final class UserInitial extends UserState {}

class UserLoading extends UserState {}

class UserSuccess extends UserState {
  final List<dynamic> users;

  UserSuccess({required this.users});
}

class UserError extends UserState {
  final String message;

  UserError({required this.message});
}
