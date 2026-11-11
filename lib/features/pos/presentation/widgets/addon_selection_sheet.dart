import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/pos_addon.dart';
import '../../domain/entities/pos_product.dart';

/// Hasil pemilihan pada bottom sheet add-on.
///
/// Hanya berisi add-on yang dicentang dan jumlah unit yang diminta. Validasi
/// stok tetap dilakukan oleh `CartCubit` agar semua aturan stok berada di satu
/// tempat (single source of truth), bukan tersebar di UI.
class AddonSelectionResult {
  const AddonSelectionResult({required this.addons, required this.quantity});

  final List<PosAddon> addons;
  final int quantity;
}

/// Bottom sheet pemilihan add-on sebelum produk masuk keranjang.
///
/// Sheet ini juga menampilkan sisa stok produk dan add-on **setelah dikurangi
/// isi keranjang**, sehingga kasir melihat angka yang sama dengan yang dipakai
/// validasi. Tombol "+" jumlah otomatis dibatasi agar tidak menawarkan angka
/// yang pasti akan ditolak.
class AddonSelectionSheet extends StatefulWidget {
  const AddonSelectionSheet({
    super.key,
    required this.product,
    required this.addons,
    required this.remainingProductStock,
    required this.remainingAddonStock,
  });

  final PosProduct product;

  /// Seluruh add-on aktif (add-on bersifat global pada skema aplikasi ini).
  final List<PosAddon> addons;

  /// Sisa stok produk setelah memperhitungkan seluruh isi keranjang.
  final int remainingProductStock;

  /// Sisa stok tiap add-on (id -> sisa) setelah memperhitungkan keranjang.
  final Map<int, int> remainingAddonStock;

  @override
  State<AddonSelectionSheet> createState() => _AddonSelectionSheetState();
}

class _AddonSelectionSheetState extends State<AddonSelectionSheet> {
  final Set<int> _selectedAddonIds = <int>{};
  int _quantity = 1;

  /// Batas jumlah yang boleh dipilih pada aksi ini.
  ///
  /// Nilainya adalah sisa stok produk dan sisa stok add-on yang dipilih;
  /// mana yang paling kecil itulah batasnya. Dengan begitu tombol "+" tidak
  /// pernah menawarkan jumlah yang melanggar *Shared Stock Validation*.
  int get _maxQuantity {
    var limit = widget.remainingProductStock;
    for (final addonId in _selectedAddonIds) {
      final remaining = widget.remainingAddonStock[addonId] ?? 0;
      if (remaining < limit) limit = remaining;
    }
    return limit < 1 ? 1 : limit;
  }

  /// Add-on terpilih sesuai urutan daftar (bukan urutan klik) agar hasilnya
  /// deterministik dan signature keranjang stabil.
  List<PosAddon> get _selectedAddons => widget.addons
      .where((addon) => _selectedAddonIds.contains(addon.id))
      .toList(growable: false);

  int get _unitTotal => widget.product.price + _addonUnitPrice;

  int get _addonUnitPrice =>
      _selectedAddons.fold<int>(0, (total, addon) => total + addon.price);

  int get _grandTotal => _unitTotal * _quantity;

  /// Mencentang / melepas satu add-on lalu menjaga quantity tetap valid.
  void _toggleAddon(PosAddon addon) {
    setState(() {
      if (_selectedAddonIds.contains(addon.id)) {
        _selectedAddonIds.remove(addon.id);
      } else {
        _selectedAddonIds.add(addon.id);
      }

      // Bila add-on baru membatasi jumlah, quantity lama ikut diturunkan agar
      // angka di layar tidak pernah melebihi stok yang tersedia.
      if (_quantity > _maxQuantity) {
        _quantity = _maxQuantity;
      }
    });
  }

  void _changeQuantity(int delta) {
    final next = _quantity + delta;
    if (next < 1 || next > _maxQuantity) return;
    setState(() => _quantity = next);
  }

  /// Menutup sheet sambil membawa pilihan ke pemanggil.
  void _submit() {
    if (widget.remainingProductStock <= 0) return;
    Navigator.of(
      context,
    ).pop(AddonSelectionResult(addons: _selectedAddons, quantity: _quantity));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handel kecil sebagai penanda sheet bisa digeser/ditutup.
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatRupiah(widget.product.price)} • '
                          'sisa stok ${widget.remainingProductStock}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Pilih add-on (opsional)',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final addon in widget.addons)
                    _buildAddonTile(context, addon),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('Jumlah', style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      IconButton.outlined(
                        tooltip: 'Kurangi jumlah',
                        visualDensity: VisualDensity.compact,
                        onPressed: _quantity > 1
                            ? () => _changeQuantity(-1)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '$_quantity',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton.outlined(
                        tooltip: 'Tambah jumlah',
                        visualDensity: VisualDensity.compact,
                        onPressed: _quantity < _maxQuantity
                            ? () => _changeQuantity(1)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            formatRupiah(_grandTotal),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: widget.remainingProductStock <= 0
                            ? null
                            : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(170, 48),
                        ),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Tambah'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Satu baris pilihan add-on.
  Widget _buildAddonTile(BuildContext context, PosAddon addon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final remaining = widget.remainingAddonStock[addon.id] ?? 0;
    final selected = _selectedAddonIds.contains(addon.id);

    // Add-on tanpa sisa stok tidak bisa dicentang, tetapi tetap ditampilkan
    // agar kasir tahu add-on tersebut ada dan sedang habis.
    final isDisabled = remaining <= 0 && !selected;

    return CheckboxListTile(
      dense: true,
      value: selected,
      onChanged: isDisabled ? null : (_) => _toggleAddon(addon),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        addon.name,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDisabled ? colorScheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: Text(
        isDisabled
            ? '${formatRupiah(addon.price)} • stok habis'
            : '${formatRupiah(addon.price)} • sisa stok $remaining',
        style: theme.textTheme.bodySmall?.copyWith(
          color: isDisabled ? colorScheme.error : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
