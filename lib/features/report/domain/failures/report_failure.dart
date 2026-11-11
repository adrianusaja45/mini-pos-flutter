import 'package:equatable/equatable.dart';

/// Jenis kegagalan fitur Laporan Penjualan.
///
/// Semua operasi laporan bersifat baca data lokal, sehingga penanganan di UI
/// cukup menampilkan pesan + tombol "Coba Lagi", kecuali [notFound] yang
/// berarti transaksi sudah tidak ada di database.
enum ReportFailureType {
  /// Ringkasan penjualan gagal dihitung.
  loadSummary,

  /// Daftar riwayat transaksi gagal dibaca.
  loadHistory,

  /// Detail struk historis gagal dibaca.
  loadReceipt,

  /// Transaksi yang diminta tidak ditemukan di database.
  notFound,

  /// Kegagalan teknis lain yang tidak terduga.
  unknown,
}

/// Kesalahan bisnis fitur laporan dengan pesan ramah pengguna (Bahasa Indonesia).
class ReportFailure extends Equatable implements Exception {
  const ReportFailure(this.message, {this.type = ReportFailureType.unknown});

  /// Pesan siap tampil di UI.
  final String message;

  /// Jenis kegagalan untuk menentukan cara penanganan.
  final ReportFailureType type;

  @override
  List<Object?> get props => [message, type];

  @override
  String toString() => 'ReportFailure($type): $message';
}
