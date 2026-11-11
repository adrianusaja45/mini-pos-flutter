import 'package:equatable/equatable.dart';

/// Entitas akun kasir pada layer domain.
///
/// Entitas ini sengaja **tidak** memiliki field password/hash. Tujuannya agar
/// lapisan UI (Cubit/Widget) secara fisik tidak mungkin membawa kredensial ke
/// luar layer data. Hash password hanya hidup di dalam repository dan data
/// source.
class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.createdAt,
  });

  /// Primary key dari tabel `users`.
  final int id;

  /// Nama lengkap kasir; dipakai sebagai identitas di Home dan nantinya
  /// di-*snapshot* ke `transactions.cashier_name` saat checkout.
  final String name;

  /// Username untuk login (selalu huruf kecil, sudah dinormalisasi).
  final String username;

  /// Waktu akun dibuat.
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, name, username, createdAt];
}
