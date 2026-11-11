import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/validators/auth_validators.dart';
import 'register_state.dart';

/// Cubit yang menjalankan pendaftaran akun kasir baru.
///
/// Alur state: idle/failure -> submitting -> success/failure.
/// Setelah sukses, halaman Register ditutup dan username dikirim balik ke
/// Login agar kasir tidak perlu mengetik ulang.
class RegisterCubit extends Cubit<RegisterState> {
  RegisterCubit(this._repository) : super(const RegisterState());

  final AuthRepository _repository;

  /// Mendaftarkan akun baru berdasarkan isi form.
  Future<void> register({
    required String name,
    required String username,
    required String password,
    required String confirmPassword,
  }) async {
    if (state.isSubmitting) return;

    // Validasi konfirmasi PIN dilakukan di Cubit (bukan hanya di widget) agar
    // aturan ini tetap berlaku bila form dipanggil dari tempat lain.
    final confirmationError = AuthValidators.validatePasswordConfirmation(
      confirmPassword,
      password: password,
    );
    if (confirmationError != null) {
      emit(
        RegisterState(
          status: RegisterStatus.failure,
          errorMessage: confirmationError,
        ),
      );
      return;
    }

    emit(const RegisterState(status: RegisterStatus.submitting));

    try {
      final user = await _repository.register(
        name: name,
        username: username,
        password: password,
      );
      emit(RegisterState(status: RegisterStatus.success, registeredUser: user));
    } on AuthFailure catch (failure) {
      emit(
        RegisterState(
          status: RegisterStatus.failure,
          errorMessage: failure.message,
        ),
      );
    } catch (_) {
      emit(
        const RegisterState(
          status: RegisterStatus.failure,
          errorMessage:
              'Terjadi kesalahan saat menyimpan akun. Silakan coba lagi.',
        ),
      );
    }
  }

  /// Menghapus pesan error agar form bersih saat kasir memperbaiki input.
  void clearError() {
    if (state.isFailure) {
      emit(const RegisterState());
    }
  }
}
