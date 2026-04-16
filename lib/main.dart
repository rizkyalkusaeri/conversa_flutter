import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/cubit/app_auth/app_auth_cubit.dart';
import 'features/auth/cubit/app_auth/app_auth_state.dart';
import 'package:fifgroup_android_ticketing/data/repositories/auth_repository.dart';
import 'features/auth/ui/login_page.dart';
import 'features/main/ui/main_page.dart';

// WAJIB: Background FCM handler harus top-level function
// Didaftarkan sebelum runApp() agar aktif saat app terminated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM [BG]: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase
  await Firebase.initializeApp();

  // Daftarkan background handler sebelum runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject dependencies utama skala App
    return MultiRepositoryProvider(
      providers: [RepositoryProvider(create: (context) => AuthRepository())],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                AppAuthCubit(authRepository: context.read<AuthRepository>())
                  ..checkAuthStatus(), // Langsung cek saat aplikasi hidup
          ),
        ],
        child: MaterialApp(
          title: 'Conversa Apps',
          theme: AppTheme.lightTheme,
          home: BlocBuilder<AppAuthCubit, AppAuthState>(
            builder: (context, state) {
              if (state is AppAuthAuthenticated) {
                // Return MainPage (wrapper BottomNavigation) ketika login
                return const MainPage();
              }
              if (state is AppAuthUnauthenticated) {
                // Return ke layar login
                return LoginPage();
              }
              // Jika baru mengecek token lokal, bisa kembali ke splash screen / spinner kosong
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            },
          ),
        ),
      ),
    );
  }
}
