import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Service untuk menangani incoming sharing intent (Teks/Link/File) dari Android.
class ShareIntentService {
  ShareIntentService._();
  static final ShareIntentService instance = ShareIntentService._();

  StreamSubscription? _intentSub;
  List<SharedMediaFile>? _pendingMedia;
  void Function(List<SharedMediaFile>)? _onSharedContentReceived;

  /// Inisialisasi listener sharing intent.
  /// Dipanggil di main.dart saat startup.
  void init() {
    debugPrint('[ShareIntentService] Initializing share intent listener...');

    // 1. Listen ke sharing intent saat app di background/foreground
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        debugPrint('[ShareIntentService] Media stream received: ${value.length} items');
        _handleSharedMedia(value);
      },
      onError: (err) {
        debugPrint('[ShareIntentService] Media stream error: $err');
      },
    );

    // 2. Cek sharing intent saat app di-launch dari terminated state
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        debugPrint('[ShareIntentService] Initial media received: ${value.length} items');
        _handleSharedMedia(value);
      }
    }).catchError((err) {
      debugPrint('[ShareIntentService] Initial media error: $err');
    });
  }

  /// Memproses shared media yang masuk
  void _handleSharedMedia(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    if (_onSharedContentReceived != null) {
      // Jika callback terdaftar (MainPage aktif), langsung panggil
      _onSharedContentReceived!(files);
      // Reset intent library agar tidak mentrigger ulang saat resume
      ReceiveSharingIntent.instance.reset();
    } else {
      // Jika callback belum terdaftar (user belum login/dashboard belum siap), simpan di buffer
      debugPrint('[ShareIntentService] No callback registered. Buffering shared media.');
      _pendingMedia = files;
    }
  }

  /// Mendaftarkan callback untuk menangani shared media.
  /// Dipanggil di MainPage (dashboard) saat siap.
  void registerCallback(void Function(List<SharedMediaFile>) callback) {
    _onSharedContentReceived = callback;
    debugPrint('[ShareIntentService] Callback registered.');

    // Jika ada pending media di buffer, langsung eksekusi dan bersihkan
    if (_pendingMedia != null && _pendingMedia!.isNotEmpty) {
      debugPrint('[ShareIntentService] Processing buffered shared media.');
      callback(_pendingMedia!);
      _pendingMedia = null;
      ReceiveSharingIntent.instance.reset();
    }
  }

  /// Menghapus callback saat widget di-dispose
  void unregisterCallback() {
    _onSharedContentReceived = null;
    debugPrint('[ShareIntentService] Callback unregistered.');
  }

  /// Membersihkan subscription
  void dispose() {
    _intentSub?.cancel();
  }
}
