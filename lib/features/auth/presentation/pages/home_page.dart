import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/auth_session.dart';
import '../../../master_data/presentation/pages/master_data_page.dart';
import '../cubit/session_cubit.dart';

/// Halaman Home **dummy** setelah kasir berhasil login.
///
/// Halaman ini sengaja masih sederhana karena fitur POS (katalog, keranjang,
/// pembayaran) akan dibuat pada tahap berikutnya. Tujuannya saat ini:
/// 1. Membuktikan alur login & sesi berjalan (nama kasir tampil).
/// 2. Menyediakan tombol Logout untuk menguji penghapusan sesi.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.session});

  /// Sesi kasir aktif; diberikan oleh [AuthGate] agar halaman ini tidak perlu
  /// membaca ulang database.
  final AuthSession session;

  /// Menampilkan dialog konfirmasi sebelum menghapus sesi.
  ///
  /// Logout sengaja memakai konfirmasi karena kasir harus mengetik PIN lagi
  /// untuk masuk, sehingga salah tekan tombol tidak langsung mengeluarkan akun.
  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: Text(
          'Kasir ${session.cashierName} akan keluar dan perlu login kembali '
          'untuk memulai transaksi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    // Pastikan widget masih terpasang sebelum memakai context setelah await.
    if (shouldLogout == true && context.mounted) {
      await context.read<SessionCubit>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Inisial nama kasir untuk avatar sederhana (mis. "Budi Santoso" -> "B").
    final initial = session.cashierName.trim().isEmpty
        ? '?'
        : session.cashierName.trim().substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini POS Offline'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        initial,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selamat bekerja,',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            session.cashierName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '@${session.user.username}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Pintu masuk fitur master data. Diletakkan di Home agar kasir
            // dapat mengelola katalog tanpa harus masuk ke halaman transaksi.
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.tertiaryContainer,
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                title: const Text(
                  'Master Data',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Kelola kategori, produk, dan add-on'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MasterDataPage()),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Halaman POS (dummy)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Katalog produk, keranjang, dan pembayaran akan dibuat '
                      'pada tahap berikutnya. Saat ini halaman ini hanya '
                      'menandakan bahwa sesi kasir berhasil tersimpan.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
