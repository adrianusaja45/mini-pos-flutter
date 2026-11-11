import 'package:equatable/equatable.dart';

import '../../domain/entities/auth_session.dart';

/// Tahapan proses login yang ditampilkan di form.
enum LoginStatus {
  /// Form siap diisi.
  idle,

  /// Sedang mencocokkan kredensial ke SQLite (tombol dinonaktifkan).
  submitting,

  /// Login berhasil dan sesi sudah tersimpan.
  success,

  /// Login gagal; [LoginState.errorMessage] berisi alasannya.
  failure,
}

/// State untuk form Login.
class LoginState extends Equatable {
  const LoginState({
    this.status = LoginStatus.idle,
    this.errorMessage,
    this.session,
  });

  final LoginStatus status;

  /// Pesan kegagalan yang aman ditampilkan ke kasir.
  final String? errorMessage;

  /// Sesi hasil login; hanya terisi saat [status] = success.
  final AuthSession? session;

  bool get isSubmitting => status == LoginStatus.submitting;
  bool get isSuccess => status == LoginStatus.success;
  bool get isFailure => status == LoginStatus.failure;

  @override
  List<Object?> get props => [status, errorMessage, session];
}
