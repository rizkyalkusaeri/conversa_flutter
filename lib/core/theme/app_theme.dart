// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  // Kita buat getter untuk mengambil Tema Light
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      // 1. Konfigurasi ColorScheme Dasar
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        surface: AppColors
            .primaryContainer, // Kita pakai oranye pudar untuk background card
        error: AppColors.error,
        brightness: Brightness.light,
      ),

      // 2. Global Text Theme (Tipografi)
      // Ini akan membuat Headline, Body, dan Label pakai warna cokelat tua konsisten
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
        ),
        bodyMedium: TextStyle(color: AppColors.textDark, fontFamily: 'Poppins'),
        labelLarge: TextStyle(color: AppColors.textDark, fontFamily: 'Poppins'),
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
          fontFamily: 'Poppins',
        ),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.textDark, fontFamily: 'Poppins'),
        titleMedium: TextStyle(color: AppColors.textDark, fontFamily: 'Poppins'), // Untuk input text pada TextField
        titleSmall: TextStyle(color: AppColors.textDark, fontFamily: 'Poppins'),
        bodySmall: TextStyle(color: AppColors.textDark, fontFamily: 'Poppins'),
      ),

      // 3. Konfigurasi Input Global (Aksesibilitas Font Poppins pada Input Field & Hints)
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(fontFamily: 'Poppins', color: Color(0xFF9CA3AF)),
        labelStyle: TextStyle(fontFamily: 'Poppins'),
        errorStyle: TextStyle(fontFamily: 'Poppins'),
      ),

      // 3. Konfigurasi Komponen Spesifik (Agar mirip tombol di gambar Mas)

      // Mengatur AppBar (Atas)
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),

      // Mengatur Elevated Button (Button Utama Cokelat)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              AppColors.secondary, // Warna cokelat tua dari button 'Primary'
          foregroundColor: Colors.white,
          minimumSize: const Size(88, 36),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // Mengatur Text Button (Inverted Button)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary, // Warna oranye
        ),
      ),
    );
  }
}
