import 'package:fifgroup_android_ticketing/data/services/profile_service.dart';
import 'package:fifgroup_android_ticketing/data/models/user_model.dart';
import '../../../core/storage/storage_manager.dart';

class ProfileRepository {
  final ProfileService _service;

  ProfileRepository({ProfileService? service})
      : _service = service ?? ProfileService();

  Future<UserModel> getProfile() async {
    final response = await _service.fetchProfile();

    if (response.success && response.data != null) {
      final updatedUser = response.data!;
      
      // Update persisten lokal token storage dengan data utuh terbaru (termasuk location & level)
      final existingToken = await StorageManager.getToken();
      if (existingToken != null) {
        await StorageManager.saveAuth(existingToken, updatedUser.toJsonString());
      }
      return updatedUser;
    } else {
      throw Exception(response.message.isNotEmpty
          ? response.message
          : 'Gagal memuat profil');
    }
  }
}
