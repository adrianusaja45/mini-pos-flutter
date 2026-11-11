import 'package:equatable/equatable.dart';

import '../../domain/entities/user.dart';

/// Tahapan proses pendaftaran akun kasir.
enum RegisterStatus {
  /// Form siap diisi.
  idle,

  /// Sedang menyimpan akun ke SQLite.
  submitting,

  /// Akun berhasil dibuat; UI kembali ke halaman Login.
  success,

  /// Pendaftaran gagal (validasi atau username duplikat).
  failure,
}

/// State untuk form Register.
class RegisterState extends Equatable {
  const RegisterState({
    this.status = RegisterStatus.idle,
    this.errorMessage,
    this.registeredUser,
  });

  final RegisterStatus status;

  /// Pesan kegagalan yang ditampilkan di atas form.
  final String? errorMessage;

  /// Akun yang baru dibuat; hanya terisi saat [status] = success.
  final User? registeredUser;

  bool get isSubmitting => status == RegisterStatus.submitting;
  bool get isSuccess => status == RegisterStatus.success;
  bool get isFailure => status == RegisterStatus.failure;

  @override
  List<Object?> get props => [status, errorMessage, registeredUser];
}
