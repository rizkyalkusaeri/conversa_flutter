// lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // --- PALETTE UTAMA DARI GAMBAR ---

  // Warna Utama (Oranye Terang) - Lihat palette 'Primary' di gambar
  static const Color primary = Color(0xFFF27F0D);

  // Warna Sekunder (Cokelat Tua) - Diambil dari button 'Primary' di gambar
  static const Color secondary = Color(0xFF6D4C41);

  // Warna Tersier (Kuning Emas) - Lihat palette 'Tertiary' di gambar
  static const Color tertiary = Color(0xFFDDAD06);

  // Warna Netral (Abu-abu Cokelat) - Lihat palette 'Neutral' di gambar
  static const Color neutral = Color(0xFF9A6E41);

  // --- WARNA AKSEN & STATUS ---
  static const Color error = Color(0xFFB00020); // Warna merah standar
  static const Color primaryContainer = Color(
    0xFFFDEFD9,
  ); // Warna oranye super pudar untuk card/container

  // --- WARNA TEKS DARI GAMBAR ---
  // Teks di Headline/Body warna cokelat tua gelap
  static const Color textDark = Color(0xFF3E2723);

  static const Color success = Color(0xFF2E7D32);
}
