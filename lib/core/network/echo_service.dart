import 'dart:convert';
import 'package:laravel_echo/laravel_echo.dart';
import 'package:pusher_client_fixed/pusher_client_fixed.dart';
import 'package:flutter/foundation.dart';
import 'api_config.dart';
import '../storage/storage_manager.dart';

class EchoService {
  static Echo? _echo;
  static PusherClient? _pusher;
  static bool _isConnected = false;
  static bool _isInitializing = false; // Guard untuk mencegah init() paralel
  static bool _isSubscribed = false;   // True setelah subscription channel berhasil diauth
  static int? _lastUserId;

  static bool get isConnected => _isConnected;
  /// isSubscribed = true berarti private channel berhasil diauth ke server.
  /// Gunakan ini (bukan isConnected) untuk guard FCM foreground handler.
  static bool get isSubscribed => _isSubscribed;

  static Future<void> init({int? currentUserId}) async {
    // Guard: Jangan init kalau sedang ada proses init yang berjalan
    if (_isInitializing) {
      debugPrint('Echo: init() dipanggil tapi sedang initializing, skip.');
      return;
    }

    // Jika sudah ada koneksi aktif dengan user yang sama, skip
    if (_echo != null && _isConnected && _lastUserId == currentUserId) {
      debugPrint('Echo: Already connected for user $currentUserId');
      return;
    }

    _isInitializing = true;

    // Jika ada koneksi lama, putuskan dahulu dan tunggu sejenak
    if (_echo != null || _pusher != null) {
      debugPrint('Echo: Disconnecting old connection before reinit...');
      await disconnect();
      // Re-set flag karena disconnect() me-reset _isInitializing = false
      _isInitializing = true;
      // Beri waktu agar thread WebSocket lama benar-benar mati
      await Future.delayed(const Duration(milliseconds: 300));
    }

    final token = await StorageManager.getToken();
    if (token == null) {
      debugPrint('Echo ERROR: Cannot init — No Auth Token found!');
      _isInitializing = false;
      return;
    }

    _lastUserId = currentUserId;
    _isSubscribed = false; // Reset subscription state saat reinit

    try {
      final pusherOptions = PusherOptions(
        host: ApiConfig.reverbHost,
        wsPort: 443,
        wssPort: 443,
        encrypted: true,
        auth: PusherAuth(
          '${ApiConfig.baseUrl.replaceAll('/v1', '')}/broadcasting/auth',
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',         // ← WAJIB: tanpa ini Laravel redirect ke route('login') → 500/404
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );

      _pusher = PusherClient(
        ApiConfig.reverbKey,
        pusherOptions,
        autoConnect: false,
        enableLogging: true,
      );

      _pusher!.onConnectionStateChange((state) {
        // currentState = state baru, previousState = state lama
        final current = state?.currentState ?? 'UNKNOWN';
        final previous = state?.previousState ?? 'UNKNOWN';
        debugPrint('Echo Connection State: $previous → $current');
        _isConnected = current == 'CONNECTED';
      });

      _pusher!.onConnectionError((error) {
        debugPrint('Echo Connection ERROR: ${error?.message}');
        _isConnected = false;
      });

      _echo = Echo(broadcaster: EchoBroadcasterType.Pusher, client: _pusher!);

      _pusher!.connect();

      debugPrint('Echo Service initialized. Host: ${ApiConfig.reverbHost}:443 (wss)');
    } catch (e) {
      debugPrint('Echo init error: $e');
      _echo = null;
      _pusher = null;
      _isConnected = false;
    } finally {
      _isInitializing = false;
    }
  }

  static void listen(String channel, String event, Function(dynamic) callback) {
    if (_echo == null) {
      debugPrint("Echo WARN: Cannot listen — not initialized. Channel: $channel Event: $event");
      return;
    }

    debugPrint("Echo: Subscribing → private-$channel / $event");
    _echo!.private(channel).listen(event, (e) {
      // Event diterima = subscription berhasil diauth
      _isSubscribed = true;
      debugPrint("Echo ✅ Event Received on $channel / $event");
      // pusher_client_fixed mengirim PusherEvent, bukan Map
      // Kita perlu extract .data (JSON string) dan decode
      try {
        Map<String, dynamic>? data;
        if (e is PusherEvent) {
          final rawData = e.data;
          if (rawData != null && rawData.isNotEmpty) {
            data = jsonDecode(rawData) as Map<String, dynamic>;
          }
        } else if (e is Map<String, dynamic>) {
          data = e;
        } else if (e is String) {
          data = jsonDecode(e) as Map<String, dynamic>;
        }
        callback(data);
      } catch (err) {
        debugPrint("Echo: Failed to decode event data on $channel / $event: $err");
        callback(null);
      }
    });
  }

  static void listenNotification(String channel, Function(dynamic) callback) {
    if (_echo == null) {
      debugPrint("Echo WARN: Cannot listenNotification — not initialized. Channel: $channel");
      return;
    }

    debugPrint("Echo: Subscribing notifications → private-$channel");
    _echo!.private(channel).notification((e) {
      debugPrint("Echo ✅ Notification Received on $channel");
      try {
        Map<String, dynamic>? data;
        if (e is PusherEvent) {
          final rawData = e.data;
          if (rawData != null && rawData.isNotEmpty) {
            data = jsonDecode(rawData) as Map<String, dynamic>;
          }
        } else if (e is Map<String, dynamic>) {
          data = e;
        } else if (e is String) {
          data = jsonDecode(e) as Map<String, dynamic>;
        }
        callback(data);
      } catch (err) {
        debugPrint("Echo: Failed to decode notification data on $channel: $err");
        callback(null);
      }
    });
  }

  static void leave(String channel) {
    debugPrint("Echo: Leaving channel private-$channel");
    _echo?.leave(channel);
  }

  static void reconnect() {
    if (_pusher != null && !_isConnected && !_isInitializing) {
      debugPrint('Echo: Attempting to reconnect Pusher natively...');
      _pusher!.connect();
    }
  }

  static Future<void> disconnect() async {
    debugPrint('Echo: Disconnecting...');
    try {
      _echo?.disconnect();
    } catch (_) {}
    // KRITIS: Reset Dart singleton agar next init() membuat PusherClient baru
    // dengan token terbaru. Tanpa ini, Dart mengembalikan singleton lama
    // dan Kotlin terus pakai token user sebelumnya → auth 500 setelah relogin.
    try {
      PusherClient.resetSingleton();
    } catch (_) {}
    _echo = null;
    _pusher = null;
    _isConnected = false;
    _isSubscribed = false;
    _lastUserId = null;
    // Reset initializing flag juga, kalau disconnect dipanggil dari luar saat init
    _isInitializing = false;
  }
}
