import 'package:bloc/bloc.dart';
import 'app_auth_state.dart';
import 'package:fifgroup_android_ticketing/data/models/user_model.dart';
import 'package:fifgroup_android_ticketing/data/repositories/auth_repository.dart';
import '../../../../core/storage/storage_manager.dart';

class AppAuthCubit extends Cubit<AppAuthState> {
  final AuthRepository _authRepository;

  AppAuthCubit({AuthRepository? authRepository}) 
      : _authRepository = authRepository ?? AuthRepository(),
        super(AppAuthInitial());

  // Di panggil saat aplikasi baru buka main()
  Future<void> checkAuthStatus() async {
    final token = await StorageManager.getToken();
    final userJson = await StorageManager.getUser();

    if (token != null && userJson != null) {
      try {
        final userObj = UserModel.fromJsonString(userJson);
        emit(AppAuthAuthenticated(userObj));
      } catch (e) {
        // Fallback kalau parsing user di memory lokal rusak
        emit(AppAuthUnauthenticated());
      }
    } else {
      emit(AppAuthUnauthenticated());
    }
  }

  // Dipanggil CUBIT LOGIN pada form supaya main layar terlempar
  void loggedIn(UserModel userProfile) {
    emit(AppAuthAuthenticated(userProfile));
  }

  // Dipanggil pada Dashboard dan interceptors error
  Future<void> logOut() async {
    await _authRepository.logout();
    emit(AppAuthUnauthenticated());
  }
}
