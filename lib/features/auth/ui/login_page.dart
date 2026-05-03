// lib/features/auth/ui/login_page.dart
import 'package:fifgroup_android_ticketing/core/widgets/form_label.dart';
import 'package:fifgroup_android_ticketing/core/widgets/form_text_field.dart';
import 'package:fifgroup_android_ticketing/core/widgets/app_version_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../cubit/login_cubit.dart';

class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginCubit(
        authRepository: context.read(),
        appAuthCubit: context.read(),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: BlocConsumer<LoginCubit, LoginState>(
          listener: (context, state) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: AppColors.error,
                ),
              );
            }
            if (state.successMessage != null) {
              // Menampilkan popup login sukses.
              // Navigasi ke Dashboard otomatis di-*handle* oleh root BlocBuilder di main.dart
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.successMessage!),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          },
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  // LOGO (Pakai Container Oranye Bulat)
                  Center(
                    child: SizedBox(
                      child: const Image(
                        image: AssetImage("assets/images/logo_filink.png"),
                        width: 150,
                        height: 150,
                      ),
                    ),
                  ),
                  const Text(
                    "Selamat Datang!",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const Text(
                    "Silahkan login untuk melanjutkan",
                    style: TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 40),

                  // INPUT USERNAME
                  FormLabel(text: "USERNAME"),
                  FormTextField(
                    controller: usernameController,
                    prefixIcon: Icons.person,
                    hintText: "Masukkan username...",
                  ),

                  const SizedBox(height: 20),

                  // INPUT PASSWORD
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FormLabel(text: "PASSWORD"),
                    ],
                  ),
                  FormTextField(
                    controller: passwordController,
                    prefixIcon: Icons.lock,
                    hintText: "Masukkan password...",
                    obscureText: state.isPasswordVisible,
                    onSuffixIconPressed: () {
                      context.read<LoginCubit>().togglePasswordVisibility();
                    },
                  ),

                  // Banner rate-limit — tampil hanya saat IP sedang diblokir
                  if (state.isRateLimited) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_clock_outlined, color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Login diblokir sementara. Coba lagi dalam ${state.retryAfterSeconds} detik.',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // BUTTON LOGIN
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      // Nonaktifkan tombol saat loading ATAU sedang rate-limited
                      onPressed: (state.isLoading || state.isRateLimited)
                          ? null
                          : () => context.read<LoginCubit>().login(
                                usernameController.text,
                                passwordController.text,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: _buildButtonContent(state),
                    ),
                  ),

                  const SizedBox(height: 40),
                  const AppVersionText(),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Konten tombol login:
  /// - Loading  → CircularProgressIndicator
  /// - Blocked  → countdown timer
  /// - Normal   → teks "Login"
  Widget _buildButtonContent(LoginState state) {
    if (state.isLoading) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    if (state.isRateLimited) {
      return Text(
        'Coba lagi dalam ${state.retryAfterSeconds}s',
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white70,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    return const Text(
      "Login",
      style: TextStyle(
        fontSize: 18,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
