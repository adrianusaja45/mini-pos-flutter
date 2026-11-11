import 'package:equatable/equatable.dart';

import '../../domain/entities/auth_session.dart';

/// Status sesi login kasir di seluruh aplikasi.
enum SessionStatus {
  /// Sesi sedang dibaca dari SQLite (Splash Screen tampil).
  checking,

  /// Ada sesi tersimpan; aplikasi boleh langsung membuka Home/POS.
  authenticated,

  /// Tidak ada sesi; aplikasi harus menampilkan halaman Login.
  unauthenticated,
}

/// State yang menggambarkan kondisi sesi kasir saat ini.
///
/// Dipakai oleh `AuthGate` untuk memutuskan halaman mana yang tampil:
/// Splash (checking), Home (authenticated), atau Login (unauthenticated).
class SessionState extends Equatable {
  const SessionState({required this.status, this.session});

  /// State awal: sesi belum diketahui.
  const SessionState.checking() : this(status: SessionStatus.checking);

  /// State setelah login berhasil atau sesi lama ditemukan.
  const SessionState.authenticated(AuthSession session)
    : this(status: SessionStatus.authenticated, session: session);

  /// State setelah logout atau ketika sesi tidak ditemukan.
  const SessionState.unauthenticated()
    : this(status: SessionStatus.unauthenticated);

  final SessionStatus status;

  /// Data kasir aktif; hanya terisi saat [status] = authenticated.
  final AuthSession? session;

  bool get isChecking => status == SessionStatus.checking;
  bool get isAuthenticated => status == SessionStatus.authenticated;

  @override
  List<Object?> get props => [status, session];
}
