import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/network/api_config.dart';

// ─────────────────────────────────────────────
// Custom Exceptions
// ─────────────────────────────────────────────

/// Tidak ada koneksi internet
class NoInternetException implements Exception {
  const NoInternetException();
  @override
  String toString() => 'Tidak ada koneksi internet.';
}

/// Download terputus di tengah jalan
class DownloadInterruptedException implements Exception {
  const DownloadInterruptedException();
  @override
  String toString() => 'Unduhan terputus. Coba lagi.';
}

/// Izin instalasi belum diberikan user
class InstallPermissionDeniedException implements Exception {
  const InstallPermissionDeniedException();
  @override
  String toString() => 'Izin instalasi belum diberikan.';
}

/// Model untuk menyimpan informasi versi dari Nextcloud
class AppVersionInfo {
  final String version;
  final int buildNumber;
  final String apkFilename;
  final String releaseNotes;
  final bool forceUpdate;

  const AppVersionInfo({
    required this.version,
    required this.buildNumber,
    required this.apkFilename,
    required this.releaseNotes,
    required this.forceUpdate,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      version: json['version'] as String? ?? '',
      buildNumber: json['build_number'] as int? ?? 0,
      apkFilename: json['apk_filename'] as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? '',
      forceUpdate: json['force_update'] as bool? ?? true,
    );
  }
}

class UpdateService {
  /// Base URL public share Nextcloud
  static const String _nextcloudToken = '2grPz9fwT6nH4S6';
  static const String _nextcloudBaseUrl = 'https://cloud.fi-link.id';
  static const String _folderPath = '/Aplikasi Android';

  /// URL untuk fetch version.json
  static String get _versionJsonUrl =>
      '$_nextcloudBaseUrl/s/$_nextcloudToken/download'
      '?path=${Uri.encodeComponent(_folderPath)}&files=version.json';

  /// URL untuk download APK
  static String _apkDownloadUrl(String filename) =>
      '$_nextcloudBaseUrl/s/$_nextcloudToken/download'
      '?path=${Uri.encodeComponent(_folderPath)}&files=${Uri.encodeComponent(filename)}';

  /// Cek apakah ada versi terbaru.
  /// Hanya berjalan di production build.
  /// Mengembalikan [AppVersionInfo] jika ada update, null jika tidak.
  static Future<AppVersionInfo?> checkForUpdate() async {
    // Hanya aktif di production
    if (!ApiConfig.isProduction) {
      debugPrint('UpdateService: Skipped (dev mode)');
      return null;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint(
        'UpdateService: Current app version=${packageInfo.version}, '
        'build=$currentBuildNumber',
      );

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          // Jangan paksa auto-decode ke Map — biarkan sebagai String/dynamic
          responseType: ResponseType.plain,
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      debugPrint('UpdateService: Fetching version.json from $_versionJsonUrl');

      final response = await dio.get<String>(_versionJsonUrl);

      debugPrint(
        'UpdateService: Response status=${response.statusCode}, '
        'body=${response.data?.substring(0, (response.data?.length ?? 0).clamp(0, 200))}',
      );

      if (response.statusCode != 200 || response.data == null || response.data!.trim().isEmpty) {
        debugPrint('UpdateService: version.json not found or empty. '
            'Pastikan file sudah diupload ke Nextcloud.');
        return null;
      }

      // Parse JSON manual dari string
      final Map<String, dynamic> json =
          Map<String, dynamic>.from(
            (response.data! as dynamic) is Map
                ? response.data! as Map
                : _parseJson(response.data!),
          );

      final remoteInfo = AppVersionInfo.fromJson(json);
      debugPrint(
        'UpdateService: Remote version=${remoteInfo.version}, '
        'build=${remoteInfo.buildNumber}',
      );

      // Ada update jika build_number di cloud lebih besar
      if (remoteInfo.buildNumber > currentBuildNumber) {
        debugPrint('UpdateService: Update available! ${remoteInfo.version}');
        return remoteInfo;
      }

      debugPrint('UpdateService: App is up to date.');
      return null;
    } catch (e, stack) {
      debugPrint('UpdateService: Error checking update — $e');
      debugPrint('UpdateService: Stack — $stack');
      return null;
    }
  }

  /// Parse JSON string ke Map secara manual menggunakan dart:convert
  static Map<String, dynamic> _parseJson(String jsonString) {
    // ignore: avoid_dynamic_calls
    return (jsonDecode(jsonString) as Map<String, dynamic>);
  }


  /// Download APK dari Nextcloud dengan progress callback.
  /// Melempar [NoInternetException] atau [DownloadInterruptedException] jika gagal.
  static Future<String> downloadApk({
    required String filename,
    required void Function(double progress, int receivedBytes, int totalBytes)
    onProgress,
  }) async {
    // Gunakan getExternalStorageDirectory agar FileProvider bisa mengaksesnya
    final dir = await getExternalStorageDirectory();
    final savePath = '${dir!.path}/$filename';

    // Hapus file lama jika ada
    final existingFile = File(savePath);
    if (await existingFile.exists()) {
      await existingFile.delete();
    }

    final dio = Dio();
    try {
      await dio.download(
        _apkDownloadUrl(filename),
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onProgress(progress, received, total);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          headers: {'Accept': 'application/vnd.android.package-archive'},
        ),
      );
    } on DioException catch (e) {
      // Hapus file yang mungkin partial
      if (await existingFile.exists()) await existingFile.delete();

      debugPrint('UpdateService: Download DioException type=${e.type}, msg=${e.message}');

      // Cek apakah ini masalah koneksi
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        throw const NoInternetException();
      }
      // Timeout atau cancel = koneksi terputus
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.cancel) {
        throw const DownloadInterruptedException();
      }
      throw const DownloadInterruptedException();
    } catch (e) {
      if (await existingFile.exists()) await existingFile.delete();
      debugPrint('UpdateService: Download unexpected error — $e');
      throw const DownloadInterruptedException();
    }

    return savePath;
  }

  /// Trigger sistem installer Android untuk menginstall APK.
  /// Melempar [InstallPermissionDeniedException] jika OpenFile gagal karena permission.
  static Future<void> installApk(String apkPath) async {
    final result = await OpenFile.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );
    debugPrint('UpdateService: OpenFile result = ${result.type} ${result.message}');

    if (result.type == ResultType.permissionDenied) {
      throw const InstallPermissionDeniedException();
    }
  }

  /// Format bytes ke string yang mudah dibaca (misal: "12.3 MB")
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
