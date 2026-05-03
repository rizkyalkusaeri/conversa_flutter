import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/services/fcm_service.dart';
import 'core/services/navigation_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/cubit/app_auth/app_auth_cubit.dart';
import 'features/auth/cubit/app_auth/app_auth_state.dart';
import 'features/chat/cubit/active_session_count_cubit.dart';
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
          BlocProvider(
            create: (context) => ActiveSessionCountCubit(),
          ),
        ],
        child: MaterialApp(
          navigatorKey: NavigationService.navigatorKey,
          title: 'Fi-Link',
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: BlocConsumer<AppAuthCubit, AppAuthState>(
            listener: (context, state) {
              if (state is AppAuthSessionExpired) {
                // Pastikan tidak ada dialog lain yang terbuka terlebih dahulu
                NavigationService.navigatorKey.currentState
                    ?.popUntil((route) => route.isFirst);

                showDialog(
                  context: NavigationService.navigatorKey.currentContext!,
                  barrierDismissible: false,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    icon: const Icon(
                      Icons.lock_clock_outlined,
                      size: 48,
                      color: Color(0xFFE53935),
                    ),
                    title: const Text(
                      'Sesi Telah Berakhir',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    content: const Text(
                      'Sesi Anda telah habis atau tidak valid. Silakan login kembali untuk melanjutkan.',
                      textAlign: TextAlign.center,
                    ),
                    actionsAlignment: MainAxisAlignment.center,
                    actions: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(
                            NavigationService.navigatorKey.currentContext!,
                          ).pop();
                          // Pindah ke LoginPage via cubit
                          context
                              .read<AppAuthCubit>()
                              .goToLogin();
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(160, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Login Kembali'),
                      ),
                    ],
                  ),
                );
              }
            },
            builder: (context, state) {
              if (state is AppAuthAuthenticated) {
                return const MainPage();
              }
              if (state is AppAuthUnauthenticated) {
                return LoginPage();
              }
              if (state is AppAuthSessionExpired) {
                // Tampilkan LoginPage di background saat dialog muncul
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
