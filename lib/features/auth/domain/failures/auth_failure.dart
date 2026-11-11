/// Kesalahan bisnis pada fitur autentikasi.
///
/// Dibuat sebagai exception khusus (bukan `Exception` biasa) agar Cubit dapat
/// membedakan:
/// - kesalahan yang **bisa dijelaskan ke kasir** (misal "Username sudah
///   dipakai"), dan
/// - kesalahan teknis tak terduga (misal database gagal dibuka).
///
/// Pesan di [message] sudah berbahasa Indonesia dan siap ditampilkan di UI.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  /// Pesan ramah pengguna yang boleh ditampilkan di layar.
  final String message;

  @override
  String toString() => 'AuthFailure: $message';
}
