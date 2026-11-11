import '../../../../core/database/db_constants.dart';
import '../../../../core/database/sql_parsers.dart';
import '../../domain/entities/report_transaction.dart';

/// Representasi satu baris header `transactions` untuk daftar riwayat.
///
/// Hanya kolom yang tampil di daftar yang dibaca. Detail produk/add-on tidak
/// ikut dimuat agar daftar laporan tetap cepat walau transaksi sudah banyak.
class ReportTransactionModel {
  const ReportTransactionModel({
    required this.id,
    required this.invoiceNumber,
    required this.cashierName,
    required this.totalAmount,
    required this.createdAt,
  });

  final int id;
  final String invoiceNumber;
  final String cashierName;
  final int totalAmount;

  /// Waktu transaksi dalam UTC (sesuai isi database).
  final DateTime createdAt;

  /// Membaca hasil query tabel `transactions`.
  factory ReportTransactionModel.fromMap(Map<String, Object?> map) {
    return ReportTransactionModel(
      id: parseInteger(map[DbColumns.id]),
      invoiceNumber: (map[DbColumns.invoiceNumber] as String?) ?? '-',
      cashierName: (map[DbColumns.cashierName] as String?) ?? '-',
      totalAmount: parseInteger(map[DbColumns.totalAmount]),
      createdAt: parseUtcDate(map[DbColumns.createdAt]),
    );
  }

  /// Mengubah model menjadi entity domain.
  ReportTransaction toEntity() {
    return ReportTransaction(
      transactionId: id,
      invoiceNumber: invoiceNumber,
      cashierName: cashierName,
      createdAt: createdAt,
      totalAmount: totalAmount,
    );
  }
}
