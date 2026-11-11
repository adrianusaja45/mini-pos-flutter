import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/receipt_addon.dart';
import '../../domain/entities/receipt_item.dart';
import '../../domain/entities/transaction_receipt.dart';

/// Kartu struk digital yang dapat dipakai ulang oleh beberapa fitur.
///
/// Widget ini sengaja HANYA menerima [TransactionReceipt] (data yang sudah jadi)
/// tanpa melakukan query apa pun. Dengan begitu:
/// - Fitur POS memakai data hasil checkout yang baru ditulis ke database.
/// - Fitur Laporan memakai data hasil pembacaan kolom snapshot dari tabel
///   `transactions`, `transaction_items`, dan `transaction_item_addons`.
///
/// Dalam dua kasus tersebut sumber angkanya sama-sama snapshot, sehingga struk
/// historis tidak berubah walaupun master produk/add-on diubah atau dihapus.
class ReceiptView extends StatelessWidget {
  const ReceiptView({super.key, required this.receipt});

  // Identitas toko contoh. Pada aplikasi nyata nilainya bisa diambil dari
  // pengaturan toko; untuk tahap ini cukup konstanta agar struk terasa lengkap.
  static const String _storeName = 'Kedai Mini POS';
  static const String _storeAddress = 'Jl. Contoh Raya No. 88, Jakarta';
  static const String _storePhone = 'Telp. 0812-0000-0000';

  /// Data struk yang akan dicetak di layar.
  final TransactionReceipt receipt;

  /// Format waktu struk memakai pola numerik agar tidak bergantung pada data
  /// lokalisasi bulan (aman dipakai tanpa inisialisasi locale tambahan).
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

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
            // ------------------- Kop struk -------------------
            Center(
              child: Text(
                _storeName,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: Text(
                _storeAddress,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Center(
              child: Text(
                _storePhone,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _DashedLine(),
            const SizedBox(height: 10),
            _ReceiptMetaRow(label: 'No. Invoice', value: receipt.invoiceNumber),
            _ReceiptMetaRow(label: 'Kasir', value: receipt.cashierName),
            _ReceiptMetaRow(
              label: 'Waktu',
              value: _dateFormat.format(receipt.createdAt),
            ),
            const SizedBox(height: 10),
            const _DashedLine(),
            const SizedBox(height: 10),
            // ------------------- Detail item -------------------
            for (final item in receipt.items) ...[
              _buildItem(context, item),
              const SizedBox(height: 10),
            ],
            const _DashedLine(),
            const SizedBox(height: 10),
            // ------------------- Ringkasan uang -------------------
            _ReceiptAmountRow(
              label: 'Subtotal',
              value: formatRupiah(receipt.subtotal),
            ),
            if (receipt.hasDiscount) ...[
              const SizedBox(height: 4),
              _ReceiptAmountRow(
                label: receipt.discountLabel,
                value: '- ${formatRupiah(receipt.discountAmount)}',
                valueColor: colorScheme.error,
              ),
            ],
            const SizedBox(height: 6),
            _ReceiptAmountRow(
              label: 'Total Akhir',
              value: formatRupiah(receipt.totalAmount),
              emphasize: true,
            ),
            const SizedBox(height: 10),
            const _DashedLine(),
            const SizedBox(height: 10),
            _ReceiptAmountRow(
              label: 'Tunai',
              value: formatRupiah(receipt.cashReceived),
            ),
            const SizedBox(height: 4),
            _ReceiptAmountRow(
              label: 'Kembalian',
              value: formatRupiah(receipt.changeAmount),
              emphasize: true,
            ),
            const SizedBox(height: 14),
            const _DashedLine(),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Terima kasih telah berbelanja',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Satu baris produk beserta add-on-nya pada struk.
  Widget _buildItem(BuildContext context, ReceiptItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatRupiah(item.lineSubtotal),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                '${item.quantity} x ${formatRupiah(item.unitPrice)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        for (final addon in item.addons) _buildAddon(context, addon),
      ],
    );
  }

  /// Baris add-on dengan indentasi agar terbaca sebagai bagian dari produk.
  Widget _buildAddon(BuildContext context, ReceiptAddon addon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '+ ${addon.name} x ${addon.quantity}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            formatRupiah(addon.price * addon.quantity),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris "label : nilai" untuk informasi invoice/kasir/waktu.
class _ReceiptMetaRow extends StatelessWidget {
  const _ReceiptMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris nominal (subtotal, diskon, total, tunai, kembalian).
class _ReceiptAmountRow extends StatelessWidget {
  const _ReceiptAmountRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style:
                (emphasize
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(fontWeight: emphasize ? FontWeight.bold : null),
          ),
        ),
        Text(
          value,
          style:
              (emphasize
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.bodyMedium)
                  ?.copyWith(
                    color: valueColor ?? theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
        ),
      ],
    );
  }
}

/// Garis putus-putus khas struk kertas.
///
/// Dibuat manual (bukan memakai `Divider`) karena Flutter tidak menyediakan
/// garis putus-putus bawaan, sedangkan menambah package hanya untuk ini tidak
/// sepadan.
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Satu pengulangan memakai 8 px (4 px garis + 4 px celah).
        final count = (constraints.maxWidth / 8).floor();
        if (count <= 0) return const SizedBox.shrink();

        return Row(
          children: [
            for (var i = 0; i < count; i++)
              Expanded(
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: color,
                ),
              ),
          ],
        );
      },
    );
  }
}
