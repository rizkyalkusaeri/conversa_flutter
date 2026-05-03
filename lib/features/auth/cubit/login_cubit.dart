import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:fifgroup_android_ticketing/data/repositories/auth_repository.dart';
import 'app_auth/app_auth_cubit.dart';

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final AuthRepository _authRepository;
  final AppAuthCubit _appAuthCubit;
  Timer? _countdownTimer;

  LoginCubit({
    required AuthRepository authRepository,
    required AppAuthCubit appAuthCubit,
  })  : _authRepository = authRepository,
        _appAuthCubit = appAuthCubit,
        super(LoginState());

  void togglePasswordVisibility() {
    emit(state.copyWith(isPasswordVisible: !state.isPasswordVisible));
  }

  void login(String username, String password) async {
    // Jika sedang dalam masa rate-limit, abaikan klik
    if (state.isRateLimited) return;

    // Set Loading & Reset Error
    emit(
      state.copyWith(isLoading: true, errorMessage: null, successMessage: null),
    );

    try {
      final user = await _authRepository.login(username, password);
      // Jika Sukses, instruksikan Global state App untuk ganti root ke dashboard
      _appAuthCubit.loggedIn(user);
      emit(state.copyWith(isLoading: false, successMessage: 'Login Berhasil!'));
    } on DioException catch (e) {
      // Tangani HTTP 429 — Rate Limit terlampaui
      if (e.response?.statusCode == 429) {
        final dynamic retryAfterRaw = e.response?.data['retry_after'];
        final int retryAfter =
            (retryAfterRaw is int) ? retryAfterRaw : (retryAfterRaw is double ? retryAfterRaw.toInt() : 900);
        final String message = e.response?.data['message'] ?? 'Terlalu banyak percobaan login.';

        emit(state.copyWith(
          isLoading: false,
          isRateLimited: true,
          retryAfterSeconds: retryAfter,
          errorMessage: message,
        ));

        _startCountdown();
        return;
      }

      // DioException lain — koneksifailure, timeout, dll
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Gagal menghubungi server.',
      ));
    } catch (e) {
      // Exception biasa dari repository (401, 500, dsb.)
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  /// Mulai countdown mundur setiap 1 detik.
  /// Saat hitungan mencapai 0, reset isRateLimited agar user bisa coba lagi.
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.retryAfterSeconds - 1;
      if (remaining <= 0) {
        timer.cancel();
        emit(state.copyWith(
          isRateLimited: false,
          retryAfterSeconds: 0,
          errorMessage: null,
        ));
      } else {
        emit(state.copyWith(retryAfterSeconds: remaining));
      }
    });
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    return super.close();
  }
}
