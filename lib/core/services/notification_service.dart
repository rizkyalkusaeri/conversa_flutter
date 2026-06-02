import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'badge_service.dart';

// ---------------------------------------------------------------------------
// Deterministic Notification IDs
// ---------------------------------------------------------------------------
// Setiap tipe notifikasi punya ID tetap agar bisa di-cancel secara spesifik.
// Keuntungan tambahan: notifikasi sejenis akan REPLACE (bukan tumpuk) di tray.
// ---------------------------------------------------------------------------
class NotificationId {
  NotificationId._();

  /// Notifikasi thread baru dari forum diskusi.
  static const int thread = 1001;

  /// Notifikasi sesi baru (SessionCreated).
  static const int sessionCreated = 1002;

  /// Notifikasi perubahan status sesi (SessionUpdated).
  static const int sessionUpdated = 1003;

  /// Notifikasi pesan baru dari sesi lain (MessageSent).
  static const int newMessage = 1004;

  /// Notifikasi global dari Filament / BroadcastNotificationCreated.
  static const int globalNotification = 1005;
}

// ---------------------------------------------------------------------------
// Active App Page — digunakan oleh cancelByContext()
// ---------------------------------------------------------------------------
enum ActiveAppPage { chat, search, threads, profile }

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

  /// Tampilkan local notification dengan ID deterministik.
  ///
  /// [notificationId] — gunakan konstanta dari [NotificationId] agar notifikasi
  /// bisa di-cancel secara spesifik via [cancelById] / [cancelByContext].
  /// Jika tidak diberikan, akan di-fallback ke ID default berdasarkan [channelId].
  ///
  /// [channelId] menentukan notification channel Android yang digunakan.
  /// Default: 'fifgroup_chat_channel'.
  /// Gunakan 'fifgroup_thread_channel' untuk notifikasi thread baru.
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'fifgroup_chat_channel',
    int? notificationId,
  }) async {
    final channelName = channelId == 'fifgroup_thread_channel'
        ? 'FIFGROUP Threads'
        : 'FIFGROUP Messages';
    final channelDesc = channelId == 'fifgroup_thread_channel'
        ? 'Notifikasi untuk thread baru di forum diskusi.'
        : 'Notifications for incoming messages and session updates.';

    // Fallback ID deterministik berdasarkan channel jika tidak disuplai.
    final id = notificationId ??
        (channelId == 'fifgroup_thread_channel'
            ? NotificationId.thread
            : NotificationId.newMessage);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      icon: 'ic_notification',
      number: BadgeService.currentBadgeCount,
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

  // ---------------------------------------------------------------------------
  // Cancel Helpers
  // ---------------------------------------------------------------------------

  /// Cancel notifikasi berdasarkan ID spesifik.
  static Future<void> cancelById(int id) async {
    try {
      await _notificationsPlugin.cancel(id: id);
      debugPrint('NotificationService: cancelled notification id=$id');
    } catch (e) {
      debugPrint('NotificationService: error cancelling id=$id — $e');
    }
  }

  /// Bersihkan SEMUA notifikasi dari tray sekaligus.
  ///
  /// Dipanggil saat app pertama dibuka atau kembali ke foreground (resume),
  /// sehingga notification tray selalu bersih ketika user aktif menggunakan app.
  static Future<void> clearAll() async {
    try {
      await _notificationsPlugin.cancelAll();
      debugPrint('NotificationService: all notifications cleared');
    } catch (e) {
      debugPrint('NotificationService: error clearing all notifications — $e');
    }
  }

  /// Cancel semua notifikasi yang relevan dengan halaman yang sedang aktif.
  ///
  /// Dipanggil saat user berpindah tab di [MainPage] atau saat halaman
  /// tertentu menjadi visible, sehingga notifikasi kontekstual otomatis
  /// dibersihkan dari tray tanpa menyentuh notifikasi halaman lain.
  ///
  /// Mapping konteks → ID notifikasi yang di-cancel:
  /// - [ActiveAppPage.threads] → [NotificationId.thread]
  /// - [ActiveAppPage.chat]    → [NotificationId.sessionCreated],
  ///                             [NotificationId.sessionUpdated],
  ///                             [NotificationId.newMessage]
  /// - [ActiveAppPage.profile] / [ActiveAppPage.search] → tidak ada notifikasi spesifik
  static Future<void> cancelByContext(ActiveAppPage page) async {
    switch (page) {
      case ActiveAppPage.threads:
        await cancelById(NotificationId.thread);
        break;

      case ActiveAppPage.chat:
        await cancelById(NotificationId.sessionCreated);
        await cancelById(NotificationId.sessionUpdated);
        await cancelById(NotificationId.newMessage);
        break;

      case ActiveAppPage.search:
      case ActiveAppPage.profile:
        // Tidak ada notifikasi spesifik untuk halaman ini.
        break;
    }
  }
}
