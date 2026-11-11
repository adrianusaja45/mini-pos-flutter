import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import 'login_state.dart';

/// Cubit yang menjalankan proses login offline.
///
/// Tugasnya hanya meneruskan input form ke repository lalu menerjemahkan
/// hasilnya menjadi state. Semua query SQLite dan verifikasi hash berada di
/// repository, sehingga widget Login tetap ringkas dan mudah dibaca.
class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._repository) : super(const LoginState());

  final AuthRepository _repository;

  /// Mencoba login dengan kredensial yang diketik kasir.
  ///
  /// Alur state: idle/failure -> submitting -> success/failure.
  Future<void> login({
    required String username,
    required String password,
  }) async {
    // Cegah double submit (mis. tombol ditekan dua kali saat proses berjalan).
    if (state.isSubmitting) return;

    emit(const LoginState(status: LoginStatus.submitting));

    try {
      final session = await _repository.login(
        username: username,
        password: password,
      );
      emit(LoginState(status: LoginStatus.success, session: session));
    } on AuthFailure catch (failure) {
      // Pesan dari repository sudah ramah pengguna (mis. kredensial salah).
      emit(
        LoginState(status: LoginStatus.failure, errorMessage: failure.message),
      );
    } catch (_) {
      // Error teknis tak terduga tidak boleh membocorkan detail ke UI.
      emit(
        const LoginState(
          status: LoginStatus.failure,
          errorMessage: 'Terjadi kesalahan saat login. Silakan coba lagi.',
        ),
      );
    }
  }

  /// Menghapus pesan error saat kasir mulai mengetik ulang.
  void clearError() {
    if (state.isFailure) {
      emit(const LoginState());
    }
  }
}
