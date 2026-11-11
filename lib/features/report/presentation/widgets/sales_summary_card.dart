import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/sales_summary.dart';

/// Kartu ringkasan penjualan (dashboard) di bagian atas halaman Laporan.
///
/// Menampilkan dua angka utama:
/// 1. Total Pendapatan (Revenue) dari seluruh transaksi sukses.
/// 2. Total Jumlah Transaksi sukses.
///
/// Widget ini murni tampilan; seluruh angka berasal dari [SalesSummary] yang
/// dihitung Cubit lewat repository, bukan dihitung di UI.
class SalesSummaryCard extends StatelessWidget {
  const SalesSummaryCard({super.key, required this.summary});

  final SalesSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                // Expanded + ellipsis mencegah judul terpotong/overflow saat
                // kartu tampil di layar ponsel sempit.
                Expanded(
                  child: Text(
                    'Ringkasan Penjualan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Dihitung dari seluruh transaksi yang tersimpan di perangkat '
              'ini.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            // Layout menyesuaikan lebar kartu: dua kolom bila cukup lebar,
            // ditumpuk vertikal bila ruang sempit agar nominal tidak terpotong.
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 340;
                final revenue = _SummaryMetric(
                  icon: Icons.payments_outlined,
                  label: 'Total Pendapatan',
                  value: formatRupiah(summary.totalRevenue),
                  highlight: true,
                );
                final count = _SummaryMetric(
                  icon: Icons.receipt_long_outlined,
                  label: 'Total Transaksi',
                  value: '${summary.totalTransactions}',
                  caption: 'transaksi sukses',
                );

                if (isNarrow) {
                  return Column(
                    children: [revenue, const SizedBox(height: 10), count],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: revenue),
                    const SizedBox(width: 10),
                    Expanded(child: count),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu kotak metrik di dalam [SalesSummaryCard].
class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;

  /// `true` untuk metrik utama (pendapatan) yang diberi warna aksen.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = highlight ? colorScheme.primary : colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: highlight
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: highlight
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // FittedBox menjaga nominal panjang (mis. Rp 1.234.567.890) tetap
          // terbaca penuh tanpa memicu overflow pada layar sempit.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: highlight ? foreground : null,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: highlight
                    ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
