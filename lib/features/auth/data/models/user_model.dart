import '../../domain/entities/user.dart';

/// Representasi baris tabel `users` di layer data.
///
/// Mengapa perlu model terpisah dari entity [User]?
/// - Model memuat kolom teknis database seperti `password_hash`, sedangkan
///   entity domain tidak boleh membawa kredensial.
/// - Semua konversi map <-> objek dikumpulkan di sini, sehingga repository
///   tidak dipenuhi kode pengambilan kolom.
class UserModel {
  const UserModel({
    this.id,
    required this.name,
    required this.username,
    this.passwordHash,
    required this.createdAt,
  });

  /// `null` saat akun belum di-insert (SQLite yang menentukan id).
  final int? id;

  /// Nama lengkap kasir.
  final String name;

  /// Username yang sudah dinormalisasi ke huruf kecil.
  final String username;

  /// Hash PIN (`salt:hash`). Hanya diisi saat membaca data login; tidak pernah
  /// diteruskan ke entity/UI.
  final String? passwordHash;

  /// Waktu pembuatan akun (UTC).
  final DateTime createdAt;

  /// Membuat model dari hasil query SQLite.
  factory UserModel.fromMap(Map<String, Object?> map) {
    return UserModel(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      username: (map['username'] as String?) ?? '',
      passwordHash: map['password_hash'] as String?,
      createdAt: _parseDate(map['created_at']),
    );
  }

  /// Mengubah model menjadi entity domain yang aman dipakai UI.
  User toEntity() {
    return User(
      id: id ?? 0,
      name: name,
      username: username,
      createdAt: createdAt,
    );
  }

  /// Data yang dikirim ke `insert()` tabel users.
  Map<String, Object?> toInsertMap() {
    return {
      'name': name,
      'username': username,
      'password_hash': passwordHash,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  /// Membaca tanggal ISO-8601 dengan aman.
  ///
  /// Bila data lama rusak, dipakai waktu epoch agar aplikasi tidak crash saat
  /// membaca tabel.
  static DateTime _parseDate(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
