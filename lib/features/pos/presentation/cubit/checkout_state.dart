import 'package:equatable/equatable.dart';

import '../../domain/entities/transaction_receipt.dart';

/// Status proses pembayaran di halaman Checkout.
enum CheckoutStatus {
  /// Belum ada permintaan pembayaran.
  idle,

  /// Sedang menyimpan transaksi atomik ke SQLite.
  processing,

  /// Transaksi berhasil; [CheckoutState.receipt] berisi struk digital.
  success,

  /// Transaksi gagal; [CheckoutState.errorMessage] berisi alasannya.
  failure,
}

/// State halaman pembayaran.
///
/// Menyimpan status proses dan struk hasil transaksi. Setelah [success], UI
/// langsung diarahkan ke halaman struk memakai data [receipt] yang berasal dari
/// database, bukan dari keranjang yang mungkin sudah dikosongkan.
class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.idle,
    this.receipt,
    this.errorMessage,
  });

  final CheckoutStatus status;

  /// Struk transaksi yang baru berhasil disimpan.
  final TransactionReceipt? receipt;

  /// Pesan kegagalan yang siap ditampilkan (mis. uang tunai kurang).
  final String? errorMessage;

  bool get isIdle => status == CheckoutStatus.idle;
  bool get isProcessing => status == CheckoutStatus.processing;
  bool get isSuccess => status == CheckoutStatus.success;
  bool get isFailure => status == CheckoutStatus.failure;

  CheckoutState copyWith({
    CheckoutStatus? status,
    TransactionReceipt? receipt,
    String? errorMessage,
    bool clearFailure = false,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      receipt: receipt ?? this.receipt,
      errorMessage: clearFailure ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, receipt, errorMessage];
}
