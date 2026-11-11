import 'package:sqflite/sqflite.dart';

import '../../../../core/utils/password_hasher.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/validators/auth_validators.dart';
import '../datasources/auth_local_data_source.dart';
import '../models/auth_session_model.dart';
import '../models/user_model.dart';

/// Implementasi nyata [AuthRepository] berbasis SQLite lokal.
///
/// Di sinilah seluruh aturan bisnis autentikasi dijalankan:
/// 1. Normalisasi input (trim + huruf kecil untuk username).
/// 2. Validasi form (tidak boleh kosong, panjang minimal, format username).
/// 3. Cek username duplikat sebelum insert.
/// 4. Hash PIN sebelum disimpan dan verifikasi hash saat login.
/// 5. Menyimpan/menghapus sesi aktif di tabel `user_sessions`.
///
/// Semua operasi 100% offline; tidak ada pemanggilan jaringan.
class AuthRepositoryImpl implements AuthRepository {
  /// [localDataSource] dapat diganti saat pengujian unit.
  AuthRepositoryImpl({AuthLocalDataSource? localDataSource})
    : _localDataSource = localDataSource ?? AuthLocalDataSource();

  final AuthLocalDataSource _localDataSource;

  /// Pesan seragam untuk login gagal.
  ///
  /// Sengaja tidak membedakan "username tidak ditemukan" dan "PIN salah" agar
  /// orang lain tidak bisa menebak username mana yang terdaftar.
  static const String _invalidCredentialsMessage =
      'Username atau PIN/password salah.';

  @override
  Future<AuthSession?> getActiveSession() async {
    // Sesi dibaca dari tabel yang di-JOIN dengan users. Hasil null berarti
    // belum login atau akunnya sudah dihapus.
    final session = await _localDataSource.readActiveSession();
    return session?.toEntity();
  }

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    // 1. Normalisasi input supaya "  Kasir1 " tetap cocok dengan "kasir1".
    final normalizedUsername = AuthValidators.normalizeUsername(username);

    // 2. Validasi ringan: form login tidak perlu aturan panjang minimal
    //    password (akun lama tetap bisa masuk), cukup tidak boleh kosong.
    if (normalizedUsername.isEmpty || password.isEmpty) {
      throw const AuthFailure('Username dan PIN/password wajib diisi.');
    }

    // 3. Cari akun di SQLite.
    final user = await _localDataSource.findUserByUsername(normalizedUsername);
    if (user == null) {
      throw const AuthFailure(_invalidCredentialsMessage);
    }

    // 4. Cocokkan PIN yang diketik dengan hash tersimpan.
    //    Password asli tidak pernah disimpan, jadi perbandingan dilakukan
    //    dengan menghitung ulang hash memakai salt milik akun tersebut.
    final storedHash = user.passwordHash;
    final isValid =
        storedHash != null &&
        PasswordHasher.verify(password: password, storedHash: storedHash);
    if (!isValid) {
      throw const AuthFailure(_invalidCredentialsMessage);
    }

    // 5. Simpan sesi agar Splash Screen berikutnya langsung membuka Home.
    final loggedInAt = DateTime.now().toUtc();
    final sessionModel = AuthSessionModel.fromEntity(
      user: user.toEntity(),
      loggedInAt: loggedInAt,
    );
    await _localDataSource.saveSession(sessionModel);

    return sessionModel.toEntity();
  }

  @override
  Future<User> register({
    required String name,
    required String username,
    required String password,
  }) async {
    // 1. Validasi bisnis (juga dipakai form UI, tetapi diulang di sini agar
    //    pemanggil lain tidak bisa menyimpan data kotor ke database).
    final validationErrors = AuthValidators.validateRegistration(
      name: name,
      username: username,
      password: password,
    );
    if (validationErrors.isNotEmpty) {
      throw AuthFailure(validationErrors.first);
    }

    // 2. Normalisasi sebelum cek duplikat agar "Budi" dan "budi" dianggap sama.
    final normalizedName = name.trim();
    final normalizedUsername = AuthValidators.normalizeUsername(username);

    // 3. Cek duplikat secara eksplisit supaya pesan errornya jelas bagi kasir.
    final existing = await _localDataSource.findUserByUsername(
      normalizedUsername,
    );
    if (existing != null) {
      throw const AuthFailure('Username sudah dipakai, gunakan username lain.');
    }

    // 4. Simpan akun dengan PIN yang sudah di-hash. PIN asli hanya hidup di
    //    memori selama proses ini lalu dibuang.
    final userModel = UserModel(
      name: normalizedName,
      username: normalizedUsername,
      passwordHash: PasswordHasher.hash(password),
      createdAt: DateTime.now().toUtc(),
    );

    try {
      final id = await _localDataSource.insertUser(userModel);
      return UserModel(
        id: id,
        name: userModel.name,
        username: userModel.username,
        createdAt: userModel.createdAt,
      ).toEntity();
    } on DatabaseException catch (error) {
      // Pengaman terakhir: bila dua proses mendaftar bersamaan, constraint
      // UNIQUE di kolom username tetap mencegah data ganda. Error teknis ini
      // diterjemahkan menjadi pesan yang bisa dipahami kasir.
      if (error.isUniqueConstraintError()) {
        throw const AuthFailure(
          'Username sudah dipakai, gunakan username lain.',
        );
      }
      throw const AuthFailure('Gagal menyimpan akun. Silakan coba lagi.');
    }
  }

  @override
  Future<void> logout() async {
    // Menghapus satu-satunya baris sesi. Data akun tetap ada sehingga kasir
    // bisa login kembali kapan saja tanpa jaringan.
    await _localDataSource.deleteSession();
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final normalizedUsername = AuthValidators.normalizeUsername(username);

    // Username yang formatnya tidak valid dianggap tidak tersedia, sehingga
    // UI tidak menampilkan centang hijau untuk input yang salah.
    if (AuthValidators.validateUsername(normalizedUsername) != null) {
      return false;
    }

    final existing = await _localDataSource.findUserByUsername(
      normalizedUsername,
    );
    return existing == null;
  }
}
