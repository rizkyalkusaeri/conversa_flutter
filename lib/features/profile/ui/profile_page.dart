import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/app_version_text.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/cubit/app_auth/app_auth_cubit.dart';
import 'package:fifgroup_android_ticketing/data/models/user_model.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';
import 'change_password_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileCubit()..getProfileDetails(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Profil',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [],
        ),
        body: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            UserModel? user;
            bool isLoading = state is ProfileLoading || state is ProfileInitial;

            if (state is ProfileLoaded) {
              user = state.user;
            } else if (state is ProfileError) {
              // Jika error fetch jaringan, gunakan data cache dari auth state sementara
              // Cast AppAuthState ke Authenticated untuk ambil fallback
              final authState = context.read<AppAuthCubit>().state;
              if (authState.runtimeType.toString() == 'AppAuthAuthenticated') {
                // Ignore type checking hack karena kita belum imp exp AuthModel ke sini
                // Alternatif aman: tampilkan error
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        state.message,
                        style: const TextStyle(color: Colors.red),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            context.read<ProfileCubit>().getProfileDetails(),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                );
              }
            }

            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (user == null) {
              return const Center(child: Text("Profil tidak ditemukan"));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAvatarAndName(user),
                  const SizedBox(height: 24),
                  _buildJobDetailsCard(user),
                  const SizedBox(height: 32),
                  _buildSettingsList(context),
                  const SizedBox(height: 48),
                  _buildLogoutButton(context),
                  const SizedBox(height: 24),
                  const AppVersionText(),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Header: Initial Avatar & Name
  Widget _buildAvatarAndName(UserModel user) {
    // Ekstraksi huruf inisial
    String initials = "U";
    if (user.fullName.isNotEmpty) {
      final parts = user.fullName
          .split(" ")
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.length > 1) {
        initials = "${parts[0][0]}${parts[1][0]}".toUpperCase();
      } else {
        initials = parts[0].substring(0, 1).toUpperCase();
      }
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: AppColors.primaryContainer,
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.fullName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Jabatan & Lokasi layaknya Session History stat Box
  Widget _buildJobDetailsCard(UserModel user) {
    return Row(
      children: [
        Expanded(
          child: _buildDetailBox(
            icon: Icons.work_outline,
            label: 'Jabatan / Level',
            value: user.level ?? 'Belum Diatur',
            iconColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildDetailBox(
            icon: Icons.location_on_outlined,
            label: 'Lokasi Kerja',
            value: user.location ?? 'Pusat (HO)',
            iconColor: AppColors.success,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildDetailBox(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Hak Akses',
            value: user.role ?? 'User',
            iconColor: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailBox({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    // Card memanjang ke bawah layout 3 pilar (mirip session history UI)
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white, // background putih pure
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // Settings List Menu (Notifications, Privacy, Help)
  Widget _buildSettingsList(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.03),
            offset: const Offset(0, 4),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildListTile(
            context: context,
            icon: Icons.lock_outline,
            title: "Ganti Password",
            iconBgColor: AppColors.primaryContainer,
            iconColor: AppColors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordPage(),
                ),
              );
            },
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
          _buildListTile(
            context: context,
            icon: Icons.help_outline,
            title: "Help & Support",
            iconBgColor: AppColors.primaryContainer,
            iconColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color iconBgColor,
    required Color iconColor,
    Widget? trailingWidget,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?trailingWidget,
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }

  // Logout Button Terbawah
  Widget _buildLogoutButton(BuildContext context) {
    return InkWell(
      hoverColor: Colors.transparent,
      onTap: () {
        // Panggil Global AppAuthCubit logOut
        context.read<AppAuthCubit>().logOut();
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.logout, color: Colors.redAccent, size: 24),
          SizedBox(width: 12),
          Text(
            "Log Out",
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
