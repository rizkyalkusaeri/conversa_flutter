import 'package:equatable/equatable.dart';
import 'package:fifgroup_android_ticketing/data/models/user_model.dart';

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

/// Khusus untuk force logout akibat token expired dari server.
/// Berbeda dengan AppAuthUnauthenticated (logout manual) agar
/// UI bisa menampilkan dialog "Sesi habis" kepada user.
class AppAuthSessionExpired extends AppAuthState {}
