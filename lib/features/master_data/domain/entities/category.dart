import 'package:equatable/equatable.dart';

/// Entitas kategori produk pada layer domain.
///
/// Entitas ini hanya memuat data yang dibutuhkan UI. Detail teknis seperti
/// nama tabel/kolom tetap berada di layer data (model & data source).
class Category extends Equatable {
  const Category({
    required this.id,
    required this.name,
    required this.createdAt,
    this.productCount = 0,
  });

  /// Primary key dari tabel `categories`.
  final int id;

  /// Nama kategori yang tampil di form produk dan filter katalog.
  final String name;

  /// Waktu kategori dibuat (UTC).
  final DateTime createdAt;

  /// Jumlah produk **aktif** yang memakai kategori ini.
  ///
  /// Nilainya berasal dari sub-query COUNT di layer data. Dipakai UI untuk
  /// memberi informasi cepat sebelum kasir menghapus kategori. Perlu diingat,
  /// produk yang sudah di-soft-delete tetap terhitung oleh FOREIGN KEY
  /// `ON DELETE RESTRICT`, sehingga repository tetap mengecek jumlah total
  /// produk (bukan hanya yang aktif) saat proses hapus.
  final int productCount;

  @override
  List<Object?> get props => [id, name, createdAt, productCount];
}
