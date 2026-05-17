import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/app_colors.dart';
import '../services/update_service.dart';

/// State internal dialog update
enum _UpdateDialogPhase { info, downloading, installing, error }

/// Tipe error — menentukan pesan & tombol aksi
enum _UpdateErrorType { noInternet, downloadInterrupted, permissionDenied, unknown }

/// Dialog blocking yang memaksa user update aplikasi.
/// Tidak bisa ditutup via back button atau tap di luar dialog.
class UpdateDialog extends StatefulWidget {
  final AppVersionInfo versionInfo;

  const UpdateDialog({super.key, required this.versionInfo});

  static Future<void> show(BuildContext context, AppVersionInfo info) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: UpdateDialog(versionInfo: info),
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogStateWidget();
}

class _UpdateDialogStateWidget extends State<UpdateDialog>
    with SingleTickerProviderStateMixin {
  _UpdateDialogPhase _phase = _UpdateDialogPhase.info;
  _UpdateErrorType _errorType = _UpdateErrorType.unknown;

  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;

  /// Path APK yang sudah berhasil didownload.
  /// Jika sudah ada, cukup install ulang tanpa re-download.
  String? _downloadedApkPath;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // Aksi
  // ──────────────────────────────────────────────

  /// Step 1 — Cek permission install SEBELUM mulai download.
  /// Jika belum granted, buka Settings dan tunggu user kembali.
  /// Return true jika sudah granted, false jika masih denied.
  Future<bool> _ensureInstallPermission() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.requestInstallPackages.status;
    debugPrint('UpdateDialog: Install permission = $status');
    if (status.isGranted) return true;

    // Buka Settings — user harus aktifkan manual
    await openAppSettings();

    // Cek ulang setelah user kembali dari Settings
    final retryStatus = await Permission.requestInstallPackages.status;
    debugPrint('UpdateDialog: Install permission after settings = $retryStatus');
    return retryStatus.isGranted;
  }

  /// Titik masuk utama: cek permission → download → install
  Future<void> _startDownloadFlow() async {
    // ① Cek permission dulu, SEBELUM download
    final permOk = await _ensureInstallPermission();
    if (!permOk) {
      _setError(_UpdateErrorType.permissionDenied);
      return;
    }

    // ② Download APK
    setState(() {
      _phase = _UpdateDialogPhase.downloading;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = 0;
    });

    try {
      _downloadedApkPath = await UpdateService.downloadApk(
        filename: widget.versionInfo.apkFilename,
        onProgress: (progress, received, total) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        },
      );
    } on NoInternetException {
      _setError(_UpdateErrorType.noInternet);
      return;
    } on DownloadInterruptedException {
      _setError(_UpdateErrorType.downloadInterrupted);
      return;
    } catch (e) {
      debugPrint('UpdateDialog: Download error — $e');
      _setError(_UpdateErrorType.unknown);
      return;
    }

    // ③ Install
    await _doInstall();
  }

  /// Install APK yang sudah ada di [_downloadedApkPath].
  /// Dipanggil setelah download selesai, atau saat retry install
  /// tanpa perlu download ulang.
  Future<void> _doInstall() async {
    if (_downloadedApkPath == null) {
      // Harusnya tidak terjadi, tapi fallback ke flow penuh
      await _startDownloadFlow();
      return;
    }

    if (!mounted) return;
    setState(() => _phase = _UpdateDialogPhase.installing);

    await Future.delayed(const Duration(milliseconds: 800));

    try {
      await UpdateService.installApk(_downloadedApkPath!);
      // Installer sudah terbuka — dialog tetap di state installing
    } on InstallPermissionDeniedException {
      // Permission dicabut setelah download — minta lagi
      _setError(_UpdateErrorType.permissionDenied);
    } catch (e) {
      debugPrint('UpdateDialog: Install error — $e');
      _setError(_UpdateErrorType.unknown);
    }
  }

  /// Hanya buka Settings lalu coba install ulang (APK sudah ada, tidak perlu re-download)
  Future<void> _openSettingsThenInstall() async {
    await openAppSettings();
    final status = await Permission.requestInstallPackages.status;
    if (!mounted) return;
    if (status.isGranted) {
      await _doInstall();
    } else {
      _setError(_UpdateErrorType.permissionDenied);
    }
  }

  void _setError(_UpdateErrorType type) {
    if (!mounted) return;
    setState(() {
      _phase = _UpdateDialogPhase.error;
      _errorType = type;
    });
  }

  // ──────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: KeyedSubtree(
            key: ValueKey(_phase),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return switch (_phase) {
      _UpdateDialogPhase.info => _buildInfoState(),
      _UpdateDialogPhase.downloading => _buildDownloadingState(),
      _UpdateDialogPhase.installing => _buildInstallingState(),
      _UpdateDialogPhase.error => _buildErrorState(),
    };
  }

  // ──────────────────────────────────────────────
  // State 1: Info Update
  // ──────────────────────────────────────────────
  Widget _buildInfoState() {
    final notes = widget.versionInfo.releaseNotes
        .replaceAll(r'\n', '\n')
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.system_update_rounded,
              size: 38,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Pembaruan Tersedia',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Versi ${widget.versionInfo.version}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (notes.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Yang baru:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 6),
                ...notes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 13)),
                        Expanded(
                          child: Text(
                            note.replaceAll(RegExp(r'^[-•]\s*'), ''),
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startDownloadFlow,
            icon: const Icon(Icons.download_rounded, size: 20),
            label: const Text(
              'Update Sekarang',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Update wajib dilakukan untuk melanjutkan.',
          style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // State 2: Downloading
  // ──────────────────────────────────────────────
  Widget _buildDownloadingState() {
    final percent = (_progress * 100).toStringAsFixed(0);
    final received = UpdateService.formatBytes(_receivedBytes);
    final total =
        _totalBytes > 0 ? UpdateService.formatBytes(_totalBytes) : '...';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.cloud_download_rounded,
          size: 52,
          color: AppColors.primary,
        ),
        const SizedBox(height: 16),
        const Text(
          'Mengunduh Pembaruan',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$received / $total',
          style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 10,
            backgroundColor: const Color(0xFFE0E0E0),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$percent%',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Jangan tutup aplikasi selama proses ini.',
          style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // State 3: Installing
  // ──────────────────────────────────────────────
  Widget _buildInstallingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
        const SizedBox(height: 20),
        const Text(
          'Membuka Installer...',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ikuti instruksi installer untuk menyelesaikan update.',
          style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // State 4: Error
  // ──────────────────────────────────────────────
  Widget _buildErrorState() {
    final cfg = _errorConfig();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: cfg.iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(cfg.icon, size: 36, color: cfg.iconColor),
        ),
        const SizedBox(height: 16),
        Text(
          cfg.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          cfg.message,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF666666),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Tombol aksi utama
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: cfg.primaryAction,
            icon: Icon(cfg.primaryIcon, size: 18),
            label: Text(
              cfg.primaryLabel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: cfg.iconColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        // Tombol sekunder jika ada
        if (cfg.secondaryLabel != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: cfg.secondaryAction,
              child: Text(
                cfg.secondaryLabel!,
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  _ErrorConfig _errorConfig() {
    return switch (_errorType) {
      _UpdateErrorType.noInternet => _ErrorConfig(
        icon: Icons.wifi_off_rounded,
        iconColor: const Color(0xFFE57373),
        title: 'Tidak Ada Koneksi Internet',
        message: 'Pastikan perangkat Anda terhubung ke internet, lalu coba lagi.',
        primaryIcon: Icons.refresh_rounded,
        primaryLabel: 'Coba Lagi',
        primaryAction: _startDownloadFlow, // Re-download karena gagal sebelum download
        secondaryLabel: null,
        secondaryAction: null,
      ),
      _UpdateErrorType.downloadInterrupted => _ErrorConfig(
        icon: Icons.cloud_off_rounded,
        iconColor: const Color(0xFFF57C00),
        title: 'Unduhan Terputus',
        message: 'Koneksi terputus saat mengunduh. Pastikan internet stabil dan coba lagi.',
        primaryIcon: Icons.refresh_rounded,
        primaryLabel: 'Ulangi Unduhan',
        primaryAction: _startDownloadFlow, // Re-download
        secondaryLabel: null,
        secondaryAction: null,
      ),
      _UpdateErrorType.permissionDenied => _ErrorConfig(
        icon: Icons.security_rounded,
        iconColor: const Color(0xFF7E57C2),
        title: 'Izin Instalasi Diperlukan',
        message:
            'Aktifkan izin "Instal aplikasi tidak dikenal" untuk Fi-Link di pengaturan, lalu kembali ke sini.',
        primaryIcon: Icons.settings_rounded,
        primaryLabel: 'Buka Pengaturan',
        // Setelah settings, langsung install — TIDAK download ulang jika APK sudah ada
        primaryAction: _downloadedApkPath != null
            ? _openSettingsThenInstall
            : _startDownloadFlow,
        secondaryLabel: _downloadedApkPath != null ? 'Sudah Diberi Izin, Install Sekarang' : null,
        secondaryAction: _downloadedApkPath != null ? _doInstall : null,
      ),
      _UpdateErrorType.unknown => _ErrorConfig(
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFE57373),
        title: 'Terjadi Kesalahan',
        message: 'Gagal memproses update. Silakan coba lagi.',
        primaryIcon: Icons.refresh_rounded,
        primaryLabel: 'Coba Lagi',
        primaryAction: _downloadedApkPath != null ? _doInstall : _startDownloadFlow,
        secondaryLabel: null,
        secondaryAction: null,
      ),
    };
  }
}

class _ErrorConfig {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final IconData primaryIcon;
  final String primaryLabel;
  final VoidCallback primaryAction;
  final String? secondaryLabel;
  final VoidCallback? secondaryAction;

  const _ErrorConfig({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.primaryIcon,
    required this.primaryLabel,
    required this.primaryAction,
    required this.secondaryLabel,
    required this.secondaryAction,
  });
}
