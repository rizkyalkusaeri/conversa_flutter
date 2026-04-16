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

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  // Daftar halaman fragment navigasi sesuai UI Reference:
  // 0: Home, 1: Search, 2: Sessions (Chat), 3: Profile
  final List<Widget> _pages = [
    const ChatPage(),
    const SearchPage(),
    const ThreadsPage(),
    const ProfilePage(),
  ];

  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initRealTime();
  }

  // Handle app lifecycle: reconnect saat app resume dari background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint("App resumed — reinitializing EchoService...");
      _initRealTime();
    }
  }

  Future<void> _initRealTime() async {
    final authState = context.read<AppAuthCubit>().state;
    if (authState is AppAuthAuthenticated) {
      _currentUserId = authState.user.id;

      await NotificationService.init();
      await EchoService.init(currentUserId: _currentUserId);

      // Inisialisasi FCM untuk push notification saat app terminated
      await FcmService.init();

      // Session events: refresh list + notifikasi
      EchoService.listen('user.$_currentUserId', '.SessionCreated', _onSessionListChanged);
      EchoService.listen('user.$_currentUserId', '.SessionUpdated', _onSessionListChanged);

      // Notifikasi pesan baru dari SEMUA sesi (ChatDetailPage akan filter jika sedang dibuka)
      EchoService.listen('user.$_currentUserId', '.MessageSent', _onNewMessageReceived);

      // Global Notification Listener (Filament / BroadcastNotificationCreated)
      EchoService.listenNotification('App.Models.User.$_currentUserId', _onNotificationEvent);
    }
  }

  void _onSessionListChanged(dynamic data) {
    debugPrint("Echo [MainPage]: Session event received: $data");

    // Trigger ChatPage untuk refresh session list
    RealtimeEventBus.instance.notifySessionRefresh();

    // Tampilkan notifikasi lokal
    if (data != null) {
      final ticketNumber = data['ticket_number'] as String?;
      final status = data['status'] as String?;

      if (ticketNumber != null) {
        // SessionCreated
        NotificationService.showNotification(
          title: 'Sesi Baru Dibuat',
          body: 'Tiket $ticketNumber telah dibuat.',
        );
      } else if (status != null) {
        // SessionUpdated
        NotificationService.showNotification(
          title: 'Status Sesi Diperbarui',
          body: 'Status sesi berubah menjadi $status.',
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
      debugPrint("Echo [MainPage]: MessageSent untuk sesi aktif ($sessionUuid), skip notifikasi");
      return;
    }

    // Tampilkan notifikasi untuk pesan dari sesi lain
    final body = messageType == 'TEXT'
        ? (messageContent ?? 'Pesan baru')
        : '📎 Mengirim lampiran';

    NotificationService.showNotification(
      title: '💬 $senderName',
      body: body,
    );

    // Refresh session list untuk update badge unread
    RealtimeEventBus.instance.notifySessionRefresh();
  }

  void _onNotificationEvent(dynamic data) {
    if (data == null) return;
    
    // Filament injects notification properties directly or inside a data map depending on structure.
    final title = data['title'] ?? data['data']?['title'] ?? 'Pemberitahuan Baru';
    final body = data['body'] ?? data['data']?['body'] ?? 'Cek aplikasi untuk info lebih lanjut.';
    
    NotificationService.showNotification(
      title: title.toString(),
      body: body.toString(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_currentUserId != null) {
      EchoService.leave('user.$_currentUserId');
    }
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      // floatingActionButton: _selectedIndex == 2
      //     ? null // ThreadsPage has its own FAB
      //     : FloatingActionButton(
      //         heroTag: 'main_fab',
      //         onPressed: () {
      //
      //         },
      //         backgroundColor: AppColors.primary,
      //         shape: const CircleBorder(),
      //         child: const Icon(Icons.confirmation_num, color: Colors.white),
      //       ),
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
                "Sessions",
                0,
              ),
              _buildBottomNavIcon(Icons.search, Icons.search, "Search", 1),
              _buildBottomNavIcon(
                Icons.group_outlined,
                Icons.group,
                "Threads",
                2,
              ),
              _buildBottomNavIcon(
                Icons.person_outline,
                Icons.person,
                "Profile",
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
