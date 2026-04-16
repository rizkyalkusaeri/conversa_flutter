class ApiConfig {
  static bool isProduction = true;
  // Gunakan IP lokal host atau 10.0.2.2 untuk emulator android
  static String get baseUrl => isProduction
      ? 'https://myconversa.cloud/api/v1'
      : 'http://localhost:8000/api/v1';

  static String get imageUrl =>
      isProduction ? 'https://myconversa.cloud' : 'http://localhost:8000';

  static String get reverbHost =>
      isProduction ? 'myconversa.cloud' : 'localhost';

  // REVERB_APP_KEY dari .env — sama di semua environment dalam project ini
  static const String reverbKey = 'syhdndftedn1zdw285ub';
}
