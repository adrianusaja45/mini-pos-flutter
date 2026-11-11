import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/report_transaction.dart';
import '../../domain/repositories/report_repository.dart';
import '../cubit/report_cubit.dart';
import '../cubit/report_state.dart';
import '../widgets/sales_summary_card.dart';
import '../widgets/transaction_history_tile.dart';
import 'report_receipt_page.dart';

/// Halaman Laporan Penjualan (100% offline).
///
/// Terdiri dari dua bagian:
/// 1. **Ringkasan penjualan** — total pendapatan & jumlah transaksi sukses.
/// 2. **Riwayat transaksi** — seluruh transaksi, terbaru lebih dulu.
///
/// Mengetuk salah satu riwayat membuka struk historis yang dibaca dari kolom
/// snapshot, bukan dari master produk/add-on.
class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Repository disediakan di main.dart melalui RepositoryProvider sehingga
    // halaman ini tidak perlu membuat koneksi database sendiri.
    final repository = context.read<ReportRepository>();

    return BlocProvider(
      // Cubit langsung memuat ringkasan + riwayat saat halaman dibuka.
      create: (_) => ReportCubit(repository)..load(),
      child: const _ReportView(),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView();

  /// Membuka struk historis milik transaksi yang diketuk.
  void _openReceipt(BuildContext context, ReportTransaction transaction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportReceiptPage(transaction: transaction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReportCubit, ReportState>(
      // Snackbar hanya muncul saat pesan kegagalan berubah, bukan setiap kali
      // state lain (mis. daftar) ikut diperbarui.
      listenWhen: (previous, current) => previous.failure != current.failure,
      listener: (context, state) {
        final failure = state.failure;
        if (failure == null) return;

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Laporan Penjualan'),
            actions: [
              IconButton(
                tooltip: 'Muat ulang laporan',
                onPressed: state.isLoading
                    ? null
                    : () => context.read<ReportCubit>().load(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(child: _buildBody(context, state)),
        );
      },
    );
  }

  /// Menentukan tampilan sesuai status pemuatan.
  Widget _buildBody(BuildContext context, ReportState state) {
    // Spinner penuh hanya dipakai saat benar-benar belum ada data. Saat
    // refresh, daftar lama tetap terlihat agar layar tidak berkedip kosong.
    if (state.isLoading && state.transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == ReportStatus.failure && state.transactions.isEmpty) {
      return _buildFailure(context, state);
    }

    return RefreshIndicator(
      onRefresh: () => context.read<ReportCubit>().load(),
      child: ListView(
        // Selalu bisa di-scroll agar pull-to-refresh tetap bekerja ketika
        // isi halaman belum memenuhi layar.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          SalesSummaryCard(summary: state.summary),
          const SizedBox(height: 20),
          _buildHistoryHeader(context, state),
          const SizedBox(height: 8),
          if (state.transactions.isEmpty)
            _buildEmptyHistory(context)
          else
            for (final transaction in state.transactions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TransactionHistoryTile(
                  transaction: transaction,
                  onTap: () => _openReceipt(context, transaction),
                ),
              ),
        ],
      ),
    );
  }

  /// Judul bagian riwayat + jumlah transaksi yang tampil.
  Widget _buildHistoryHeader(BuildContext context, ReportState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Riwayat Transaksi',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${state.transactions.length} transaksi',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  /// Tampilan saat belum ada transaksi sama sekali.
  Widget _buildEmptyHistory(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada transaksi',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Transaksi yang berhasil dibayar di Layar Kasir akan muncul di '
              'sini beserta ringkasan pendapatannya.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tampilan kegagalan saat data belum pernah berhasil dimuat.
  Widget _buildFailure(BuildContext context, ReportState state) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Gagal memuat laporan',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              state.failure?.message ?? 'Silakan coba lagi.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.read<ReportCubit>().load(),
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
