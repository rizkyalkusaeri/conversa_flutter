import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/cubit/app_auth/app_auth_cubit.dart';
import 'features/auth/cubit/app_auth/app_auth_state.dart';
import 'features/auth/repository/auth_repository.dart';
import 'features/auth/ui/login_page.dart';
import 'features/main/ui/main_page.dart';

void main() {
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
