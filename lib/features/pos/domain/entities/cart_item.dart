import 'package:equatable/equatable.dart';

import 'cart_addon.dart';

/// Satu baris item di keranjang kasir.
///
/// Aturan identitas baris (penting untuk *Shared Stock Validation*):
/// - Produk sama + kombinasi add-on **berbeda** => baris terpisah.
///   Contoh: "Kopi Susu" polos dan "Kopi Susu + Extra Shot" adalah 2 baris.
/// - Produk sama + kombinasi add-on **identik** => digabung, `quantity`
///   ditambah. Penggabungan memakai [signature].
///
/// Nama, harga, stok, dan daftar add-on disimpan sebagai snapshot agar isi
/// keranjang stabil selama kasir bekerja, meskipun master data berubah.
class CartItem extends Equatable {
  const CartItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.productStock,
    required this.quantity,
    this.addons = const <CartAddon>[],
    this.imagePath,
  });

  /// Primary key produk asal.
  final int productId;

  /// Nama produk saat dimasukkan ke keranjang.
  final String productName;

  /// Harga produk satuan (tanpa add-on).
  final int unitPrice;

  /// Stok produk saat dimasukkan; batas validasi tombol "+".
  final int productStock;

  /// Jumlah produk pada baris ini.
  final int quantity;

  /// Add-on yang menempel pada baris ini (satu pilihan per add-on).
  final List<CartAddon> addons;

  /// Path foto produk untuk ditampilkan di keranjang.
  final String? imagePath;

  /// Kunci identitas baris: `productId#idAddonTerurut`.
  ///
  /// Add-on diurutkan lebih dulu supaya urutan centang kasir tidak
  /// menghasilkan dua baris berbeda untuk kombinasi yang sebenarnya sama.
  String get signature =>
      buildSignature(productId, addons.map((addon) => addon.addonId));

  /// Membuat signature dari produk dan daftar id add-on.
  ///
  /// `toSet()` dipakai agar add-on yang sama tidak terhitung dua kali bila ada
  /// data yang tidak sengaja duplikat.
  static String buildSignature(int productId, Iterable<int> addonIds) {
    final sortedIds = addonIds.toSet().toList()..sort();
    return '$productId#${sortedIds.join(',')}';
  }

  /// Total harga add-on untuk SATU unit produk pada baris ini.
  int get addonUnitPrice =>
      addons.fold<int>(0, (total, addon) => total + addon.price);

  /// Harga satu unit produk beserta seluruh add-on-nya.
  int get unitPriceWithAddons => unitPrice + addonUnitPrice;

  /// Subtotal baris = harga satu unit lengkap x quantity.
  int get lineTotal => unitPriceWithAddons * quantity;

  /// Teks ringkas add-on untuk ditampilkan di keranjang.
  String get addonSummary {
    if (addons.isEmpty) return 'Tanpa add-on';
    return addons.map((addon) => addon.name).join(', ');
  }

  /// Menyalin baris dengan quantity baru (dipakai saat tombol +/- ditekan).
  CartItem copyWith({int? quantity}) {
    return CartItem(
      productId: productId,
      productName: productName,
      unitPrice: unitPrice,
      productStock: productStock,
      quantity: quantity ?? this.quantity,
      addons: addons,
      imagePath: imagePath,
    );
  }

  @override
  List<Object?> get props => [
    productId,
    productName,
    unitPrice,
    productStock,
    quantity,
    addons,
    imagePath,
  ];
}
