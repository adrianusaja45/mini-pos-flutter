import '../../domain/entities/product.dart';
import 'model_parsers.dart';

/// Representasi baris tabel `products` (di-JOIN dengan `categories`).
class ProductModel {
  const ProductModel({
    this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.price,
    required this.stock,
    required this.createdAt,
    this.imagePath,
    this.isDeleted = false,
  });

  final int? id;
  final int categoryId;

  /// Nama kategori hasil JOIN; hanya untuk ditampilkan di UI.
  final String categoryName;

  final String name;
  final int price;
  final int stock;

  /// Path permanen foto di Application Documents Directory (boleh null).
  final String? imagePath;

  final bool isDeleted;
  final DateTime createdAt;

  /// Membaca hasil query `SELECT p.*, c.name AS category_name ...`.
  factory ProductModel.fromJoinedMap(Map<String, Object?> map) {
    return ProductModel(
      id: map['id'] == null ? null : parseInteger(map['id']),
      categoryId: parseInteger(map['category_id']),
      categoryName: (map['category_name'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      price: parseInteger(map['price']),
      stock: parseInteger(map['stock']),
      imagePath: map['image_path'] as String?,
      isDeleted: parseBool(map['is_deleted']),
      createdAt: parseUtcDate(map['created_at']),
    );
  }

  /// Mengubah model menjadi entity domain.
  Product toEntity() {
    return Product(
      id: id ?? 0,
      categoryId: categoryId,
      categoryName: categoryName,
      name: name,
      price: price,
      stock: stock,
      imagePath: imagePath,
      isDeleted: isDeleted,
      createdAt: createdAt,
    );
  }

  /// Data untuk INSERT produk baru.
  ///
  /// `is_deleted` selalu 0 karena produk baru pasti aktif. `image_path` diisi
  /// path permanen hasil penyalinan foto (atau null bila tanpa foto).
  Map<String, Object?> toInsertMap() {
    return {
      'category_id': categoryId,
      'name': name,
      'price': price,
      'stock': stock,
      'image_path': imagePath,
      'is_deleted': 0,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  /// Data untuk UPDATE produk.
  ///
  /// `created_at` tidak diubah agar waktu pembuatan tetap tercatat. Kolom
  /// `is_deleted` juga tidak diubah karena penghapusan punya method khusus
  /// (soft delete) agar tidak tercampur dengan proses edit.
  Map<String, Object?> toUpdateMap() {
    return {
      'category_id': categoryId,
      'name': name,
      'price': price,
      'stock': stock,
      'image_path': imagePath,
    };
  }
}
