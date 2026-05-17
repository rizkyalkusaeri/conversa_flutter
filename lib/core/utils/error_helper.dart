import 'package:dio/dio.dart';

class ErrorHelper {
  /// Mengubah semua jenis Exception/DioException menjadi pesan ramah pengguna (user-friendly)
  static String getFriendlyError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
        case DioExceptionType.badResponse:
          final response = e.response;
          if (response?.data != null) {
            // Coba ambil pesan spesifik dari payload respons API backend jika ada
            if (response!.data is Map) {
              final data = response.data as Map;
              if (data['message'] != null && data['message'].toString().isNotEmpty) {
                return data['message'].toString();
              }
            }
          }
          final code = response?.statusCode;
          if (code == 401) return 'Sesi telah berakhir. Silakan login kembali.';
          if (code == 403) return 'Anda tidak memiliki akses untuk tindakan ini.';
          if (code == 404) return 'Data atau halaman tidak ditemukan.';
          if (code != null && code >= 500) {
            return 'Server sedang bermasalah. Coba beberapa saat lagi.';
          }
          return 'Terjadi kesalahan dari server.';
        case DioExceptionType.cancel:
          return 'Permintaan dibatalkan.';
        default:
          return 'Terjadi kesalahan jaringan atau koneksi.';
      }
    }
    final raw = e.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.replaceFirst('Exception: ', '').trim();
    }
    if (raw.startsWith('PendingFeedbackException: ')) {
      return raw.replaceFirst('PendingFeedbackException: ', '').trim();
    }
    return raw.trim();
  }
}
