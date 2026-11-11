import 'package:flutter/material.dart';

import 'core/database/database_helper.dart';
import 'core/theme/app_theme.dart';

/// Titik masuk aplikasi.
///
/// Database dibuka lebih dulu sebelum UI ditampilkan. Dengan begitu, saat
/// halaman fitur (auth, master data, POS) dibuka nanti, koneksi SQLite sudah
/// siap dipakai dan pengguna tidak melihat layar kosong sambil menunggu.
Future<void> main() async {
  // Wajib dipanggil karena kita memakai plugin (sqflite) sebelum runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Membuka database sekali di awal; skema akan dibuat otomatis saat pertama
  // kali aplikasi dijalankan.
  await DatabaseHelper.instance.database;

  runApp(const PosApp());
}

/// Widget akar aplikasi.
class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mini POS Offline',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _FoundationReadyPage(),
    );
  }
}

/// Halaman sementara untuk menandai fondasi (Tahap 1) sudah siap.
///
/// Halaman ini bukan fitur bisnis; nanti akan diganti oleh halaman login pada
/// tahap fitur autentikasi.
class _FoundationReadyPage extends StatelessWidget {
  const _FoundationReadyPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mini POS Offline')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storage_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Fondasi proyek & database SQLite siap',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
