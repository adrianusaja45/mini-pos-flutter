import 'package:equatable/equatable.dart';

import '../../../pos/domain/entities/transaction_receipt.dart';
import '../../domain/failures/report_failure.dart';

/// Status pemuatan struk historis.
enum ReceiptDetailStatus {
  /// Belum pernah memuat struk.
  initial,

  /// Sedang membaca snapshot transaksi dari SQLite.
  loading,

  /// Struk siap ditampilkan.
  ready,

  /// Pemuatan gagal; pesan ada di [ReceiptDetailState.failure].
  failure,
}

/// State halaman struk historis.
class ReceiptDetailState extends Equatable {
  const ReceiptDetailState({
    this.status = ReceiptDetailStatus.initial,
    this.receipt,
    this.failure,
  });

  final ReceiptDetailStatus status;

  /// Struk yang dibentuk dari snapshot transaksi.
  final TransactionReceipt? receipt;

  final ReportFailure? failure;

  bool get isLoading => status == ReceiptDetailStatus.loading;
  bool get isReady => status == ReceiptDetailStatus.ready && receipt != null;

  ReceiptDetailState copyWith({
    ReceiptDetailStatus? status,
    TransactionReceipt? receipt,
    ReportFailure? failure,
    bool clearFailure = false,
  }) {
    return ReceiptDetailState(
      status: status ?? this.status,
      receipt: receipt ?? this.receipt,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, receipt, failure];
}
