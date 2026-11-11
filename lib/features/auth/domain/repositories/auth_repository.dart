import '../entities/auth_session.dart';
import '../entities/user.dart';

/// Kontrak (interface) seluruh operasi autentikasi.
///
/// Layer domain hanya mendefinisikan *apa* yang bisa dilakukan aplikasi,
/// bukan *bagaimana* caranya. Implementasi nyata (SQLite) berada di layer data
/// pada `AuthRepositoryImpl`. Pola ini memudahkan pengujian: Cubit bisa diberi
/// repository palsu tanpa perlu membuka database.
abstract class AuthRepository {
  /// Mengambil sesi kasir yang tersimpan di perangkat.
  ///
  /// Mengembalikan `null` bila belum ada sesi (kasir harus login).
  Future<AuthSession?> getActiveSession();

  /// Mencocokkan username + PIN ke tabel `users`, lalu menyimpan sesi aktif.
  ///
  /// Melempar `AuthFailure` bila kredensial salah.
  Future<AuthSession> login({
    required String username,
    required String password,
  });

  /// Mendaftarkan akun kasir baru ke tabel `users`.
  ///
  /// Melempar `AuthFailure` bila data tidak valid atau username sudah dipakai.
  Future<User> register({
    required String name,
    required String username,
    required String password,
  });

  /// Menghapus sesi aktif sehingga kasir kembali ke halaman login.
  Future<void> logout();

  /// Mengecek ketersediaan username, dipakai untuk menampilkan bantuan
  /// langsung di form register (opsional, pengaman utamanya tetap di [register]).
  Future<bool> isUsernameAvailable(String username);
}
