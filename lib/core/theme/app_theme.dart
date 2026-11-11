import 'package:flutter/material.dart';

/// Tema global aplikasi.
///
/// Didefinisikan sekali di `core` agar seluruh halaman fitur (auth, master
/// data, POS, laporan) tampil konsisten. Nilai warna dan bentuk sengaja
/// dipusatkan di sini supaya perubahan desain tidak perlu menyentuh banyak
/// file UI.
class AppTheme {
  const AppTheme._();

  /// Warna utama aplikasi (hijau) yang memberi kesan segar dan cocok untuk
  /// aplikasi kasir/ritel.
  static const Color seedColor = Color(0xFF2E7D32);

  /// Tema terang (mode utama aplikasi POS).
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(seedColor: seedColor);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
      ),
      // Tombol utama dibuat lebar penuh agar mudah ditekan kasir saat sibuk.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        isDense: true,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
