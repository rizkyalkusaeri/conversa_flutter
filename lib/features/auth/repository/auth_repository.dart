import '../service/auth_service.dart';
import '../../../core/storage/storage_manager.dart';
import '../models/user_model.dart';
class AuthRepository {
  final AuthService _authService;

  AuthRepository({AuthService? authService}) 
      : _authService = authService ?? AuthService();

  // Kembalikan model UserModel jika berhasil
  Future<UserModel> login(String username, String password) async {
    final response = await _authService.loginRequest(username, password);

    if (response.success && response.data != null) {
      final loginData = response.data!;
      
      // Simpan JWT Token dan Data User sekaligus
      await StorageManager.saveAuth(
        loginData.accessToken,
        loginData.user.toJsonString(),
      );
      
      return loginData.user;
    } else {
      // Melemparkan exception dengan error message dari API
      throw Exception(response.message.isNotEmpty 
          ? response.message 
          : 'Gagal login, periksa username dan password.');
    }
  }

  Future<void> logout() async {
    try {
      // Walau error di panggil authService, tetap hapus sesi
      await _authService.logoutRequest();
    } catch (e) {
      // Log / Abaikan error jika server sudah tidak merespon/sesi expired di atas
    } finally {
      await StorageManager.clearAuth();
    }
  }
}
