import 'package:equatable/equatable.dart';

/// Ringkasan penjualan yang tampil di bagian atas halaman Laporan.
///
/// Seluruh angka dihitung dari tabel `transactions`, sehingga ringkasan selalu
/// konsisten dengan riwayat transaksi yang ditampilkan di bawahnya.
class SalesSummary extends Equatable {
  const SalesSummary({this.totalRevenue = 0, this.totalTransactions = 0});

  /// Total pendapatan (Revenue) = jumlah `total_amount` seluruh transaksi.
  ///
  /// Memakai `total_amount` (setelah diskon), bukan `subtotal`, karena itulah
  /// uang yang benar-benar diterima toko.
  final int totalRevenue;

  /// Jumlah transaksi yang berhasil tersimpan.
  ///
  /// Aplikasi tidak pernah menyimpan transaksi gagal: checkout berjalan dalam
  /// satu `db.transaction`, sehingga setiap baris di tabel `transactions`
  /// pasti transaksi sukses.
  final int totalTransactions;

  /// `true` bila belum ada transaksi sama sekali.
  bool get isEmpty => totalTransactions == 0;

  @override
  List<Object?> get props => [totalRevenue, totalTransactions];
}
