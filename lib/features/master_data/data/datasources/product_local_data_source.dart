import '../../../../core/database/database_helper.dart';
import '../../../../core/database/db_constants.dart';
import '../models/product_model.dart';

/// Gerbang query tabel `products`.
///
/// Query JOIN ke `categories` dipakai agar daftar produk langsung membawa nama
/// kategorinya. Semua operasi hapus memakai *soft delete* sehingga baris
/// produk tidak pernah hilang dari database.
class ProductLocalDataSource {
  ProductLocalDataSource({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  /// Query dasar produk + nama kategori.
  ///
  /// `p.*` mengambil seluruh kolom produk, sedangkan `category_name` adalah
  /// alias hasil JOIN yang dibaca [ProductModel.fromJoinedMap].
  static const String _selectWithCategory =
      '''
    SELECT p.*, c.${DbColumns.name} AS category_name
    FROM ${DbTables.products} AS p
    INNER JOIN ${DbTables.categories} AS c
      ON c.${DbColumns.id} = p.${DbColumns.categoryId}
  ''';

  /// Mengambil produk yang belum dihapus (katalog aktif).
  Future<List<ProductModel>> getActiveProducts() async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery('''
      $_selectWithCategory
      WHERE p.${DbColumns.isDeleted} = 0
      ORDER BY p.${DbColumns.name} COLLATE NOCASE ASC
      ''');
    return rows.map(ProductModel.fromJoinedMap).toList();
  }

  /// Mencari produk berdasarkan id, termasuk yang sudah soft delete.
  ///
  /// Data soft-deleted tetap dibutuhkan saat proses edit/pengecekan agar
  /// repository bisa membedakan "tidak ada" dan "sudah dihapus".
  Future<ProductModel?> findById(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '$_selectWithCategory WHERE p.${DbColumns.id} = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return null;
    return ProductModel.fromJoinedMap(rows.first);
  }

  /// Menyimpan produk baru dan mengembalikan id AUTOINCREMENT.
  Future<int> insert(ProductModel product) async {
    final db = await _databaseHelper.database;
    return db.insert(DbTables.products, product.toInsertMap());
  }

  /// Mengubah data produk. Nilai balik = jumlah baris terpengaruh.
  Future<int> updateById(int id, Map<String, Object?> values) async {
    final db = await _databaseHelper.database;
    return db.update(
      DbTables.products,
      values,
      where: '${DbColumns.id} = ?',
      whereArgs: [id],
    );
  }

  /// Soft delete: mengubah `is_deleted` menjadi 1 tanpa menghapus baris.
  ///
  /// Nilai balik = jumlah baris terpengaruh, dipakai repository untuk
  /// mendeteksi id yang tidak ada.
  Future<int> softDelete(int id) async {
    final db = await _databaseHelper.database;
    return db.update(
      DbTables.products,
      {DbColumns.isDeleted: 1},
      where: '${DbColumns.id} = ? AND ${DbColumns.isDeleted} = 0',
      whereArgs: [id],
    );
  }
}
