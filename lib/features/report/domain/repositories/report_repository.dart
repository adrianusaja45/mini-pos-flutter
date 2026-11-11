import '../../../pos/domain/entities/transaction_receipt.dart';
import '../entities/report_transaction.dart';
import '../entities/sales_summary.dart';

/// Kontrak baca data laporan penjualan.
///
/// Layer domain hanya tahu bahwa ringkasan, riwayat, dan struk bisa dibaca.
/// Detail bahwa sumbernya tabel `transactions`, `transaction_items`, dan
/// `transaction_item_addons` di SQLite berada di layer data.
///
/// PENTING: implementasi [getReceipt] WAJIB hanya membaca kolom snapshot.
/// Tidak boleh ada JOIN ke master `products`/`addons`, sehingga perhitungan
/// laporan tidak terpengaruh perubahan harga atau penghapusan master data.
abstract class ReportRepository {
  /// Menghitung total pendapatan dan jumlah transaksi sukses.
  Future<SalesSummary> getSalesSummary();

  /// Mengambil seluruh transaksi, terbaru lebih dulu (`created_at` DESC).
  Future<List<ReportTransaction>> getTransactions();

  /// Membaca satu struk lengkap dari snapshot transaksi.
  ///
  /// Melempar `ReportFailure` bertipe `notFound` bila transaksi tidak ada.
  Future<TransactionReceipt> getReceipt(int transactionId);
}
