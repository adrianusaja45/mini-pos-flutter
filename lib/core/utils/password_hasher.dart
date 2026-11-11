import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Utilitas untuk mengubah PIN/password kasir menjadi hash sebelum disimpan.
///
/// Mengapa PIN tidak disimpan apa adanya?
/// - File database SQLite berada di perangkat dan bisa ikut terekspos saat
///   backup. Jika PIN disimpan sebagai teks asli, siapa pun yang membuka file
///   tersebut langsung bisa login.
/// - Dengan hash SHA-256 + *salt* acak per akun, isi database tidak bisa
///   dipakai untuk menebak PIN asli, dan dua akun dengan PIN sama tetap
///   menghasilkan hash yang berbeda.
///
/// Format hash yang disimpan: `salt:hash`
/// - `salt` = 16 byte acak yang di-encode Base64Url.
/// - `hash` = SHA-256 dari teks `salt:password`.
class PasswordHasher {
  // Kelas utilitas: tidak perlu dibuat menjadi objek.
  const PasswordHasher._();

  /// Panjang salt dalam byte (128 bit, cukup untuk mencegah *rainbow table*).
  static const int _saltLengthInBytes = 16;

  /// Membuat hash baru dari PIN/password yang masih berupa teks asli.
  ///
  /// Salt selalu dibuat baru setiap kali dipanggil, sehingga hash tidak pernah
  /// deterministik antar akun.
  static String hash(String password) {
    final random = Random.secure();
    final saltBytes = List<int>.generate(
      _saltLengthInBytes,
      (_) => random.nextInt(256),
    );
    // Base64Url dipilih karena aman dipakai di dalam string dan tanpa karakter
    // pemisah `:` sehingga mudah dipecah kembali saat verifikasi.
    final salt = base64UrlEncode(saltBytes);
    return '$salt:${_digest(salt, password)}';
  }

  /// Memeriksa apakah [password] yang diketik kasir cocok dengan [storedHash].
  ///
  /// Mengembalikan `false` (bukan melempar error) bila format hash rusak,
  /// supaya proses login tidak macet karena data lama yang tidak valid.
  static bool verify({required String password, required String storedHash}) {
    final separatorIndex = storedHash.indexOf(':');
    if (separatorIndex <= 0 || separatorIndex == storedHash.length - 1) {
      return false;
    }

    final salt = storedHash.substring(0, separatorIndex);
    final expectedHash = storedHash.substring(separatorIndex + 1);
    final actualHash = _digest(salt, password);
    return _constantTimeEquals(actualHash, expectedHash);
  }

  /// Menghitung SHA-256 dari gabungan salt dan password.
  ///
  /// Salt ikut di-hash agar salt yang tersimpan tidak bisa dipakai ulang untuk
  /// menebak password akun lain dengan hash yang sama.
  static String _digest(String salt, String password) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  /// Membandingkan dua hash tanpa berhenti di karakter pertama yang berbeda.
  ///
  /// Tujuannya mengurangi risiko *timing attack* (menebak isi hash berdasarkan
  /// lama proses pembandingan), meskipun risiko ini kecil pada aplikasi lokal.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;

    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }
}
