import 'package:shared_preferences/shared_preferences.dart';

class StorageManager {
  static const String _keyToken = 'access_token';
  static const String _keyUser = 'user_data';

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
  }
}
