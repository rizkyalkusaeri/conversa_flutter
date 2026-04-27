import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Meminta izin notifikasi (Android 13+)
    await Permission.notification.request();

    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('ic_notification');

    const DarwinInitializationSettings iosInitializationSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped with payload: ${response.payload}');
        // Redirect or handle notification tap here if needed in the future
      },
    );

    // WAJIB untuk Android 8+: Buat notification channel secara eksplisit.
    // FCM (background & terminated) akan mengirim notifikasi ke channel ini.
    // Channel ID HARUS sama persis dengan:
    //   1. AndroidManifest.xml → default_notification_channel_id
    //   2. showNotification() → AndroidNotificationDetails channelId
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'fifgroup_chat_channel',
      'FIFGROUP Messages',
      description: 'Notifications for incoming messages and session updates.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    debugPrint('NotificationService: channel "fifgroup_chat_channel" registered');

    // Channel khusus untuk notifikasi thread baru.
    // Dipisah dari chat agar user Android bisa atur preferensi notif secara
    // independen antara pesan chat dan thread forum.
    const AndroidNotificationChannel threadChannel = AndroidNotificationChannel(
      'fifgroup_thread_channel',
      'FIFGROUP Threads',
      description: 'Notifikasi untuk thread baru di forum diskusi.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await androidPlugin?.createNotificationChannel(threadChannel);
    debugPrint('NotificationService: channel "fifgroup_thread_channel" registered');
  }

  /// Tampilkan local notification.
  ///
  /// [channelId] menentukan notification channel Android yang digunakan.
  /// Default: 'fifgroup_chat_channel' agar backward compatible dengan
  /// semua pemanggil yang sudah ada.
  /// Gunakan 'fifgroup_thread_channel' untuk notifikasi thread baru.
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'fifgroup_chat_channel',
  }) async {
    final channelName = channelId == 'fifgroup_thread_channel'
        ? 'FIFGROUP Threads'
        : 'FIFGROUP Messages';
    final channelDesc = channelId == 'fifgroup_thread_channel'
        ? 'Notifikasi untuk thread baru di forum diskusi.'
        : 'Notifications for incoming messages and session updates.';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      icon: 'ic_notification',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final id = Random().nextInt(100000);

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }
}
