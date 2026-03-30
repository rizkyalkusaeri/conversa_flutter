part of 'login_cubit.dart';

class LoginState {
  final bool isLoading;
  final bool isPasswordVisible;
  final String? errorMessage;
  final String?
  successMessage; // Ganti isSuccess jadi message agar lebih fleksibel

  LoginState({
    this.isLoading = false,
    this.isPasswordVisible = true,
    this.errorMessage,
    this.successMessage,
  });

  LoginState copyWith({
    bool? isLoading,
    bool? isPasswordVisible,
    String? errorMessage,
    String? successMessage,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}
