import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../pos/presentation/widgets/receipt_view.dart';
import '../../domain/entities/report_transaction.dart';
import '../../domain/repositories/report_repository.dart';
import '../cubit/receipt_detail_cubit.dart';
import '../cubit/receipt_detail_state.dart';

/// Halaman struk historis yang dibuka dari daftar Laporan Penjualan.
///
/// Halaman ini MEMBUKTIKAN prinsip *immutability* riwayat transaksi:
/// - Struk dirakit ulang HANYA dari tabel `transactions`, `transaction_items`,
///   dan `transaction_item_addons`.
/// - Tidak ada query/JOIN ke master `products` atau `addons`.
/// - Nama, harga, dan nama kasir dibaca dari kolom snapshot, sehingga struk
///   tetap tampil utuh meskipun master data diubah atau dihapus.
///
/// Tampilan kartu struk memakai ulang [ReceiptView] milik fitur POS agar hasil
/// cetak historis identik dengan struk setelah checkout.
class ReportReceiptPage extends StatelessWidget {
  const ReportReceiptPage({super.key, required this.transaction});

  /// Data ringkas transaksi yang diketuk di daftar riwayat.
  ///
  /// Dipakai untuk mengetahui id transaksi yang akan dibaca. Isi struk tetap
  /// diambil ulang dari database lewat [ReceiptDetailCubit] agar halaman ini
  /// benar-benar membuktikan pembacaan snapshot, bukan sekadar memakai data
  /// daftar.
  final ReportTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ReportRepository>();

    return BlocProvider(
      create: (_) =>
          ReceiptDetailCubit(repository, transaction.transactionId)..load(),
      child: _ReportReceiptView(transaction: transaction),
    );
  }
}

class _ReportReceiptView extends StatelessWidget {
  const _ReportReceiptView({required this.transaction});

  final ReportTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReceiptDetailCubit, ReceiptDetailState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Struk Historis')),
          body: SafeArea(child: _buildBody(context, state)),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ReceiptDetailState state) {
    final receipt = state.receipt;

    // Saat struk belum pernah berhasil dimuat, tampilkan spinner penuh.
    if (state.isLoading && receipt == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (receipt == null && state.status == ReceiptDetailStatus.failure) {
      return _buildFailure(context, state);
    }

    if (receipt == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildSnapshotBanner(context),
            const SizedBox(height: 16),
            // Kartu struk yang sama dengan yang dipakai setelah checkout.
            ReceiptView(receipt: receipt),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              label: const Text('Tutup Struk'),
            ),
          ],
        ),
      ),
    );
  }

  /// Penjelasan singkat bahwa struk dibaca dari snapshot, bukan master data.
  Widget _buildSnapshotBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.history_toggle_off,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Struk dari riwayat transaksi',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Isi struk dibaca dari salinan data (snapshot) saat '
                  'transaksi terjadi. Perubahan harga atau penghapusan produk '
                  'dan add-on tidak akan mengubah struk ini.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tampilan kegagalan saat struk tidak bisa dibaca.
  Widget _buildFailure(BuildContext context, ReceiptDetailState state) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Struk tidak dapat ditampilkan',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              transaction.invoiceNumber,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.failure?.message ?? 'Silakan coba lagi.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.read<ReceiptDetailCubit>().load(),
              style: FilledButton.styleFrom(minimumSize: const Size(180, 48)),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
