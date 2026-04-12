import 'package:laravel_echo/laravel_echo.dart';
import 'package:pusher_client_fixed/pusher_client_fixed.dart';
import 'package:flutter/foundation.dart';
import 'api_config.dart';
import '../storage/storage_manager.dart';

class EchoService {
  static Echo? _echo;

  static Future<void> init({int? currentUserId}) async {
    if (_echo != null) return;

    final token = await StorageManager.getToken();
    if (token == null) {
      debugPrint("Cannot init Echo: No Auth Token");
      return;
    }

    try {
      final pusherOptions = PusherOptions(
        host: ApiConfig.reverbHost,
        wsPort: 443,
        wssPort: 443,
        encrypted: true,
        cluster: 'mt1',
        auth: PusherAuth(
          '${ApiConfig.baseUrl.replaceAll('/v1', '')}/broadcasting/auth',
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      final pusher = PusherClient(
        'syhdndftedn1zdw285ub', // Dari REVERB_APP_KEY .env
        pusherOptions,
        autoConnect: false,
        enableLogging: true,
      );

      // Membersihkan cache native plugin (bawaan dari hot restart sebelumnya)
      // agar tidak terjadi "Already subscribed" saat melakukan subscribe ulang
      if (currentUserId != null) {
        try {
          pusher.unsubscribe('private-user.$currentUserId');
        } catch (_) {}
      }

      _echo = Echo(broadcaster: EchoBroadcasterType.Pusher, client: pusher);

      pusher.connect();

      debugPrint("Echo Service initialized successfully.");
    } catch (e) {
      debugPrint("Echo init error: $e");
    }
  }

  static void listen(String channel, String event, Function(dynamic) callback) {
    if (_echo == null) return;

    // Echo in dart usually requires prefixing the event with '.' if broadcastAs is used,
    // and if we use private channel, we subscribe via private()
    _echo!.private(channel).listen(event, (e) {
      debugPrint("Echo Event Received on $channel / $event: $e");
      callback(e);
    });
  }

  static void listenNotification(String channel, Function(dynamic) callback) {
    if (_echo == null) return;

    _echo!.private(channel).notification((e) {
      debugPrint("Echo Notification Received on $channel: $e");
      callback(e);
    });
  }

  static void leave(String channel) {
    _echo?.leave(channel);
  }

  static void disconnect() {
    _echo?.disconnect();
    _echo = null;
  }
}
