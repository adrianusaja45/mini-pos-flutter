import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/cart_state.dart';
import 'cart_item_tile.dart';
import 'discount_sheet.dart';

/// Panel keranjang yang dipakai dua cara:
/// - menetap di sisi kanan pada layar lebar (tablet/desktop),
/// - ditampilkan sebagai bottom sheet pada layar ponsel.
///
/// Panel ini murni menampilkan [CartState]; seluruh perubahan data (item,
/// diskon) dilakukan lewat [CartCubit] sehingga aturan stok & diskon tetap
/// terpusat di Cubit.
///
/// [onPay] dipanggil saat kasir menekan "Bayar". Pemanggil (halaman POS) yang
/// menentukan cara membuka halaman pembayaran, karena halaman POS juga perlu
/// menutup bottom sheet keranjang bila panel sedang tampil sebagai sheet.
class CartPanel extends StatelessWidget {
  const CartPanel({super.key, this.onPay});

  /// Aksi tombol "Bayar"; `null` membuat tombol tidak bereaksi.
  final VoidCallback? onPay;

  /// Konfirmasi sebelum mengosongkan keranjang.
  ///
  /// Pengosongan sengaja memakai konfirmasi karena tindakan ini menghapus
  /// seluruh pilihan kasir dan tidak bisa dibatalkan.
  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kosongkan keranjang?'),
        content: const Text(
          'Semua item akan dihapus dari keranjang. Tindakan ini tidak bisa '
          'dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Kosongkan'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<CartCubit>().clear();
    }
  }

  /// Membuka sheet pengaturan diskon.
  ///
  /// State keranjang dikirim sebagai snapshot agar sheet menampilkan subtotal
  /// yang sama dengan yang dilihat kasir. Perubahan tetap dilakukan lewat
  /// [CartCubit] yang dioper sebagai callback.
  Future<void> _openDiscountSheet(BuildContext context, CartState state) {
    final cubit = context.read<CartCubit>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DiscountSheet(
        subtotal: state.subtotal,
        initialType: state.discountType,
        initialValue: state.discountValue,
        // Hasil dari Cubit dikembalikan ke sheet supaya pesan penolakan bisa
        // ditampilkan tanpa menutup sheet.
        onApply: (type, value) =>
            cubit.applyDiscount(type: type, value: value),
        onRemove: cubit.clearDiscount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ColoredBox(
      color: colorScheme.surface,
      child: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Keranjang',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${state.totalQuantity} unit',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (!state.isEmpty)
                      IconButton(
                        tooltip: 'Kosongkan keranjang',
                        visualDensity: VisualDensity.compact,
                        color: colorScheme.error,
                        onPressed: () => _confirmClear(context),
                        icon: const Icon(Icons.delete_sweep_outlined),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: state.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: state.items.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 66),
                        itemBuilder: (context, index) {
                          return CartItemTile(item: state.items[index]);
                        },
                      ),
              ),
              const Divider(height: 1),
              if (state.errorMessage != null)
                _buildErrorBanner(context, state.errorMessage!),
              _buildFooter(context, state),
            ],
          );
        },
      ),
    );
  }

  /// Tampilan saat belum ada item di keranjang.
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.remove_shopping_cart_outlined,
              size: 44,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 10),
            Text(
              'Keranjang kosong',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Klik produk di katalog untuk menambahkan.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Peringatan stok/kegagalan aksi terakhir.
  ///
  /// Ditampilkan di dalam panel (bukan snackbar) supaya tetap terbaca saat
  /// panel dibuka sebagai bottom sheet.
  Widget _buildErrorBanner(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      color: colorScheme.errorContainer,
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tutup peringatan',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            color: colorScheme.onErrorContainer,
            onPressed: () => context.read<CartCubit>().clearError(),
            icon: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }

  /// Baris diskon: menampilkan potongan aktif dan tombol pengaturan.
  ///
  /// Nominal yang tampil adalah [CartState.discountAmount], yaitu nilai yang
  /// BENAR-BENAR dipotong (sudah dijepit pada 0..subtotal). Jadi angka di layar
  /// selalu sama dengan angka yang nanti dikirim ke database.
  Widget _buildDiscountRow(BuildContext context, CartState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Text('Diskon', style: theme.textTheme.bodyMedium),
        if (state.hasDiscount)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '(${state.discountLabel})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const Spacer(),
        Flexible(
          child: Text(
            state.hasDiscount
                ? '- ${formatRupiah(state.discountAmount)}'
                : 'Belum ada',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: state.hasDiscount
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
              fontWeight: state.hasDiscount ? FontWeight.bold : null,
            ),
          ),
        ),
        IconButton(
          tooltip: state.hasDiscount ? 'Ubah diskon' : 'Tambah diskon',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: state.isEmpty
              ? null
              : () => _openDiscountSheet(context, state),
          icon: Icon(
            state.hasDiscount ? Icons.edit_outlined : Icons.local_offer_outlined,
            size: 18,
          ),
        ),
        if (state.hasDiscount)
          IconButton(
            tooltip: 'Hapus diskon',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            color: colorScheme.error,
            onPressed: () => context.read<CartCubit>().clearDiscount(),
            icon: const Icon(Icons.close, size: 18),
          ),
      ],
    );
  }

  /// Ringkasan subtotal, diskon, total, dan tombol pembayaran.
  Widget _buildFooter(BuildContext context, CartState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Subtotal', style: theme.textTheme.bodyMedium),
                ),
                Text(
                  formatRupiah(state.subtotal),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            _buildDiscountRow(context, state),
            if (state.isDiscountClamped)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'Diskon nominal otomatis dibatasi agar total tidak minus.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
            const Divider(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  formatRupiah(state.totalAmount),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              state.isEmpty
                  ? 'Belum ada item untuk dihitung.'
                  : '${state.lineCount} baris • '
                        '${state.totalQuantity} unit produk',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: state.isEmpty ? null : onPay,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.point_of_sale_outlined),
              label: const Text('Bayar'),
            ),
          ],
        ),
      ),
    );
  }
}
