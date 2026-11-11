import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/report_failure.dart';
import '../../domain/repositories/report_repository.dart';
import 'receipt_detail_state.dart';

/// Cubit pemuat satu struk historis.
///
/// Cubit ini sengaja terpisah dari [ReportCubit] agar daftar laporan tidak ikut
/// dihitung ulang setiap kali kasir membuka satu struk. Data struk dibaca dari
/// snapshot transaksi (bukan master produk), sesuai prinsip immutability.
class ReceiptDetailCubit extends Cubit<ReceiptDetailState> {
  ReceiptDetailCubit(this._repository, this.transactionId)
    : super(const ReceiptDetailState());

  final ReportRepository _repository;

  /// Id header transaksi yang struknya akan dibuka.
  final int transactionId;

  /// Memuat struk dari SQLite.
  Future<void> load() async {
    if (state.isLoading) return;

    emit(
      state.copyWith(status: ReceiptDetailStatus.loading, clearFailure: true),
    );

    try {
      final receipt = await _repository.getReceipt(transactionId);
      emit(
        ReceiptDetailState(status: ReceiptDetailStatus.ready, receipt: receipt),
      );
    } on ReportFailure catch (failure) {
      emit(
        state.copyWith(status: ReceiptDetailStatus.failure, failure: failure),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ReceiptDetailStatus.failure,
          failure: const ReportFailure(
            'Gagal memuat struk transaksi. Silakan coba lagi.',
            type: ReportFailureType.loadReceipt,
          ),
        ),
      );
    }
  }
}
