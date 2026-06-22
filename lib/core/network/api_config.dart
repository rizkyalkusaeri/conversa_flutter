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
  static String get reverbKey =>
      isProduction ? 'syhdndftedn1zdw285ub' : 'syhdndftedn1zdw999ub';

  static String getDownloadUrl(String path, String? originalName) {
    if (originalName == null || originalName.isEmpty) {
      return imageUrl + path;
    }

    // Extract path segment (remove /storage/ or domain prefix)
    String cleanPath = path;
    if (cleanPath.contains('/storage/')) {
      cleanPath = cleanPath.split('/storage/').last;
    } else if (cleanPath.startsWith('http')) {
      try {
        final uri = Uri.parse(cleanPath);
        if (uri.path.contains('/storage/')) {
          cleanPath = uri.path.split('/storage/').last;
        } else {
          cleanPath = uri.path.startsWith('/')
              ? uri.path.substring(1)
              : uri.path;
        }
      } catch (_) {}
    } else if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    return '$baseUrl/download-attachment?path=${Uri.encodeComponent(cleanPath)}&name=${Uri.encodeComponent(originalName)}';
  }
}
