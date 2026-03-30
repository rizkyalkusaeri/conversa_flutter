// lib/features/auth/ui/login_page.dart
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
                        image: AssetImage("assets/images/1.png"),
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
                  _buildLabel("USERNAME"),
                  _buildTextField(usernameController, Icons.person, "Masukkan username..."),

                  const SizedBox(height: 20),

                  // INPUT PASSWORD
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabel("PASSWORD"),
                      // TextButton(
                      //   onPressed: () {},
                      //   child: const Text(
                      //     "FORGOT PASSWORD?",
                      //     style: TextStyle(
                      //       color: AppColors.primary,
                      //       fontSize: 12,
                      //       fontWeight: FontWeight.bold,
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                  _buildTextField(
                    passwordController,
                    Icons.lock,
                    "",
                    isPassword: state.isPasswordVisible,
                    onSuffixIconPressed: () {
                      context.read<LoginCubit>().togglePasswordVisibility();
                    },
                  ),

                  const SizedBox(height: 30),

                  // BUTTON LOGIN
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: state.isLoading
                          ? null
                          : () => context.read<LoginCubit>().login(
                              usernameController.text,
                              passwordController.text,
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: state.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Login",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Icon(Icons.arrow_forward, color: Colors.white),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Widget Helper untuk Label
  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  // Widget Helper untuk TextField
  Widget _buildTextField(
    TextEditingController controller,
    IconData icon,
    String hint, {
    bool isPassword = false,
    VoidCallback? onSuffixIconPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey),
          suffixIcon: onSuffixIconPressed != null
              ? IconButton(
                  icon: Icon(
                    isPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: onSuffixIconPressed,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}
