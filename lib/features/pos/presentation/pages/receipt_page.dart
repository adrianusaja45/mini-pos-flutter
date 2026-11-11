import 'package:flutter/material.dart';

import '../../domain/entities/transaction_receipt.dart';
import '../widgets/receipt_view.dart';

/// Halaman pratinjau struk digital setelah transaksi berhasil disimpan.
///
/// Halaman ini hanya menampilkan data **snapshot** dari
/// [TransactionReceipt]. Tidak ada query ulang ke SQLite, sehingga:
/// - struk langsung tampil tanpa menunggu database,
/// - isi struk tidak mungkin berubah walaupun master produk diedit setelah
///   pembayaran (prinsip *immutability* riwayat transaksi).
///
/// Isi kartu struk dipisah ke [ReceiptView] agar dapat dipakai ulang oleh
/// fitur Laporan Penjualan saat membuka struk historis.
///
/// Tombol "Selesai" mengosongkan keranjang (lewat callback `onFinish`) lalu
/// kembali ke halaman katalog POS. Tombol back sengaja dinonaktifkan supaya
/// kasir tidak meninggalkan struk tanpa menyelesaikan alur dan tanpa sengaja
/// membayar ulang transaksi yang sama.
class ReceiptPage extends StatelessWidget {
  const ReceiptPage({super.key, required this.receipt, required this.onFinish});

  /// Data struk hasil transaksi.
  final TransactionReceipt receipt;

  /// Aksi "Selesai": kosongkan keranjang & muat ulang katalog.
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      // Back dinonaktifkan: satu-satunya jalan keluar adalah tombol "Selesai".
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Struk Digital'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // Banner konfirmasi agar kasir yakin transaksi tersimpan.
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pembayaran berhasil disimpan.',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Kartu struk yang sama dipakai halaman laporan historis.
                  ReceiptView(receipt: receipt),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: () {
                // Mengosongkan keranjang + memuat ulang stok katalog. Callback
                // bersifat idempotent sehingga aman bila sudah dipanggil saat
                // transaksi sukses.
                onFinish();
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.done_all),
              label: const Text('Selesai'),
            ),
          ),
        ),
      ),
    );
  }
}
