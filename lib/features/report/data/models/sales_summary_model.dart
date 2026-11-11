import '../../../../core/database/sql_parsers.dart';
import '../../domain/entities/sales_summary.dart';

/// Representasi hasil query agregat ringkasan penjualan.
///
/// Query memakai alias kolom agar hasil agregasi mudah dibaca. Alias tersebut
/// didefinisikan sebagai konstanta di sini supaya penulisan SQL dan pembacaan
/// map tidak pernah berbeda (mengurangi risiko salah ketik).
class SalesSummaryModel {
  const SalesSummaryModel({
    required this.totalRevenue,
    required this.totalTransactions,
  });

  /// Alias SQL untuk `SUM(total_amount)`.
  static const String revenueAlias = 'total_revenue';

  /// Alias SQL untuk `COUNT(*)`.
  static const String transactionCountAlias = 'total_transactions';

  /// Total uang yang diterima dari seluruh transaksi.
  final int totalRevenue;

  /// Banyaknya transaksi sukses.
  final int totalTransactions;

  /// Membaca hasil query agregat SQLite.
  factory SalesSummaryModel.fromMap(Map<String, Object?> map) {
    return SalesSummaryModel(
      // `COALESCE` di query memastikan hasilnya 0 (bukan null) saat tabel
      // transaksi masih kosong; parseInteger tetap dipakai sebagai pengaman.
      totalRevenue: parseInteger(map[revenueAlias]),
      totalTransactions: parseInteger(map[transactionCountAlias]),
    );
  }

  /// Mengubah model data menjadi entity domain yang aman dipakai UI.
  SalesSummary toEntity() {
    return SalesSummary(
      totalRevenue: totalRevenue,
      totalTransactions: totalTransactions,
    );
  }
}
