import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import 'session_state.dart';

/// Cubit yang mengatur siklus hidup sesi login kasir.
///
/// Alur:
/// 1. [checkSession] dipanggil saat aplikasi start -> membaca `user_sessions`
///    melalui repository. Inilah logika di balik Splash Screen.
/// 2. [onLoginSuccess] dipanggil setelah LoginCubit berhasil login. Sesi sudah
///    disimpan repository, jadi di sini cukup memberi tahu UI.
/// 3. [logout] menghapus sesi di SQLite lalu mengembalikan aplikasi ke Login.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._repository) : super(const SessionState.checking());

  final AuthRepository _repository;

  /// Mengecek apakah masih ada sesi login tersimpan.
  ///
  /// Jika pembacaan database gagal (mis. file korup), aplikasi tidak boleh
  /// macet di Splash. Karena itu error diperlakukan sebagai "belum login"
  /// sehingga kasir tetap bisa masuk lewat form Login.
  Future<void> checkSession() async {
    emit(const SessionState.checking());
    try {
      final session = await _repository.getActiveSession();
      if (session == null) {
        emit(const SessionState.unauthenticated());
        return;
      }
      emit(SessionState.authenticated(session));
    } catch (_) {
      emit(const SessionState.unauthenticated());
    }
  }

  /// Menandai sesi sebagai aktif tanpa query ulang ke SQLite.
  ///
  /// Repository login sudah menyimpan sesi; memanggil ini hanya memperbarui
  /// state agar `AuthGate` langsung berpindah ke Home.
  void onLoginSuccess(AuthSession session) {
    emit(SessionState.authenticated(session));
  }

  /// Logout lokal: hapus baris sesi di SQLite lalu tampilkan Login.
  Future<void> logout() async {
    try {
      await _repository.logout();
    } finally {
      // Apa pun hasil penghapusan, UI tetap dikembalikan ke Login agar kasir
      // tidak terjebak di Home dengan sesi yang seharusnya sudah berakhir.
      emit(const SessionState.unauthenticated());
    }
  }
}
