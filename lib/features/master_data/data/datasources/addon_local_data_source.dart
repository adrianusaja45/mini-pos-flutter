import '../../../../core/database/database_helper.dart';
import '../../../../core/database/db_constants.dart';
import '../models/addon_model.dart';

/// Gerbang query tabel `addons`.
///
/// Sama seperti produk, penghapusan add-on memakai soft delete agar riwayat
/// transaksi yang memakai add-on tersebut tetap utuh.
class AddonLocalDataSource {
  AddonLocalDataSource({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  /// Mengambil add-on yang masih aktif, diurutkan sesuai abjad.
  Future<List<AddonModel>> getActiveAddons() async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      DbTables.addons,
      where: '${DbColumns.isDeleted} = 0',
      orderBy: '${DbColumns.name} COLLATE NOCASE ASC',
    );
    return rows.map(AddonModel.fromMap).toList();
  }

  /// Mencari add-on berdasarkan id (termasuk yang sudah soft delete).
  Future<AddonModel?> findById(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      DbTables.addons,
      where: '${DbColumns.id} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AddonModel.fromMap(rows.first);
  }

  /// Menyimpan add-on baru dan mengembalikan id AUTOINCREMENT.
  Future<int> insert(AddonModel addon) async {
    final db = await _databaseHelper.database;
    return db.insert(DbTables.addons, addon.toInsertMap());
  }

  /// Mengubah data add-on. Nilai balik = jumlah baris terpengaruh.
  Future<int> updateById(int id, Map<String, Object?> values) async {
    final db = await _databaseHelper.database;
    return db.update(
      DbTables.addons,
      values,
      where: '${DbColumns.id} = ?',
      whereArgs: [id],
    );
  }

  /// Soft delete add-on (`is_deleted = 1`).
  Future<int> softDelete(int id) async {
    final db = await _databaseHelper.database;
    return db.update(
      DbTables.addons,
      {DbColumns.isDeleted: 1},
      where: '${DbColumns.id} = ? AND ${DbColumns.isDeleted} = 0',
      whereArgs: [id],
    );
  }

  /// Mengecek nama add-on yang sudah dipakai.
  ///
  /// [excludeId] dipakai saat edit agar add-on itu sendiri tidak dianggap
  /// duplikat. Kolom `name` memakai `COLLATE NOCASE`.
  Future<bool> existsByName(String name, {int? excludeId}) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      DbTables.addons,
      columns: [DbColumns.id],
      where: excludeId == null
          ? '${DbColumns.name} = ?'
          : '${DbColumns.name} = ? AND ${DbColumns.id} <> ?',
      whereArgs: excludeId == null ? [name] : [name, excludeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}
