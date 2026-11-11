import 'package:equatable/equatable.dart';

import 'pos_addon.dart';
import 'pos_product.dart';

/// Hasil pemuatan katalog kasir: produk + add-on dalam satu paket.
///
/// Dibungkus menjadi satu entity agar repository cukup menyediakan satu method
/// `loadCatalog()`. Manfaatnya, layar kasir tidak mungkin menampilkan produk
/// yang sudah ada tetapi daftar add-on-nya belum selesai dimuat.
class PosCatalog extends Equatable {
  const PosCatalog({required this.products, required this.addons});

  /// Produk aktif yang boleh dijual.
  final List<PosProduct> products;

  /// Add-on aktif yang bisa dipilih untuk produk mana pun.
  final List<PosAddon> addons;

  @override
  List<Object?> get props => [products, addons];
}
