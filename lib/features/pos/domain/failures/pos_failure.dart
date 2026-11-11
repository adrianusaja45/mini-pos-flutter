import 'package:equatable/equatable.dart';

/// Jenis kegagalan fitur POS.
///
/// Hanya dibedakan tiga jenis karena layar kasir tidak butuh penanganan
/// serinci master data: hampir semua kegagalan cukup ditampilkan sebagai
/// snackbar singkat agar kasir bisa langsung melanjutkan transaksi.
enum PosFailureType {
  /// Katalog gagal dimuat dari SQLite.
  loadCatalog,

  /// Validasi stok / input keranjang ditolak.
  validation,

  /// Kegagalan teknis lain yang tidak terduga.
  unknown,
}

/// Kesalahan bisnis fitur POS dengan pesan ramah pengguna (Bahasa Indonesia).
class PosFailure extends Equatable implements Exception {
  const PosFailure(this.message, {this.type = PosFailureType.unknown});

  /// Pesan siap tampil di UI.
  final String message;

  /// Jenis kegagalan untuk menentukan cara penanganan.
  final PosFailureType type;

  @override
  List<Object?> get props => [message, type];

  @override
  String toString() => 'PosFailure($type): $message';
}
