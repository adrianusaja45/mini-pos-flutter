import 'package:equatable/equatable.dart';

/// Jenis kegagalan fitur master data.
///
/// UI memakai jenis ini untuk menentukan cara menampilkan pesan:
/// - [duplicateName] dan [validation] cukup ditampilkan di form/banner.
/// - [categoryInUse] ditampilkan sebagai dialog khusus karena kasir perlu
///   tindakan lanjutan (memindahkan produk ke kategori lain).
enum MasterDataFailureType {
  /// Input tidak lolos aturan validasi (kosong, negatif, dsb.).
  validation,

  /// Nama kategori/add-on sudah dipakai data lain.
  duplicateName,

  /// Kategori tidak boleh dihapus karena masih dirujuk produk (RESTRICT).
  categoryInUse,

  /// Data yang akan diubah/dihapus sudah tidak ada.
  notFound,

  /// Kegagalan teknis lain (I/O foto, database, dsb.).
  unknown,
}

/// Kesalahan bisnis yang pesannya sudah ramah pengguna (Bahasa Indonesia).
///
/// Dibuat sebagai exception sekaligus [Equatable] agar Cubit dapat menyimpan
/// objek kegagalan di dalam state dan UI cukup membandingkan nilainya.
class MasterDataFailure extends Equatable implements Exception {
  const MasterDataFailure(
    this.message, {
    this.type = MasterDataFailureType.unknown,
  });

  /// Pesan siap tampil di UI.
  final String message;

  /// Jenis kegagalan untuk menentukan tampilan (snackbar/dialog).
  final MasterDataFailureType type;

  @override
  List<Object?> get props => [message, type];

  @override
  String toString() => 'MasterDataFailure($type): $message';
}
