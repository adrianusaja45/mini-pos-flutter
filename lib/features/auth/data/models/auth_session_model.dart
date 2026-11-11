import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user.dart';
import 'user_model.dart';

/// Representasi baris sesi login (tabel `user_sessions` + data akun).
///
/// Query sesi selalu di-*join* dengan tabel `users`, sehingga model ini
/// menerima satu map gabungan: kolom sesi (`logged_in_at`) dan kolom akun
/// (`id`, `name`, `username`, `created_at`).
class AuthSessionModel {
  const AuthSessionModel({required this.user, required this.loggedInAt});

  /// Akun kasir pemilik sesi.
  final UserModel user;

  /// Waktu sesi dimulai (UTC).
  final DateTime loggedInAt;

  /// Membuat model dari hasil query JOIN sesi + users.
  factory AuthSessionModel.fromJoinedMap(Map<String, Object?> map) {
    return AuthSessionModel(
      user: UserModel.fromMap(map),
      loggedInAt: _parseDate(map['logged_in_at']),
    );
  }

  /// Membuat model dari objek domain (dipakai setelah login berhasil).
  factory AuthSessionModel.fromEntity({
    required User user,
    required DateTime loggedInAt,
  }) {
    return AuthSessionModel(
      user: UserModel(
        id: user.id,
        name: user.name,
        username: user.username,
        createdAt: user.createdAt,
      ),
      loggedInAt: loggedInAt,
    );
  }

  /// Mengubah model menjadi entity domain.
  AuthSession toEntity() {
    return AuthSession(user: user.toEntity(), loggedInAt: loggedInAt);
  }

  /// Data untuk `insert()`/`replace()` tabel `user_sessions`.
  ///
  /// `id` selalu 1 karena tabel dirancang hanya menampung satu sesi aktif.
  Map<String, Object?> toInsertMap() {
    return {
      'id': 1,
      'user_id': user.id,
      'user_name': user.name,
      'username': user.username,
      'logged_in_at': loggedInAt.toUtc().toIso8601String(),
    };
  }

  /// Membaca tanggal ISO-8601 dengan fallback aman.
  static DateTime _parseDate(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
