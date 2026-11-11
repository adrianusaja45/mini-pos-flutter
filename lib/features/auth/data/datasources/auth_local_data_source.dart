import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/database/db_constants.dart';
import '../models/auth_session_model.dart';
import '../models/user_model.dart';

/// Gerbang tunggal antara repository autentikasi dan SQLite.
///
/// Tugas kelas ini murni teknis: menjalankan query ke tabel `users` dan
/// `user_sessions`. Ia tidak tahu aturan bisnis (misal "username tidak boleh
/// duplikat") maupun hashing; itu tugas repository. Pemisahan ini membuat
/// query mudah dites dan mudah diganti bila suatu saat sumber data berubah.
class AuthLocalDataSource {
  /// [databaseHelper] bisa diisi versi palsu saat pengujian; pada aplikasi
  /// nyata dipakai singleton [DatabaseHelper.instance].
  AuthLocalDataSource({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  /// Mencari akun berdasarkan username (sudah dinormalisasi huruf kecil).
  ///
  /// Mengembalikan `null` bila akun tidak ada. Hash password ikut dibaca di
  /// sini karena hanya repository yang boleh memakainya untuk verifikasi.
  Future<UserModel?> findUserByUsername(String username) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      DbTables.users,
      where: '${DbColumns.username} = ?',
      whereArgs: [username],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  /// Menyimpan akun kasir baru dan mengembalikan id hasil AUTOINCREMENT.
  Future<int> insertUser(UserModel user) async {
    final db = await _databaseHelper.database;
    return db.insert(DbTables.users, user.toInsertMap());
  }

  /// Membaca sesi aktif (baris tunggal) beserta data akunnya.
  ///
  /// JOIN dipakai agar sesi otomatis dianggap tidak ada bila akun kasirnya
  /// sudah dihapus dari tabel `users`.
  Future<AuthSessionModel?> readActiveSession() async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery('''
      SELECT
        s.${DbColumns.loggedInAt} AS ${DbColumns.loggedInAt},
        u.${DbColumns.id} AS ${DbColumns.id},
        u.${DbColumns.name} AS ${DbColumns.name},
        u.${DbColumns.username} AS ${DbColumns.username},
        u.${DbColumns.createdAt} AS ${DbColumns.createdAt}
      FROM ${DbTables.userSessions} AS s
      INNER JOIN ${DbTables.users} AS u
        ON u.${DbColumns.id} = s.${DbColumns.userId}
      WHERE s.${DbColumns.id} = 1
      LIMIT 1
    ''');

    if (rows.isEmpty) return null;
    return AuthSessionModel.fromJoinedMap(rows.first);
  }

  /// Menyimpan sesi kasir yang baru login.
  ///
  /// `ConflictAlgorithm.replace` dipakai karena tabel hanya boleh berisi satu
  /// baris (id = 1): login kasir berikutnya otomatis menimpa sesi sebelumnya.
  Future<void> saveSession(AuthSessionModel session) async {
    final db = await _databaseHelper.database;
    await db.insert(
      DbTables.userSessions,
      session.toInsertMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Menghapus sesi aktif (dipakai saat logout).
  Future<void> deleteSession() async {
    final db = await _databaseHelper.database;
    await db.delete(DbTables.userSessions);
  }
}
