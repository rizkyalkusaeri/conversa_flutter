import 'package:fifgroup_android_ticketing/features/threads/ui/threads_page.dart';
import 'package:flutter/material.dart';
import '../../chat/ui/chat_page.dart';
import '../../profile/ui/profile_page.dart';
import '../../../core/constants/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/cubit/app_auth/app_auth_cubit.dart';
import '../../auth/cubit/app_auth/app_auth_state.dart';
import '../../search/ui/search_page.dart';
import '../../../core/network/echo_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/realtime_event_bus.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/update_service.dart';
import '../../../core/storage/storage_manager.dart';
import '../../profile/ui/privacy_policy_page.dart';
import '../../chat/cubit/active_session_count_cubit.dart';
import '../../chat/cubit/active_session_count_state.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const ChatPage(),
    const SearchPage(),
    const ThreadsPage(),
    const ProfilePage(),
  ];

  int? _currentUserId;

  // Guard untuk memastikan Echo listeners hanya didaftarkan SATU KALI.
  // Setiap kali reconnect (setelah resume), kita hanya perlu reconnect
  // koneksi WebSocket — bukan re-register listener.
  bool _listenersRegistered = false;

  // Guard agar NotificationService & FcmService tidak di-init berulang
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initUpdate();
    _initRealTime();
    _checkPrivacyPolicy();
  }

  Future<void> _checkPrivacyPolicy() async {
    final accepted = await StorageManager.isPrivacyPolicyAccepted();
    if (!accepted && mounted) {
      // Tunggu sebentar agar build selesai sebelum menampilkan bottom sheet
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          PrivacyPolicyPage.showAcceptanceSheet(context);
        }
      });
    }
  }

  Future<void> _initUpdate() async {
    // Jalankan cek update secara async tanpa menunggu UI terhambat
    if (mounted) {
      UpdateService.checkForUpdate(context);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed — checking Echo connection...');
      // Kalau koneksi Echo putus, panggil reconnect (tanpa re-init/destroy koneksi lama)
      // Pusher client plugin juga memiliki auto-reconnect native.
      // Kita tidak boleh memanggil EchoService.init() di sini karena akan bertabrakan dengan native reconnect.
      if (!EchoService.isConnected && _currentUserId != null) {
        debugPrint(
          'App resumed — Echo disconnected, requesting soft reconnect...',
        );
        EchoService.reconnect();
      }
    }
  }

  Future<void> _initRealTime() async {
    final authState = context.read<AppAuthCubit>().state;
    if (authState is! AppAuthAuthenticated) return;

    _currentUserId = authState.user.id;

    // 1. Init NotificationService (buat Android channel) — sekali saja
    if (!_servicesInitialized) {
      await NotificationService.init();
    }

    // 2. Init Echo (WebSocket ke Reverb)
    await EchoService.init(currentUserId: _currentUserId);

    // 3. Init FCM (minta permission, upload token ke server) — sekali saja
    //    Dijalankan setelah auth token tersedia
    if (!_servicesInitialized) {
      await FcmService.init();
      _servicesInitialized = true;
    }

    // 4. Daftarkan Echo listeners — hanya sekali
    _registerEchoListeners();

    if (mounted) {
      context.read<ActiveSessionCountCubit>().fetchCount();
    }
  }

  void _registerEchoListeners() {
    if (_listenersRegistered || _currentUserId == null) return;
    _listenersRegistered = true;

    debugPrint(
      'Echo [MainPage]: Registering listeners for user $_currentUserId',
    );

    // Session events: refresh list + notifikasi + forward ke EventBus
    EchoService.listen(
      'user.$_currentUserId',
      '.SessionCreated',
      _onSessionCreated,
    );
    EchoService.listen(
      'user.$_currentUserId',
      '.SessionUpdated',
      _onSessionUpdated,
    );

    // Notifikasi pesan baru dari SEMUA sesi
    EchoService.listen(
      'user.$_currentUserId',
      '.MessageSent',
      _onNewMessageReceived,
    );

    // Global Notification Listener (Filament / BroadcastNotificationCreated)
    EchoService.listenNotification(
      'App.Models.User.$_currentUserId',
      _onNotificationEvent,
    );
  }

  void _onSessionCreated(dynamic data) {
    debugPrint('Echo [MainPage]: SessionCreated received: $data');

    // Refresh session list
    RealtimeEventBus.instance.notifySessionRefresh();

    // Tampilkan notifikasi lokal
    if (data != null) {
      final ticketNumber = data['ticket_number'] as String?;
      NotificationService.showNotification(
        title: 'Sesi Baru Dibuat',
        body: ticketNumber != null
            ? 'Tiket #$ticketNumber telah dibuat.'
            : 'Sesi baru tersedia.',
      );
    }
  }

  void _onSessionUpdated(dynamic data) {
    debugPrint('Echo [MainPage]: SessionUpdated received: $data');

    // Refresh session list
    RealtimeEventBus.instance.notifySessionRefresh();

    // Forward ke ChatDetailPage jika sedang terbuka (via EventBus)
    if (data != null && data is Map<String, dynamic>) {
      RealtimeEventBus.instance.notifySessionUpdated(data);

      // Tampilkan notifikasi lokal HANYA jika bukan sesi yang sedang dibuka
      final sessionUuid = data['session_uuid'] as String?;
      if (sessionUuid == null ||
          sessionUuid != RealtimeEventBus.instance.activeSessionUuid) {
        final status = data['status'] as String?;
        NotificationService.showNotification(
          title: 'Status Sesi Diperbarui',
          body: status != null
              ? 'Status sesi berubah menjadi $status.'
              : 'Sesi telah diperbarui.',
        );
      }
    }
  }

  void _onNewMessageReceived(dynamic data) {
    if (data == null) return;

    final sessionUuid = data['session_uuid'] as String?;
    final senderName = data['sender_name'] as String? ?? 'Pesan Baru';
    final messageContent = data['message_content'] as String?;
    final messageType = data['message_type'] as String? ?? 'TEXT';

    // JANGAN tampilkan notifikasi jika user sedang membuka sesi tersebut
    if (sessionUuid != null &&
        sessionUuid == RealtimeEventBus.instance.activeSessionUuid) {
      debugPrint(
        'Echo [MainPage]: MessageSent untuk sesi aktif ($sessionUuid), skip notifikasi',
      );
      return;
    }

    // Tampilkan notifikasi untuk pesan dari sesi lain
    final body = messageType == 'TEXT'
        ? (messageContent ?? 'Pesan baru')
        : '📎 Mengirim lampiran';

    NotificationService.showNotification(title: '💬 $senderName', body: body);

    // Refresh session list untuk update badge unread
    RealtimeEventBus.instance.notifySessionRefresh();
  }

  void _onNotificationEvent(dynamic data) {
    if (data == null) return;

    final title =
        data['title'] ?? data['data']?['title'] ?? 'Pemberitahuan Baru';
    final body =
        data['body'] ??
        data['data']?['body'] ??
        'Cek aplikasi untuk info lebih lanjut.';

    NotificationService.showNotification(
      title: title.toString(),
      body: body.toString(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Putuskan koneksi Echo sepenuhnya saat MainPage di-dispose (logout)
    EchoService.disconnect();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    // Jika pindah ke tab Threads (index 2), picu refresh data terbaru
    if (index == 2) {
      RealtimeEventBus.instance.notifyThreadRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavIcon(
                Icons.chat_bubble_outline,
                Icons.chat_bubble,
                'Chat',
                0,
              ),
              _buildBottomNavIcon(Icons.search, Icons.search, 'Pencarian', 1),
              _buildBottomNavIcon(
                Icons.group_outlined,
                Icons.group,
                'Threads',
                2,
              ),
              _buildBottomNavIcon(
                Icons.person_outline,
                Icons.person,
                'Profil',
                3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavIcon(
    IconData icon,
    IconData activeIcon,
    String label,
    int index,
  ) {
    final isActive = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (index == 0) // Chat icon with badge
            BlocBuilder<ActiveSessionCountCubit, ActiveSessionCountState>(
              builder: (context, state) {
                int count = 0;
                if (state is ActiveSessionCountLoaded) {
                  count = state.count;
                }
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text(count.toString()),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? AppColors.primary : Colors.grey,
                    size: 24,
                  ),
                );
              },
            )
          else
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : Colors.grey,
              size: 24,
            ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? AppColors.primary : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
