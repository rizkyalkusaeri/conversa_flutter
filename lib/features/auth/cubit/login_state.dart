part of 'login_cubit.dart';

class LoginState {
  final bool isLoading;
  final bool isPasswordVisible;
  final String? errorMessage;
  final String? successMessage;
  final bool isRateLimited;      // true ketika IP sedang diblokir oleh server (HTTP 429)
  final int retryAfterSeconds;   // sisa detik sebelum bisa coba login lagi

  LoginState({
    this.isLoading = false,
    this.isPasswordVisible = true,
    this.errorMessage,
    this.successMessage,
    this.isRateLimited = false,
    this.retryAfterSeconds = 0,
  });

  LoginState copyWith({
    bool? isLoading,
    bool? isPasswordVisible,
    String? errorMessage,
    String? successMessage,
    bool? isRateLimited,
    int? retryAfterSeconds,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      errorMessage: errorMessage,
      successMessage: successMessage,
      isRateLimited: isRateLimited ?? this.isRateLimited,
      retryAfterSeconds: retryAfterSeconds ?? this.retryAfterSeconds,
    );
  }
}
