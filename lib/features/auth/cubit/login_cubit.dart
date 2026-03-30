import 'package:bloc/bloc.dart';
import '../repository/auth_repository.dart';
import 'app_auth/app_auth_cubit.dart';

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final AuthRepository _authRepository;
  final AppAuthCubit _appAuthCubit;

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
    // 1. Set Loading & Reset Error
    emit(
      state.copyWith(isLoading: true, errorMessage: null, successMessage: null),
    );

    try {
      final user = await _authRepository.login(username, password);
      // 2. Jika Sukses, instruksikan Global state App untuk ganti root ke dashboard
      _appAuthCubit.loggedIn(user);
      emit(state.copyWith(isLoading: false, successMessage: "Login Berhasil!"));
    } catch (e) {
      // 3. Jika Gagal, kembalikan ke format exception parsing api
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }
}
