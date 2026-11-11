import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/report_transaction.dart';

/// Satu baris riwayat transaksi pada halaman Laporan Penjualan.
///
/// Menampilkan empat informasi yang diminta:
/// 1. Nomor invoice,
/// 2. Waktu transaksi (waktu lokal perangkat),
/// 3. Nama kasir (snapshot saat transaksi),
/// 4. Total tagihan.
///
/// Seluruh data berasal dari kolom header `transactions`; tidak ada query ke
/// master produk, sehingga daftar historis tidak terpengaruh perubahan katalog.
class TransactionHistoryTile extends StatelessWidget {
  const TransactionHistoryTile({
    super.key,
    required this.transaction,
    required this.onTap,
  });

  final ReportTransaction transaction;

  /// Aksi saat baris diketuk: membuka struk historis dari snapshot.
  final VoidCallback onTap;

  /// Format waktu memakai pola numerik agar tidak bergantung pada data
  /// lokalisasi bulan.
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.invoiceNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _InfoLine(
                      icon: Icons.schedule,
                      // created_at disimpan UTC; toLocal() membuat jam yang
                      // tampil sesuai zona waktu perangkat kasir.
                      text: _dateFormat.format(transaction.createdAt.toLocal()),
                    ),
                    const SizedBox(height: 2),
                    _InfoLine(
                      icon: Icons.person_outline,
                      text: transaction.cashierName,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Kolom nominal dibatasi lebarnya agar harga besar tidak
              // mendorong teks invoice keluar layar.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        formatRupiah(transaction.totalAmount),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Flexible + ellipsis menjaga label tetap muat di
                        // kolom sempit (mis. saat nominal tagihan panjang).
                        Flexible(
                          child: Text(
                            'Lihat struk',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris kecil berisi ikon + teks informasi transaksi.
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
