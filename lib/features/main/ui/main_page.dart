import 'package:fifgroup_android_ticketing/features/threads/ui/threads_page.dart';
import 'package:flutter/material.dart';
import '../../chat/ui/chat_page.dart';
import '../../profile/ui/profile_page.dart';
import '../../../core/constants/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/cubit/app_auth/app_auth_cubit.dart';
import '../../auth/cubit/app_auth/app_auth_state.dart';
import '../../chat/cubit/session_list_cubit.dart';
import '../../search/ui/search_page.dart';
import '../../../core/network/echo_service.dart';
import '../../../core/services/notification_service.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
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
    _initRealTime();
  }

  Future<void> _initRealTime() async {
    final authState = context.read<AppAuthCubit>().state;
    if (authState is AppAuthAuthenticated) {
      _currentUserId = authState.user.id;

      await NotificationService.init();
      await EchoService.init(currentUserId: _currentUserId);
      
      // Global Notification Listener (Filament / BroadcastNotificationCreated)
      EchoService.listenNotification(
        'App.Models.User.$_currentUserId',
        _onNotificationEvent,
      );
    }
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
