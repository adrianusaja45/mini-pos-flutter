import 'package:equatable/equatable.dart';

import 'user.dart';

/// Data sesi login kasir yang sedang aktif.
///
/// Satu sesi selalu terdiri dari dua informasi:
/// 1. [user] — siapa kasir yang login (id, nama, username). Dipakai halaman
///    POS/struk untuk mencetak nama kasir.
/// 2. [loggedInAt] — kapan sesi dibuat, berguna untuk audit sederhana.
///
/// Sesi disimpan di SQLite agar tetap tersedia setelah aplikasi ditutup
/// (100% offline, tanpa token jaringan).
class AuthSession extends Equatable {
  const AuthSession({required this.user, required this.loggedInAt});

  /// Kasir yang sedang login.
  final User user;

  /// Waktu sesi dimulai.
  final DateTime loggedInAt;

  /// Shortcut agar UI tidak perlu menulis `session.user.name` berulang kali.
  String get cashierName => user.name;

  @override
  List<Object?> get props => [user, loggedInAt];
}
