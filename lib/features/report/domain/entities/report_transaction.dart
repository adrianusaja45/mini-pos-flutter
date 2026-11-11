import 'package:equatable/equatable.dart';

/// Satu baris riwayat transaksi yang tampil di daftar Laporan Penjualan.
///
/// Entity ini hanya memuat kolom header (`transactions`) yang dibutuhkan daftar.
/// Rincian produk/add-on tidak ikut dimuat di sini agar daftar tetap ringan;
/// detail baru dibaca saat kasir membuka struk historis.
class ReportTransaction extends Equatable {
  const ReportTransaction({
    required this.transactionId,
    required this.invoiceNumber,
    required this.cashierName,
    required this.createdAt,
    required this.totalAmount,
  });

  /// Primary key header transaksi; dipakai untuk membuka detail struk.
  final int transactionId;

  /// Nomor nota unik, format `INV-yyyyMMdd-####`.
  final String invoiceNumber;

  /// Nama kasir hasil snapshot saat transaksi terjadi.
  final String cashierName;

  /// Waktu transaksi dalam **UTC** (sesuai penyimpanan database).
  ///
  /// UI wajib memanggil `toLocal()` sebelum memformat, supaya jam yang dilihat
  /// kasir sesuai zona waktu perangkat.
  final DateTime createdAt;

  /// Total tagihan setelah diskon.
  final int totalAmount;

  @override
  List<Object?> get props => [
    transactionId,
    invoiceNumber,
    cashierName,
    createdAt,
    totalAmount,
  ];
}
