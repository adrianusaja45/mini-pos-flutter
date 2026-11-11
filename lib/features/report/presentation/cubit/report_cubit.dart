import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/report_failure.dart';
import '../../domain/repositories/report_repository.dart';
import 'report_state.dart';

/// Cubit pengelola data halaman Laporan Penjualan.
///
/// Alur data:
/// UI (ReportPage) -> ReportCubit -> ReportRepository -> SQLite.
///
/// Ringkasan dan riwayat dimulai bersamaan (`Future` dibuat lebih dulu, baru
/// di-`await`) agar halaman tidak menunggu dua query secara bergantian.
class ReportCubit extends Cubit<ReportState> {
  ReportCubit(this._repository) : super(const ReportState());

  final ReportRepository _repository;

  /// Memuat ringkasan penjualan + riwayat transaksi.
  ///
  /// Bisa dipanggil ulang dari tombol refresh maupun *pull-to-refresh*.
  /// Permintaan baru diabaikan selama pemuatan berjalan agar query tidak
  /// menumpuk saat kasir menekan tombol berulang.
  Future<void> load() async {
    if (state.isLoading) return;

    emit(state.copyWith(status: ReportStatus.loading, clearFailure: true));

    try {
      // Kedua future dimulai sebelum di-await sehingga query berjalan
      // bersamaan; total waktu tunggu mengikuti query yang paling lambat.
      final summaryFuture = _repository.getSalesSummary();
      final transactionsFuture = _repository.getTransactions();

      final summary = await summaryFuture;
      final transactions = await transactionsFuture;

      emit(
        ReportState(
          status: ReportStatus.ready,
          summary: summary,
          transactions: transactions,
        ),
      );
    } on ReportFailure catch (failure) {
      emit(state.copyWith(status: ReportStatus.failure, failure: failure));
    } catch (_) {
      emit(
        state.copyWith(
          status: ReportStatus.failure,
          failure: const ReportFailure(
            'Gagal memuat laporan penjualan. Silakan coba lagi.',
            type: ReportFailureType.unknown,
          ),
        ),
      );
    }
  }
}
