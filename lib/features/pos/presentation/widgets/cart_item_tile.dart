import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/cart_item.dart';
import '../cubit/cart_cubit.dart';

/// Satu baris item pada keranjang.
///
/// Aksi yang tersedia:
/// - tombol "-" mengurangi quantity (menghapus baris bila tersisa 1),
/// - tombol "+" menambah quantity dengan validasi stok bersama,
/// - tombol hapus membuang seluruh baris.
///
/// Pesan kegagalan (mis. stok tidak cukup) tampil sebagai banner di panel
/// keranjang melalui `CartState.errorMessage`, sehingga tetap terbaca saat
/// panel berupa bottom sheet di layar ponsel.
class CartItemTile extends StatelessWidget {
  const CartItemTile({super.key, required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cubit = context.read<CartCubit>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildThumbnail(context),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    IconButton(
                      tooltip: 'Hapus item',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                      color: colorScheme.error,
                      onPressed: () => cubit.removeItem(item.signature),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                ),
                Text(
                  item.addonSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatRupiah(item.lineTotal),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildQuantityStepper(context, cubit),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tombol pengatur quantity dengan ukuran ringkas agar muat di panel sempit.
  Widget _buildQuantityStepper(BuildContext context, CartCubit cubit) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          tooltip: 'Kurangi',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          onPressed: () => cubit.decreaseQuantity(item.signature),
          icon: const Icon(Icons.remove, size: 16),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '${item.quantity}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton.outlined(
          tooltip: 'Tambah',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          onPressed: () => cubit.increaseQuantity(item.signature),
          icon: const Icon(Icons.add, size: 16),
        ),
      ],
    );
  }

  /// Thumbnail kecil produk di keranjang.
  Widget _buildThumbnail(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imagePath = item.imagePath;

    Widget placeholder() {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.fastfood_outlined,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: imagePath == null
            ? placeholder()
            : Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder(),
              ),
      ),
    );
  }
}
