import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'navigation_service.dart';
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

  static bool _listenersRegistered = false;

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

    if (!_listenersRegistered) {
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

      // 6. Subscribe ke token refresh
      _fcm.onTokenRefresh.listen(uploadTokenToServer);
      
      _listenersRegistered = true;
    }

    // 5. Upload token ke server (Selalu dijalankan setiap login untuk memastikan server punya token)
    final token = await _fcm.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');
      await uploadTokenToServer(token);
    }
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

      // Subscribe ke topic global thread setelah token berhasil diupload
      await _subscribeToThreadTopic(authToken);
    } catch (e) {
      debugPrint('FCM: Gagal upload token: $e');
    }
  }

  /// Subscribe FCM token ke topic global thread (fifgroup_all_threads).
  /// Dipanggil otomatis setelah upload token berhasil.
  static Future<void> _subscribeToThreadTopic(String authToken) async {
    try {
      final dio = Dio();
      await dio.post(
        '${ApiConfig.baseUrl}/fcm/subscribe-topic',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Accept': 'application/json',
          },
        ),
      );
      debugPrint('FCM: Subscribed ke topic fifgroup_all_threads');
    } catch (e) {
      debugPrint('FCM: Gagal subscribe topic (akan retry saat login berikutnya): $e');
    }
  }

  /// Hapus FCM token dari server (saat logout).
  /// Juga unsubscribe dari topic global thread sebelum hapus token.
  static Future<void> deleteTokenFromServer() async {
    try {
      final authToken = await StorageManager.getToken();
      if (authToken == null) return;

      final dio = Dio();

      // Unsubscribe dari topic thread terlebih dahulu (butuh token yang masih valid)
      try {
        await dio.post(
          '${ApiConfig.baseUrl}/fcm/unsubscribe-topic',
          options: Options(
            headers: {
              'Authorization': 'Bearer $authToken',
              'Accept': 'application/json',
            },
          ),
        );
        debugPrint('FCM: Unsubscribed dari topic fifgroup_all_threads');
      } catch (e) {
        debugPrint('FCM: Gagal unsubscribe topic: $e');
      }

      // Hapus token dari server
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

    final type = message.data['type'] as String?;

    if (type == 'new_thread') {
      // Untuk notifikasi thread: cek apakah pembuat adalah user yang sedang login
      // Jika ya, skip — pembuat tidak perlu menerima notifikasi threadnya sendiri
      final creatorId = message.data['creator_id'] as String?;
      final userJson = await StorageManager.getUser();
      if (userJson != null && creatorId != null) {
        // Parse user id dari JSON yang tersimpan di local storage
        try {
          final decoded = jsonDecode(userJson) as Map<String, dynamic>;
          final currentUserId = decoded['id']?.toString();
          if (currentUserId == creatorId) {
            debugPrint('FCM [Foreground]: Thread dibuat oleh user sendiri, skip notifikasi.');
            return;
          }
        } catch (_) {}
      }

      // Tampilkan notifikasi thread menggunakan channel thread
      final notification = message.notification;
      if (notification != null) {
        await NotificationService.showNotification(
          title: notification.title ?? '📢 Thread Baru',
          body: notification.body ?? '',
          payload: jsonEncode(message.data),
          channelId: 'fifgroup_thread_channel',
        );
      }
      return;
    }

    // Untuk notifikasi NON-thread (chat, session, dll):
    // Skip jika Echo sudah fully subscribed → hindari notifikasi ganda
    if (EchoService.isSubscribed) {
      debugPrint(
        'FCM [Foreground]: Echo aktif+subscribed, skip FCM popup untuk hindari duplikasi.',
      );
      return;
    }

    final notification = message.notification;
    if (notification != null) {
      await NotificationService.showNotification(
        title: notification.title ?? 'Notifikasi',
        body: notification.body ?? '',
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Handle tap pada notifikasi FCM — routing ke halaman yang sesuai
  /// berdasarkan field 'type' pada data payload.
  static void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;

    debugPrint('FCM [Notification Tap]: type=$type, data=$data');

    if (type == 'new_thread') {
      final threadUuid = data['thread_uuid'] as String?;
      if (threadUuid != null) {
        // Delay kecil untuk memastikan MaterialApp + Navigator sudah fully mounted.
        // Diperlukan terutama saat app dalam state TERMINATED (cold start).
        Future.delayed(const Duration(milliseconds: 500), () {
          NavigationService.navigateToThread(threadUuid);
        });
      }
      return;
    }

    // Chat/session notifications — bisa ditambahkan di sini di masa mendatang
    final sessionUuid = data['session_uuid'] as String?;
    if (sessionUuid != null) {
      debugPrint('FCM [Notification Tap]: session_uuid=$sessionUuid (handler belum diimplementasikan)');
    }
  }
}
