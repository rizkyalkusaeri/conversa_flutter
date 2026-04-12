import 'package:fifgroup_android_ticketing/features/profile/cubit/change_password/change_password_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fifgroup_android_ticketing/data/repositories/auth_repository.dart';

class ChangePasswordCubit extends Cubit<ChangePasswordState> {
  final AuthRepository _authRepository;

  ChangePasswordCubit({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const ChangePasswordState());

  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    emit(state.copyWith(status: ChangePasswordStatus.loading));

    try {
      await _authRepository.changePassword(
        currentPassword: currentPassword,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      emit(
        state.copyWith(
          status: ChangePasswordStatus.success,
          message: 'Password berhasil diperbarui',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ChangePasswordStatus.error,
          message: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  void toggleCurrentPasswordVisibility() {
    emit(
      state.copyWith(isCurrentPasswordVisible: !state.isCurrentPasswordVisible),
    );
  }

  void toggleNewPasswordVisibility() {
    emit(state.copyWith(isNewPasswordVisible: !state.isNewPasswordVisible));
  }

  void toggleConfirmPasswordVisibility() {
    emit(
      state.copyWith(isConfirmPasswordVisible: !state.isConfirmPasswordVisible),
    );
  }
}
