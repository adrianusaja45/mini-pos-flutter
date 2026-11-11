import 'package:equatable/equatable.dart';

/// Add-on yang bisa dipilih kasir saat menambahkan produk ke keranjang.
///
/// Pada skema database aplikasi ini, add-on bersifat **global**: satu add-on
/// dapat ditempelkan ke produk apa pun yang dijual. Karena itu pemilihan
/// add-on di layar kasir cukup memakai daftar add-on aktif dari master data.
class PosAddon extends Equatable {
  const PosAddon({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
  });

  /// Primary key tabel `addons`.
  final int id;

  /// Nama add-on yang tampil di bottom sheet dan ringkasan keranjang.
  final String name;

  /// Harga tambahan per unit (Rupiah utuh).
  final int price;

  /// Stok add-on di database (belum dikurangi isi keranjang).
  final int stock;

  @override
  List<Object?> get props => [id, name, price, stock];
}
