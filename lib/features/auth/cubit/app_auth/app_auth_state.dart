import 'package:equatable/equatable.dart';
import '../../models/user_model.dart';

abstract class AppAuthState extends Equatable {
  const AppAuthState();

  @override
  List<Object> get props => [];
}

class AppAuthInitial extends AppAuthState {}

class AppAuthAuthenticated extends AppAuthState {
  final UserModel user;

  const AppAuthAuthenticated(this.user);

  @override
  List<Object> get props => [user];
}

class AppAuthUnauthenticated extends AppAuthState {}
