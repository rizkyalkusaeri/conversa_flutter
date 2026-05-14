class ApiConfig {
  static bool isProduction = false;
  // Gunakan IP lokal host atau 10.0.2.2 untuk emulator android
  static String get baseUrl => isProduction
      ? 'https://fi-link.id/api/v1'
      : 'https://dev.fi-link.id/api/v1';

  static String get imageUrl =>
      isProduction ? 'https://fi-link.id' : 'https://dev.fi-link.id';

  static String get reverbHost =>
      isProduction ? 'fi-link.id' : 'dev.fi-link.id';

  // REVERB_APP_KEY dari .env — sama di semua environment dalam project ini
  static const String reverbKey = 'syhdndftedn1zdw285ub';
}
