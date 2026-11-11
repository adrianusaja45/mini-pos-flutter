import 'package:equatable/equatable.dart';

/// Salinan (snapshot) satu add-on yang menempel pada baris keranjang.
///
/// Mengapa memakai snapshot, bukan hanya id?
/// - Nama dan harga disalin saat kasir memilih add-on, sehingga bila master
///   add-on diubah dari halaman lain, isi keranjang yang sedang berjalan tidak
///   tiba-tiba berubah harga.
/// - `stock` ikut disalin agar tombol "+" di keranjang tetap bisa memvalidasi
///   stok tanpa perlu query ulang ke database.
class CartAddon extends Equatable {
  const CartAddon({
    required this.addonId,
    required this.name,
    required this.price,
    required this.stock,
  });

  /// Primary key add-on asal.
  final int addonId;

  /// Nama add-on saat dimasukkan ke keranjang.
  final String name;

  /// Harga add-on saat dimasukkan ke keranjang.
  final int price;

  /// Stok add-on saat keranjang diisi; dipakai sebagai batas validasi.
  final int stock;

  @override
  List<Object?> get props => [addonId, name, price, stock];
}
