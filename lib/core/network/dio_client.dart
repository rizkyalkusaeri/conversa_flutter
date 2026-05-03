import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/storage/storage_manager.dart';
import '../../core/services/navigation_service.dart';
import '../../features/auth/ui/login_page.dart';
import '../../features/auth/cubit/app_auth/app_auth_cubit.dart';
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

        onResponse: (response, handler) async {
          // Layer 10 — Sliding Token Expiration:
          // Jika server mengirim token baru via header X-New-Token, simpan secara silent
          final newToken = response.headers.value('x-new-token');
          if (newToken != null) {
            final userJson = await StorageManager.getUser();
            if (userJson != null) {
              await StorageManager.saveAuth(newToken, userJson);
            }
          }
          return handler.next(response);
        },

        onError: (DioException e, handler) async {
          // Tangkap Unauthorized (401) — token expired atau tidak valid
          if (e.response?.statusCode == 401) {
            // Dapatkan context dari navigator global untuk akses Cubit
            final context = NavigationService.navigatorKey.currentContext;
            
            if (context != null) {
              // Panggil forceLogout untuk membersihkan token, mutus Echo & FCM, lalu ubah state
              context.read<AppAuthCubit>().forceLogout();
              
              // Pop out of any nested routes (like ChatPage) back to root (MainPage/LoginPage)
              NavigationService.navigatorKey.currentState?.popUntil((route) => route.isFirst);
            } else {
              // Fallback jika context belum ada
              await StorageManager.clearAuth();
              NavigationService.navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => LoginPage()),
                (route) => false,
              );
            }
          }
          return handler.next(e);
        },
      ),
    );
    return _dio;
  }
}
