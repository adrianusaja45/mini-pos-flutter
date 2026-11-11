import '../../domain/entities/addon.dart';
import '../../../../core/database/sql_parsers.dart';

/// Representasi baris tabel `addons` di layer data.
class AddonModel {
  const AddonModel({
    this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.createdAt,
    this.isDeleted = false,
  });

  final int? id;
  final String name;
  final int price;
  final int stock;
  final bool isDeleted;
  final DateTime createdAt;

  /// Membaca hasil query tabel add-on.
  factory AddonModel.fromMap(Map<String, Object?> map) {
    return AddonModel(
      id: map['id'] == null ? null : parseInteger(map['id']),
      name: (map['name'] as String?) ?? '',
      price: parseInteger(map['price']),
      stock: parseInteger(map['stock']),
      isDeleted: parseBool(map['is_deleted']),
      createdAt: parseUtcDate(map['created_at']),
    );
  }

  /// Mengubah model menjadi entity domain.
  Addon toEntity() {
    return Addon(
      id: id ?? 0,
      name: name,
      price: price,
      stock: stock,
      isDeleted: isDeleted,
      createdAt: createdAt,
    );
  }

  /// Data untuk INSERT add-on baru.
  Map<String, Object?> toInsertMap() {
    return {
      'name': name,
      'price': price,
      'stock': stock,
      'is_deleted': 0,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  /// Data untuk UPDATE add-on. `created_at` dan `is_deleted` tidak diubah.
  Map<String, Object?> toUpdateMap() {
    return {'name': name, 'price': price, 'stock': stock};
  }
}
