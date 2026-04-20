import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/services/fcm_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/cubit/app_auth/app_auth_cubit.dart';
import 'features/auth/cubit/app_auth/app_auth_state.dart';
import 'package:fifgroup_android_ticketing/data/repositories/auth_repository.dart';
import 'features/auth/ui/login_page.dart';
import 'features/main/ui/main_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase
  await Firebase.initializeApp();

  // WAJIB: Daftarkan background handler SEBELUM runApp & SEBELUM user login
  // Harus top-level function dengan @pragma('vm:entry-point')
  // Handler ini aktif saat app terminated/background tanpa Flutter engine
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // CATATAN: NotificationService.init() & FcmService.init() TIDAK dipanggil di sini
  // karena keduanya membutuhkan auth token yang baru tersedia setelah login.
  // Keduanya dipanggil di MainPage._initRealTime() setelah auth ready.

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
          debugShowCheckedModeBanner: false,
          home: BlocBuilder<AppAuthCubit, AppAuthState>(
            builder: (context, state) {
              if (state is AppAuthAuthenticated) {
                return const MainPage();
              }
              if (state is AppAuthUnauthenticated) {
                return LoginPage();
              }
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
