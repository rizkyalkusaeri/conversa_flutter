import 'package:shared_preferences/shared_preferences.dart';

class StorageManager {
  static const String _keyToken = 'access_token';
  static const String _keyUser = 'user_data';
  static const String _keyPrivacyAccepted = 'privacy_policy_accepted';

  // Menyimpan Token dan Data User (dalam bentuk JSON String)
  static Future<void> saveAuth(String token, String userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUser, userJson);
  }

  // Mengambil Token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  // Mengambil Data User (JSON String)
  static Future<String?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUser);
  }

  // Menghapus Sesi
  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
    // Kita tidak menghapus _keyPrivacyAccepted di sini agar user tidak perlu accept ulang saat logout
  }

  // Menandai Privacy Policy telah disetujui
  static Future<void> setPrivacyPolicyAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPrivacyAccepted, true);
  }

  // Mengecek apakah Privacy Policy sudah disetujui
  static Future<bool> isPrivacyPolicyAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPrivacyAccepted) ?? false;
  }
}
