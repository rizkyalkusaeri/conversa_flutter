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
  static int? _lastUserId;

  static bool get isConnected => _isConnected;

  static Future<void> init({int? currentUserId}) async {
    // Jika sudah ada koneksi aktif dengan user yang sama, skip
    if (_echo != null && _isConnected && _lastUserId == currentUserId) {
      debugPrint("Echo: Already connected for user $currentUserId");
      return;
    }

    // Jika ada koneksi lama, putuskan dahulu
    if (_echo != null) {
      debugPrint("Echo: Disconnecting old connection before reinit");
      await disconnect();
    }

    final token = await StorageManager.getToken();
    if (token == null) {
      debugPrint("Echo ERROR: Cannot init — No Auth Token found!");
      return;
    }

    _lastUserId = currentUserId;

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
            'Accept': 'application/json',
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
        debugPrint("Echo Connection State: ${state?.currentState} → ${state?.previousState}");
        _isConnected = state?.currentState == 'CONNECTED';
      });

      _pusher!.onConnectionError((error) {
        debugPrint("Echo Connection ERROR: ${error?.message}");
        _isConnected = false;
      });

      _echo = Echo(broadcaster: EchoBroadcasterType.Pusher, client: _pusher!);

      _pusher!.connect();

      debugPrint("Echo Service initialized. Host: ${ApiConfig.reverbHost}:443 (wss)");
    } catch (e) {
      debugPrint("Echo init error: $e");
      _echo = null;
      _pusher = null;
      _isConnected = false;
    }
  }

  static void listen(String channel, String event, Function(dynamic) callback) {
    if (_echo == null) {
      debugPrint("Echo WARN: Cannot listen — not initialized. Channel: $channel Event: $event");
      return;
    }

    debugPrint("Echo: Subscribing → private-$channel / $event");
    _echo!.private(channel).listen(event, (e) {
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

  static Future<void> disconnect() async {
    debugPrint("Echo: Disconnecting...");
    _echo?.disconnect();
    _echo = null;
    _pusher = null;
    _isConnected = false;
    _lastUserId = null;
  }

  static void reconnect() {
    if (_pusher != null && !_isConnected) {
      debugPrint("Echo: Attempting to reconnect Pusher natively...");
      _pusher!.connect();
    }
  }
}
