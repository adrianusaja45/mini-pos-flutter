import 'package:equatable/equatable.dart';

import '../../domain/entities/pos_addon.dart';
import '../../domain/entities/pos_category.dart';
import '../../domain/entities/pos_product.dart';
import '../../domain/failures/pos_failure.dart';

/// Status pemuatan katalog kasir.
enum PosCatalogStatus {
  /// Belum pernah memuat data.
  initial,

  /// Sedang membaca produk & add-on dari SQLite.
  loading,

  /// Katalog siap dipakai (bisa saja kosong).
  ready,

  /// Pemuatan gagal; pesan ada di [PosCatalogState.failure].
  failure,
}

/// State katalog layar kasir.
class PosCatalogState extends Equatable {
  const PosCatalogState({
    this.status = PosCatalogStatus.initial,
    this.products = const <PosProduct>[],
    this.addons = const <PosAddon>[],
    this.failure,
  });

  final PosCatalogStatus status;

  /// Produk aktif yang tampil di grid katalog.
  final List<PosProduct> products;

  /// Add-on aktif yang bisa dipilih untuk produk mana pun.
  final List<PosAddon> addons;

  final PosFailure? failure;

  /// Daftar kategori untuk chip filter, diurutkan sesuai abjad.
  ///
  /// Kategori diambil dari produk yang termuat, bukan dari tabel kategori.
  /// Tujuannya agar chip hanya berisi kategori yang pasti ada produknya.
  List<PosCategory> get categories {
    final namesByCategory = <int, String>{};
    for (final product in products) {
      namesByCategory[product.categoryId] = product.categoryName;
    }

    final categories = namesByCategory.entries
        .map((entry) => PosCategory(id: entry.key, name: entry.value))
        .toList();

    categories.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return categories;
  }

  /// `true` bila master data memiliki add-on aktif.
  ///
  /// Dipakai UI untuk memutuskan: klik produk langsung masuk keranjang, atau
  /// membuka bottom sheet pemilihan add-on terlebih dahulu.
  bool get hasAddons => addons.isNotEmpty;

  PosCatalogState copyWith({
    PosCatalogStatus? status,
    List<PosProduct>? products,
    List<PosAddon>? addons,
    PosFailure? failure,
    bool clearFailure = false,
  }) {
    return PosCatalogState(
      status: status ?? this.status,
      products: products ?? this.products,
      addons: addons ?? this.addons,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, products, addons, failure];
}
