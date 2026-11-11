import 'package:equatable/equatable.dart';

/// Entitas master produk yang dijual di POS.
///
/// Kolom `imagePath` berisi **path permanen** di Application Documents
/// Directory, bukan path sementara dari kamera/galeri. Path permanen inilah
/// yang disimpan ke SQLite agar foto tetap tampil setelah aplikasi ditutup
/// atau cache sistem dibersihkan.
class Product extends Equatable {
  const Product({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.price,
    required this.stock,
    required this.createdAt,
    this.imagePath,
    this.isDeleted = false,
  });

  /// Primary key dari tabel `products`.
  final int id;

  /// Kategori induk produk.
  final int categoryId;

  /// Nama kategori hasil JOIN, disalin ke entity agar UI tidak perlu query
  /// tambahan hanya untuk menampilkan label kategori.
  final String categoryName;

  /// Nama produk yang tampil di katalog dan dicetak di struk.
  final String name;

  /// Harga jual satuan dalam Rupiah utuh (INTEGER, tanpa sen).
  final int price;

  /// Stok tersedia saat ini.
  final int stock;

  /// Path permanen foto produk di Application Documents Directory.
  /// `null` berarti produk tidak memiliki foto.
  final String? imagePath;

  /// Status soft delete. Produk terhapus tetap tersimpan di database agar
  /// riwayat transaksi lama tidak kehilangan referensi.
  final bool isDeleted;

  /// Waktu produk dibuat (UTC).
  final DateTime createdAt;

  /// Menyalin entity dengan nilai tertentu yang diganti.
  ///
  /// Dipakai halaman form untuk menampilkan pratinjau foto tanpa harus
  /// menyusun ulang seluruh field produk.
  Product copyWith({
    int? categoryId,
    String? categoryName,
    String? name,
    int? price,
    int? stock,
    String? imagePath,
    bool clearImage = false,
    bool? isDeleted,
  }) {
    return Product(
      id: id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    categoryId,
    categoryName,
    name,
    price,
    stock,
    imagePath,
    isDeleted,
    createdAt,
  ];
}
