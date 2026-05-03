import 'package:bloc/bloc.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app_auth_state.dart';
import 'package:fifgroup_android_ticketing/data/models/user_model.dart';
import 'package:fifgroup_android_ticketing/data/repositories/auth_repository.dart';
import '../../../../core/storage/storage_manager.dart';
import '../../../../core/network/echo_service.dart';

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
    // Normal logout (koneksi masih valid)
    await _authRepository.logout();
    
    // Putuskan koneksi socket / Echo
    try {
      await EchoService.disconnect();
    } catch (_) {}
    
    // Hapus FCM token lokal agar unsubscribe dan stop listen
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}

    emit(AppAuthUnauthenticated());
  }

  // Dipanggil oleh DioClient saat mendapat 401 Unauthorized
  Future<void> forceLogout() async {
    // 1. Bersihkan storage lokal
    await StorageManager.clearAuth();
    
    // 2. Putuskan koneksi socket / Echo
    try {
      await EchoService.disconnect();
    } catch (_) {}
    
    // 3. Hapus FCM token lokal agar unsubscribe dan stop listen
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}

    // 4. Emit SessionExpired agar root widget menampilkan dialog "Sesi Habis"
    //    sebelum redirect ke LoginPage
    emit(AppAuthSessionExpired());
  }

  /// Dipanggil tombol "Login Kembali" di dialog sesi habis
  /// agar BlocConsumer rebuild ke LoginPage.
  void goToLogin() {
    emit(AppAuthUnauthenticated());
  }
}

