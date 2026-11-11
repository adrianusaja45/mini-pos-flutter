import 'package:equatable/equatable.dart';

import '../../domain/entities/report_transaction.dart';
import '../../domain/entities/sales_summary.dart';
import '../../domain/failures/report_failure.dart';

/// Status pemuatan halaman Laporan Penjualan.
///
/// Ringkasan dan riwayat dimuat bersamaan, sehingga satu status cukup untuk
/// mewakili keduanya: layar menampilkan spinner sampai dua-duanya siap.
enum ReportStatus {
  /// Belum pernah memuat data.
  initial,

  /// Sedang membaca ringkasan & riwayat dari SQLite.
  loading,

  /// Data siap ditampilkan (bisa saja belum ada transaksi).
  ready,

  /// Pemuatan gagal; pesan ada di [ReportState.failure].
  failure,
}

/// State halaman Laporan Penjualan.
class ReportState extends Equatable {
  const ReportState({
    this.status = ReportStatus.initial,
    this.summary = const SalesSummary(),
    this.transactions = const <ReportTransaction>[],
    this.failure,
  });

  final ReportStatus status;

  /// Total pendapatan & jumlah transaksi.
  final SalesSummary summary;

  /// Riwayat transaksi terbaru lebih dulu.
  final List<ReportTransaction> transactions;

  final ReportFailure? failure;

  bool get isLoading => status == ReportStatus.loading;

  /// `true` bila belum ada satu pun transaksi di perangkat ini.
  bool get isEmpty => status == ReportStatus.ready && transactions.isEmpty;

  ReportState copyWith({
    ReportStatus? status,
    SalesSummary? summary,
    List<ReportTransaction>? transactions,
    ReportFailure? failure,
    bool clearFailure = false,
  }) {
    return ReportState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      transactions: transactions ?? this.transactions,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, summary, transactions, failure];
}
