import 'package:dio/dio.dart';
import '../../core/storage/storage_manager.dart';
import 'api_config.dart';

class DioClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    receiveTimeout: const Duration(seconds: 15),
    connectTimeout: const Duration(seconds: 15),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ));

  static Dio get getInstance {
    _dio.interceptors.clear(); // Bersihkan interceptor sblm pasang baru agar tidak dobel
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Selalu coba sisipkan Token sebelum berangkat request
          final token = await StorageManager.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // Bisa tambah modifikasi response general
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          // Tangkap Unauthorized
          if (e.response?.statusCode == 401) {
            // Kita hapus token lalu trigger event utk logout 
            // Namun idealnya event akan dipanggil oleh cubit setelah lemparan
            await StorageManager.clearAuth();
          }
          return handler.next(e);
        },
      ),
    );
    return _dio;
  }
}
