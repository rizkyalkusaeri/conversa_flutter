import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/storage/storage_manager.dart';
import '../../core/services/navigation_service.dart';
import '../../features/auth/ui/login_page.dart';
import '../../features/auth/cubit/app_auth/app_auth_cubit.dart';
import '../../core/network/connectivity_service.dart';
import 'api_config.dart';

class DioClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
    sendTimeout: const Duration(seconds: 120),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ));

  static Dio get getInstance {
    _dio.interceptors.clear(); // Bersihkan interceptor sblm pasang baru agar tidak dobel

    // ── Interceptor 1: Retry (harus dipasang PERTAMA) ──────────────────────────
    // Hanya retry untuk error jaringan (timeout, connection error).
    // TIDAK retry untuk HTTP 4xx/5xx — itu respons valid dari server.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) async {
          final isNetworkError =
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.connectionError;

          // Bukan network error → teruskan ke interceptor berikutnya (auth)
          if (!isNetworkError) {
            return handler.next(e);
          }

          // Offline → tidak ada gunanya retry, langsung throw
          if (!ConnectivityService.instance.isOnline) {
            debugPrint('[DioRetry] Offline, skip retry for: ${e.requestOptions.path}');
            return handler.next(e);
          }

          // Cek apakah masih dalam batas retry
          final retryCount = (e.requestOptions.extra['retryCount'] as int?) ?? 0;
          if (retryCount >= 3) {
            debugPrint('[DioRetry] Max retry reached (3x) for: ${e.requestOptions.path}');
            return handler.next(e);
          }

          // Exponential backoff: 1s → 2s → 4s
          final delaySeconds = pow(2, retryCount).toInt();
          debugPrint(
            '[DioRetry] Retry ${retryCount + 1}/3 for: ${e.requestOptions.path} '
            '(delay: ${delaySeconds}s)',
          );
          await Future.delayed(Duration(seconds: delaySeconds));

          // Clone request options dengan retryCount +1
          final retryOptions = e.requestOptions.copyWith(
            extra: {
              ...e.requestOptions.extra,
              'retryCount': retryCount + 1,
            },
          );

          try {
            final response = await _dio.fetch(retryOptions);
            return handler.resolve(response);
          } on DioException catch (retryError) {
            return handler.next(retryError);
          }
        },
      ),
    );

    // ── Interceptor 2: Auth (token inject, sliding expiry, 401 logout) ─────────
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
          // KECUALI untuk endpoint login (karena 401 di login berarti user/pass salah)
          if (e.response?.statusCode == 401 &&
              !e.requestOptions.path.contains('/auth/login')) {
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
