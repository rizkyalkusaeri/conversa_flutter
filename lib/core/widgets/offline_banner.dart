import 'package:flutter/material.dart';
import '../network/connectivity_service.dart';

/// Banner animasi yang tampil otomatis saat koneksi internet terputus.
///
/// Letakkan sebagai wrapper untuk [body] di dalam [Scaffold]:
/// ```dart
/// body: OfflineBanner(
///   child: IndexedStack(...),
/// ),
/// ```
///
/// Banner akan muncul/hilang dengan animasi smooth 300ms.
/// Tidak mempengaruhi route, navigator, atau state apapun.
class OfflineBanner extends StatelessWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<ConnectivityStatus>(
          stream: ConnectivityService.instance.onStatusChange,
          initialData: ConnectivityService.instance.currentStatus,
          builder: (context, snapshot) {
            final isOffline = snapshot.data == ConnectivityStatus.offline;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: isOffline ? 40 : 0,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(color: Color(0xFFB71C1C)),
              child: isOffline
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off_rounded, color: Colors.white, size: 15),
                        SizedBox(width: 8),
                        Text(
                          'Tidak ada koneksi internet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            );
          },
        ),
        Expanded(child: child),
      ],
    );
  }
}
