import 'package:flutter/material.dart';

/// Splash Screen yang tampil saat sesi login sedang diperiksa.
///
/// Logika pengecekan sesi berada di `SessionCubit.checkSession()` yang
/// dijalankan saat aplikasi start. Halaman ini murni visual: memberi tahu
/// kasir bahwa aplikasi sedang menyiapkan data lokal (SQLite) sebelum
/// berpindah ke Login atau Home.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ikon toko sebagai identitas aplikasi POS.
            CircleAvatar(
              radius: 44,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.storefront_rounded,
                size: 48,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Mini POS Offline',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Menyiapkan data kasir...',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            // Indikator proses: sesi sedang dibaca dari tabel user_sessions.
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
