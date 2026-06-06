import 'package:flutter/material.dart';
import 'package:fifgroup_android_ticketing/data/models/user_model.dart';
import 'package:fifgroup_android_ticketing/data/repositories/profile_repository.dart';

class UserProfilePopup extends StatefulWidget {
  final int userId;

  const UserProfilePopup({
    super.key,
    required this.userId,
  });

  static Future<void> show(BuildContext context, int userId) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => UserProfilePopup(userId: userId),
    );
  }

  @override
  State<UserProfilePopup> createState() => _UserProfilePopupState();
}

class _UserProfilePopupState extends State<UserProfilePopup> {
  final ProfileRepository _repository = ProfileRepository();
  UserModel? _user;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _repository.getUserProfile(widget.userId);
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isLoading
              ? _buildLoadingState(theme, isDark)
              : _errorMessage != null
                  ? _buildErrorState(theme)
                  : _buildProfileState(theme, isDark),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme, bool isDark) {
    return SizedBox(
      key: const ValueKey('loading'),
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat profil...',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return SizedBox(
      key: const ValueKey('error'),
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'Gagal memuat profil',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadUserProfile,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileState(ThemeData theme, bool isDark) {
    final user = _user!;
    final initials = user.fullName.isNotEmpty
        ? user.fullName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : '?';

    return Column(
      key: const ValueKey('profile'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Close Button
        Align(
          alignment: Alignment.topRight,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(
              Icons.close,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              size: 20,
            ),
          ),
        ),
        
        // Avatar
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                theme.primaryColor,
                theme.primaryColor.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Name
        Text(
          user.fullName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),

        // Username
        Text(
          '@${user.username}',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),

        // Detail Rows
        _buildInfoRow(
          icon: Icons.shield_outlined,
          label: 'Role / Peran',
          value: user.role ?? '-',
          theme: theme,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          icon: Icons.work_outline,
          label: 'Jabatan (Level)',
          value: user.level ?? '-',
          theme: theme,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          icon: Icons.location_on_outlined,
          label: 'Kantor Cabang (Lokasi)',
          value: user.location ?? '-',
          theme: theme,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A32) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF33333C) : const Color(0xFFE9ECEF),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
