import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import '../network/api_config.dart';
import '../storage/storage_manager.dart';
import '../network/echo_service.dart';

/// Background message handler — WAJIB top-level function (bukan method)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(
    'FCM [Background]: ${message.notification?.title} / ${message.data}',
  );
  // flutter_local_notifications tidak bisa dipanggil di background isolate
  // FCM akan otomatis tampilkan system notification dari data.notification
}

class FcmService {
  FcmService._();

  static FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  /// Inisialisasi FCM: minta permission, setup handler, upload token
  static Future<void> init() async {
    // 1. Minta permission notifikasi
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    // CATATAN: onBackgroundMessage WAJIB didaftarkan di main() sebelum runApp()
    // Jangan daftarkan di sini untuk menghindari konflik isolate

    // 2. Handle pesan saat app FOREGROUND
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 3. Handle tap notifikasi saat app BACKGROUND (buka dari background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 4. Handle tap notifikasi saat app TERMINATED (dilaunch dari notifikasi)
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM [Terminated tap]: ${initialMessage.data}');
      _handleNotificationTap(initialMessage);
    }

    // 5. Upload token ke server
    final token = await _fcm.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');
      await uploadTokenToServer(token);
    }

    // 6. Subscribe ke token refresh
    _fcm.onTokenRefresh.listen(uploadTokenToServer);
  }

  /// Upload FCM token ke server Laravel
  static Future<void> uploadTokenToServer(String token) async {
    try {
      final authToken = await StorageManager.getToken();
      if (authToken == null) return;

      final dio = Dio();
      await dio.post(
        '${ApiConfig.baseUrl}/fcm-token',
        data: {'token': token},
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Accept': 'application/json',
          },
        ),
      );
      debugPrint('FCM: Token berhasil diupload ke server');
    } catch (e) {
      debugPrint('FCM: Gagal upload token: $e');
    }
  }

  /// Hapus FCM token dari server (saat logout)
  static Future<void> deleteTokenFromServer() async {
    try {
      final authToken = await StorageManager.getToken();
      if (authToken == null) return;

      final dio = Dio();
      await dio.delete(
        '${ApiConfig.baseUrl}/fcm-token',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Accept': 'application/json',
          },
        ),
      );
      debugPrint('FCM: Token dihapus dari server');
    } catch (e) {
      debugPrint('FCM: Gagal hapus token: $e');
    }
  }

  /// Handle pesan FCM saat app FOREGROUND
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('FCM [Foreground]: ${message.notification?.title}');

    // Gunakan isSubscribed (bukan isConnected) sebagai guard:
    // isConnected = WebSocket terhubung ke server, tapi channel bisa gagal auth (404)
    // isSubscribed = sudah ada event berhasil diterima → Echo benar-benar aktif
    // Jika Echo fully subscribed, MainPage sudah menampilkan notifikasi via event listeners.
    // Skip FCM agar tidak terjadi notifikasi ganda (Echo + FCM = 2x popup).
    if (EchoService.isSubscribed) {
      debugPrint(
        'FCM [Foreground]: Echo aktif+subscribed, skip FCM popup untuk hindari duplikasi.',
      );
      return;
    }

    final notification = message.notification;
    if (notification != null) {
      // Echo tidak subscribed → tampilkan notifikasi dari FCM sebagai fallback
      await NotificationService.showNotification(
        title: notification.title ?? 'Notifikasi',
        body: notification.body ?? '',
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Handle tap pada notifikasi FCM (deep link ke session)
  static void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final sessionUuid = data['session_uuid'] as String?;
    debugPrint('FCM [Notification Tap]: session_uuid=$sessionUuid');
    // navigasi ke ChatDetailPage setelah navigator siap
    // Ini akan dikaitkan dengan NavigationService di fase selanjutnya
  }
}
