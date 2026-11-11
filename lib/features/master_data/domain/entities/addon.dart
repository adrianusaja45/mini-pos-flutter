import 'package:equatable/equatable.dart';

/// Entitas master add-on (topping/tambahan) yang bisa dipilih saat transaksi.
///
/// Stok add-on dikelola **terpisah** dari stok produk karena satu add-on bisa
/// menempel pada banyak produk. Contoh: "Extra Keju" memiliki stok sendiri dan
/// berkurang setiap kali terjual, berapa pun produk yang memakainya.
class Addon extends Equatable {
  const Addon({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.createdAt,
    this.isDeleted = false,
  });

  /// Primary key dari tabel `addons`.
  final int id;

  /// Nama add-on yang tampil di katalog dan struk.
  final String name;

  /// Harga tambahan per unit dalam Rupiah utuh (INTEGER, tanpa sen).
  final int price;

  /// Stok add-on yang tersedia.
  final int stock;

  /// Status soft delete; add-on terhapus disembunyikan dari katalog tetapi
  /// barisnya tetap ada demi keutuhan riwayat transaksi.
  final bool isDeleted;

  /// Waktu add-on dibuat (UTC).
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, name, price, stock, isDeleted, createdAt];
}
