import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/pos_product.dart';

/// Kartu produk pada grid katalog kasir.
///
/// Dua aksi sengaja dipisahkan demi kecepatan kerja kasir:
/// - Mengetuk kartu -> membuka pilihan add-on (bila ada) / menambah langsung.
/// - Menekan tombol "+" kecil -> menambah produk polos tanpa membuka apa pun.
///
/// Kartu yang stok efektifnya habis (stok database dikurangi isi keranjang)
/// ditampilkan dengan overlay "HABIS" dan tidak bisa ditekan.
class ProductCatalogCard extends StatelessWidget {
  const ProductCatalogCard({
    super.key,
    required this.product,
    required this.remainingStock,
    required this.addonCount,
    required this.onTap,
    required this.onQuickAdd,
  });

  final PosProduct product;

  /// Sisa stok yang masih boleh dijual setelah dikurangi isi keranjang.
  final int remainingStock;

  /// Jumlah add-on aktif; hanya dipakai sebagai penanda di kartu.
  final int addonCount;

  /// Aksi saat kartu diketuk (buka pilihan add-on / tambah langsung).
  final VoidCallback onTap;

  /// Aksi tombol "+" untuk menambah produk tanpa add-on.
  final VoidCallback onQuickAdd;

  bool get _isOutOfStock => remainingStock <= 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _isOutOfStock ? null : onTap,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildImage(context)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatRupiah(product.price),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _StockBadge(remainingStock: remainingStock),
                          ),
                          const SizedBox(width: 4),
                          IconButton.filledTonal(
                            tooltip: 'Tambah tanpa add-on',
                            onPressed: _isOutOfStock ? null : onQuickAdd,
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            constraints: const BoxConstraints.tightFor(
                              width: 30,
                              height: 30,
                            ),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Overlay menutup seluruh kartu sehingga aksi tap maupun tombol "+"
            // otomatis tidak bisa dipakai saat stok habis.
            if (_isOutOfStock)
              const Positioned.fill(child: _OutOfStockOverlay()),
          ],
        ),
      ),
    );
  }

  /// Area foto produk beserta penanda jumlah add-on.
  Widget _buildImage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imagePath = product.imagePath;

    Widget placeholder() {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.fastfood_outlined,
          size: 32,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        imagePath == null
            ? placeholder()
            : Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder(),
              ),
        if (addonCount > 0)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.extension_outlined,
                    size: 12,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$addonCount',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Label sisa stok pada kartu produk.
class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.remainingStock});

  final int remainingStock;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Warna dibedakan agar kasir cepat melihat produk yang hampir habis.
    final (background, foreground) = switch (remainingStock) {
      <= 0 => (colorScheme.errorContainer, colorScheme.onErrorContainer),
      <= 3 => (colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
      _ => (colorScheme.surfaceContainerHighest, colorScheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Sisa $remainingStock',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

/// Lapisan transparan bertuliskan "HABIS" di atas kartu produk.
class _OutOfStockOverlay extends StatelessWidget {
  const _OutOfStockOverlay();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surface.withValues(alpha: 0.78),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 14, color: colorScheme.onErrorContainer),
              const SizedBox(width: 4),
              Text(
                'HABIS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
