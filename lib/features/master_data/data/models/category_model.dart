import '../../domain/entities/category.dart';
import '../../../../core/database/sql_parsers.dart';

/// Representasi baris tabel `categories` di layer data.
///
/// Model memisahkan detail database (nama kolom, hasil JOIN) dari entity
/// domain. Dengan begitu repository dan UI tidak dipenuhi kode pengambilan
/// kolom.
class CategoryModel {
  const CategoryModel({
    this.id,
    required this.name,
    required this.createdAt,
    this.productCount = 0,
  });

  /// `null` saat kategori belum di-insert (SQLite yang menentukan id).
  final int? id;

  final String name;

  final DateTime createdAt;

  /// Hasil sub-query COUNT produk aktif pada kategori ini.
  final int productCount;

  /// Membaca satu baris hasil query kategori.
  factory CategoryModel.fromMap(Map<String, Object?> map) {
    return CategoryModel(
      id: map['id'] == null ? null : parseInteger(map['id']),
      name: (map['name'] as String?) ?? '',
      createdAt: parseUtcDate(map['created_at']),
      productCount: parseInteger(map['product_count']),
    );
  }

  /// Mengubah model menjadi entity domain.
  Category toEntity() {
    return Category(
      id: id ?? 0,
      name: name,
      createdAt: createdAt,
      productCount: productCount,
    );
  }

  /// Data untuk `insert()`. `id` dan `product_count` tidak dikirim karena
  /// id dibuat otomatis oleh SQLite dan product_count hanya hasil hitungan.
  Map<String, Object?> toInsertMap() {
    return {'name': name, 'created_at': createdAt.toUtc().toIso8601String()};
  }
}
