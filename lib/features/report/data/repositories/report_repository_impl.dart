import '../../../pos/domain/entities/receipt_addon.dart';
import '../../../pos/domain/entities/transaction_receipt.dart';
import '../../domain/entities/report_transaction.dart';
import '../../domain/entities/sales_summary.dart';
import '../../domain/failures/report_failure.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_local_data_source.dart';

/// Implementasi [ReportRepository] berbasis SQLite lokal (100% offline).
///
/// Tugas kelas ini hanya dua:
/// 1. Menerjemahkan model data menjadi entity domain.
/// 2. Mengubah kegagalan teknis SQLite menjadi [ReportFailure] yang pesannya
///    ramah untuk kasir.
///
/// Seluruh aturan "hanya baca snapshot" berada di [ReportLocalDataSource].
class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl({ReportLocalDataSource? localDataSource})
    : _localDataSource = localDataSource ?? ReportLocalDataSource();

  final ReportLocalDataSource _localDataSource;

  /// Membaca total pendapatan & jumlah transaksi.
  @override
  Future<SalesSummary> getSalesSummary() async {
    try {
      final model = await _localDataSource.getSalesSummary();
      return model.toEntity();
    } on ReportFailure {
      rethrow;
    } catch (_) {
      throw const ReportFailure(
        'Gagal menghitung ringkasan penjualan. Silakan coba lagi.',
        type: ReportFailureType.loadSummary,
      );
    }
  }

  /// Membaca seluruh riwayat, terbaru lebih dulu.
  @override
  Future<List<ReportTransaction>> getTransactions() async {
    try {
      final models = await _localDataSource.getTransactions();
      return models.map((model) => model.toEntity()).toList(growable: false);
    } on ReportFailure {
      rethrow;
    } catch (_) {
      throw const ReportFailure(
        'Gagal memuat riwayat transaksi. Silakan coba lagi.',
        type: ReportFailureType.loadHistory,
      );
    }
  }

  /// Membaca satu struk lengkap dari snapshot.
  ///
  /// Alur:
  /// 1. Data source mengambil header, item, dan add-on dari tabel transaksi.
  /// 2. Add-on dikelompokkan per `transaction_item_id` di memori.
  /// 3. Setiap item digabung dengan add-on miliknya, lalu header + item
  ///    dirakit menjadi [TransactionReceipt] yang siap dipakai [ReceiptView].
  ///
  /// Tidak ada pengambilan data dari master `products`/`addons`, sehingga
  /// struk historis tetap utuh meskipun master data berubah.
  @override
  Future<TransactionReceipt> getReceipt(int transactionId) async {
    try {
      final snapshot = await _localDataSource.getReceipt(transactionId);
      if (snapshot == null) {
        throw const ReportFailure(
          'Transaksi tidak ditemukan. Data mungkin sudah tidak tersedia di '
          'perangkat ini.',
          type: ReportFailureType.notFound,
        );
      }

      // Kelompokkan add-on berdasarkan baris produk pemiliknya. List datar dari
      // database diubah menjadi struktur bersarang agar sesuai entity struk.
      final addonsByItemId = <int, List<ReceiptAddon>>{};
      for (final addon in snapshot.addons) {
        addonsByItemId
            .putIfAbsent(addon.transactionItemId, () => <ReceiptAddon>[])
            .add(addon.toEntity());
      }

      final items = snapshot.items
          .map(
            (item) => item.toEntity(
              addonsByItemId[item.id] ?? const <ReceiptAddon>[],
            ),
          )
          .toList(growable: false);

      return snapshot.header.toReceipt(items);
    } on ReportFailure {
      rethrow;
    } catch (_) {
      throw const ReportFailure(
        'Gagal memuat struk transaksi. Silakan coba lagi.',
        type: ReportFailureType.loadReceipt,
      );
    }
  }
}
