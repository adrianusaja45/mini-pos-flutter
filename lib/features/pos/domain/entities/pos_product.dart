import 'package:equatable/equatable.dart';

/// Produk dalam bentuk yang dipakai layar kasir (POS).
///
/// Mengapa dipisahkan dari `Product` milik fitur master data?
/// - Fitur POS hanya membutuhkan data yang tampil di katalog (nama, harga,
///   stok, foto, kategori) sehingga entity-nya bisa lebih ringkas.
/// - Dengan entity sendiri, layar kasir tidak ikut berubah bila suatu saat
///   master data menambah kolom internal baru.
///
/// Nilai `stock` di sini adalah **stok di database saat katalog dimuat**.
/// Stok yang benar-benar bisa dipakai kasir dihitung ulang di keranjang
/// (stok database dikurangi akumulasi pemakaian di keranjang).
class PosProduct extends Equatable {
  const PosProduct({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.price,
    required this.stock,
    this.imagePath,
  });

  /// Primary key tabel `products`.
  final int id;

  /// Kategori induk; dipakai untuk filter cepat per kategori.
  final int categoryId;

  /// Nama kategori hasil JOIN di layer data.
  final String categoryName;

  /// Nama produk yang tampil di kartu katalog.
  final String name;

  /// Harga jual satuan dalam Rupiah utuh.
  final int price;

  /// Stok tersedia di database (belum dikurangi isi keranjang).
  final int stock;

  /// Path permanen foto produk, `null` bila produk tidak memiliki foto.
  final String? imagePath;

  @override
  List<Object?> get props => [
    id,
    categoryId,
    categoryName,
    name,
    price,
    stock,
    imagePath,
  ];
}
