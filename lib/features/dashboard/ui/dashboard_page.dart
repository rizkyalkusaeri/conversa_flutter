import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/cubit/app_auth/app_auth_cubit.dart';
import '../../auth/cubit/app_auth/app_auth_state.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide DashboardCubit local ke halaman ini dan otomatis fetch API pertama kali
    return BlocProvider(
      create: (context) => DashboardCubit()..fetchSummary(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              // ...Tarik ke bawah me-refresh
              // tidak usah dihandle manual lewat route context baru, tapi di builder context
            },
            child: BlocBuilder<DashboardCubit, DashboardState>(
              builder: (context, state) {
                // Konfigurasi ulang Refresh Indicator menggunakan inner context
                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<DashboardCubit>().fetchSummary();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 32),
                        _buildHeroCard(state),
                        const SizedBox(height: 24),
                        _buildStatsRow(state),
                        const SizedBox(height: 24),
                        _buildCreateSessionButton(),
                        const SizedBox(height: 32),
                        _buildSectionTitle("Recent Threads"),
                        const SizedBox(height: 16),
                        _buildThreadsList(state),
                        const SizedBox(height: 80), // Jarak ekstra buat bottom nav
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Header
  Widget _buildHeader(BuildContext context) {
    // Cek status global Auth untuk mendapatkan profile
    final authState = context.read<AppAuthCubit>().state;
    String userName = "Guest";
    String roleMessage = "Welcome";

    if (authState is AppAuthAuthenticated) {
      // Ambil nama pertama jika ada spasi
      final nameParts = authState.user.fullName.split(" ");
      userName = nameParts.isNotEmpty ? nameParts[0] : authState.user.username;
      roleMessage = authState.user.role ?? "User";
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(
                  'https://i.pravatar.cc/150?img=47'), // Placeholder image
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(roleMessage,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(
                  userName,
                  style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ],
            ),
          ],
        ),
        Stack(
          children: [
            const Icon(Icons.notifications_none,
                size: 28, color: AppColors.textDark),
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          ],
        ),
      ],
    );
  }

  // Hero Card
  Widget _buildHeroCard(DashboardState state) {
    String sessionsText = "Loading...";
    if (state is DashboardLoaded) {
      sessionsText = "You have ${state.summary.activeSessionsCount} active sessions today.";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Ready for your sessions?",
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            sessionsText,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
            child: const Text(
              "View Calendar",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  // Stats Row (Pecah jadi deret Horizontal Scroll atau Row Wrap)
  Widget _buildStatsRow(DashboardState state) {
    if (state is DashboardLoading || state is DashboardInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is DashboardError) {
      return Center(
        child: Text(
          "Error: ${state.message}",
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (state is DashboardLoaded) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            _buildStatCard(
              Icons.access_time_filled,
              "Active\nSessions",
              "${state.summary.activeSessionsCount}",
              AppColors.primary,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              Icons.check_circle,
              "Resolved\nSessions",
              "${state.summary.resolvedSessionsCount}",
              AppColors.success,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              Icons.chat_bubble,
              "Unread\nChats",
              "${state.summary.unreadChatsCount}",
              AppColors.secondary,
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildStatCard(IconData icon, String title, String value, Color color) {
    return Container(
      width: 130, // Fixed width agar rapi jika horizontal
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 28,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Create Session Button
  Widget _buildCreateSessionButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryContainer, width: 2.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              const Text(
                "Create New Session",
                style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Icon(Icons.chevron_right, color: AppColors.primary),
        ],
      ),
    );
  }

  // Pengganti Tabs judul section
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    );
  }

  // Thread List
  Widget _buildThreadsList(DashboardState state) {
    if (state is DashboardLoaded) {
      if (state.summary.recentThreads.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "No recent threads available",
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        );
      }

      return Column(
        children: state.summary.recentThreads.map((thread) {
          return _buildThreadItem(
            title: thread.title,
            author: thread.authorName,
            date: thread.createdAt, // Nanti diformat
          );
        }).toList(),
      );
    }
    return const SizedBox.shrink(); // Biarkan box stats sj yg loading
  }

  Widget _buildThreadItem({
    required String title,
    required String author,
    required String date,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
                color: AppColors.secondary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      author,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13),
                    ),
                    Text(
                      date, // Kalau bs diparsing lebih bagus, misal format 'd MMM yyyy'
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
