import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/database/db_constants.dart';
import '../models/category_model.dart';

/// Gerbang query tabel `categories` (dan hitungan produk terkait).
///
/// Kelas ini murni teknis: tidak tahu aturan bisnis seperti "nama tidak boleh
/// duplikat". Pengecekan aturan dilakukan repository, sehingga SQL di sini
/// tetap sederhana dan mudah diuji.
class CategoryLocalDataSource {
  CategoryLocalDataSource({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  /// Query dasar pengambilan kategori.
  ///
  /// Sub-query `product_count` menghitung produk **aktif** per kategori agar
  /// daftar kategori bisa menampilkan informasi "x produk" tanpa query N+1
  /// (satu query per baris).
  static const String _selectWithProductCount =
      '''
    SELECT
      c.${DbColumns.id} AS ${DbColumns.id},
      c.${DbColumns.name} AS ${DbColumns.name},
      c.${DbColumns.createdAt} AS ${DbColumns.createdAt},
      (
        SELECT COUNT(*)
        FROM ${DbTables.products} AS p
        WHERE p.${DbColumns.categoryId} = c.${DbColumns.id}
          AND p.${DbColumns.isDeleted} = 0
      ) AS product_count
    FROM ${DbTables.categories} AS c
  ''';

  /// Mengambil semua kategori, diurutkan sesuai abjad (tanpa membedakan
  /// huruf besar/kecil) agar mudah dicari kasir.
  Future<List<CategoryModel>> getAll() async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '$_selectWithProductCount ORDER BY c.${DbColumns.name} COLLATE NOCASE ASC',
    );
    return rows.map(CategoryModel.fromMap).toList();
  }

  /// Mencari kategori berdasarkan id. `null` bila tidak ada.
  Future<CategoryModel?> findById(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '$_selectWithProductCount WHERE c.${DbColumns.id} = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return null;
    return CategoryModel.fromMap(rows.first);
  }

  /// Menyimpan kategori baru dan mengembalikan id AUTOINCREMENT.
  Future<int> insert(CategoryModel category) async {
    final db = await _databaseHelper.database;
    return db.insert(DbTables.categories, category.toInsertMap());
  }

  /// Mengubah nama kategori. Nilai balik = jumlah baris yang terpengaruh.
  Future<int> updateName(int id, String name) async {
    final db = await _databaseHelper.database;
    return db.update(
      DbTables.categories,
      {DbColumns.name: name},
      where: '${DbColumns.id} = ?',
      whereArgs: [id],
    );
  }

  /// Menghapus kategori secara fisik. Nilai balik = jumlah baris terhapus.
  ///
  /// Bila masih ada produk yang memakai kategori ini, SQLite akan menolak
  /// karena FOREIGN KEY `ON DELETE RESTRICT`, dan error-nya diterjemahkan
  /// repository menjadi pesan yang ramah pengguna.
  Future<int> deleteById(int id) async {
    final db = await _databaseHelper.database;
    return db.delete(
      DbTables.categories,
      where: '${DbColumns.id} = ?',
      whereArgs: [id],
    );
  }

  /// Mengecek apakah nama kategori sudah dipakai.
  ///
  /// [excludeId] dipakai saat mengedit agar kategori itu sendiri tidak
  /// dianggap duplikat. Kolom `name` memakai `COLLATE NOCASE`, sehingga
  /// "Minuman" dan "minuman" dianggap sama.
  Future<bool> existsByName(String name, {int? excludeId}) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      DbTables.categories,
      columns: [DbColumns.id],
      where: excludeId == null
          ? '${DbColumns.name} = ?'
          : '${DbColumns.name} = ? AND ${DbColumns.id} <> ?',
      whereArgs: excludeId == null ? [name] : [name, excludeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Menghitung produk yang memakai kategori tertentu.
  ///
  /// [onlyActive] = `false` dipakai repository sebelum menghapus kategori,
  /// karena FOREIGN KEY tetap menghitung produk yang sudah di-soft-delete.
  Future<int> countProductsInCategory(
    int categoryId, {
    bool onlyActive = true,
  }) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM ${DbTables.products}
      WHERE ${DbColumns.categoryId} = ?
      ${onlyActive ? 'AND ${DbColumns.isDeleted} = 0' : ''}
      ''',
      [categoryId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
