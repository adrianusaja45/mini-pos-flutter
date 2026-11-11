import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/checkout_request.dart';
import '../../domain/failures/pos_failure.dart';
import '../../domain/repositories/pos_repository.dart';
import 'cart_state.dart';
import 'checkout_state.dart';

/// Cubit yang mengurus satu proses pembayaran (checkout).
///
/// Tanggung jawabnya sengaja sempit:
/// 1. Memvalidasi input pembayaran terakhir yang belum dicek keranjang
///    (keranjang tidak kosong dan uang tunai cukup).
/// 2. Mengirim [CheckoutRequest] ke repository yang menjalankan
///    `db.transaction` atomik.
/// 3. Menyimpan struk hasil transaksi ke state agar UI dapat menampilkan
///    halaman struk digital.
///
/// Diskon TIDAK divalidasi di sini karena sudah dijaga oleh [CartCubit] dan
/// divalidasi ulang oleh repository. Dengan begitu aturan diskon hanya ditulis
/// sekali (di `DiscountCalculator`) dan tidak ada risiko dua implementasi
/// validasi yang berbeda.
class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(this._repository) : super(const CheckoutState());

  final PosRepository _repository;

  /// Memproses pembayaran tunai.
  ///
  /// [cart] adalah snapshot keranjang saat tombol bayar ditekan, dan
  /// [cashReceived] adalah uang tunai yang diinput kasir.
  Future<void> confirmPayment({
    required CartState cart,
    required int cashReceived,
  }) async {
    // Mencegah pembayaran ganda bila kasir menekan tombol konfirmasi dua kali
    // sebelum proses database selesai.
    if (state.isProcessing) return;

    if (cart.isEmpty) {
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          errorMessage: 'Keranjang masih kosong. Tambahkan produk terlebih '
              'dahulu.',
        ),
      );
      return;
    }

    if (cashReceived < 0) {
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          errorMessage: 'Uang tunai tidak boleh negatif.',
        ),
      );
      return;
    }

    // VALIDASI KUNCI: uang tunai tidak boleh kurang dari total akhir.
    // Perbandingan memakai [CartState.totalAmount] yang sudah dijamin >= 0
    // (subtotal - diskon, dengan diskon dijepit pada 0..subtotal).
    if (cashReceived < cart.totalAmount) {
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          errorMessage: 'Uang tunai ${formatRupiah(cashReceived)} masih kurang '
              'dari total tagihan ${formatRupiah(cart.totalAmount)}.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: CheckoutStatus.processing,
        clearFailure: true,
      ),
    );

    try {
      final receipt = await _repository.checkout(
        CheckoutRequest(
          items: cart.items,
          discountType: cart.discountType,
          discountValue: cart.discountValue,
          cashReceived: cashReceived,
        ),
      );

      emit(CheckoutState(status: CheckoutStatus.success, receipt: receipt));
    } on PosFailure catch (failure) {
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          errorMessage: failure.message,
        ),
      );
    } catch (_) {
      // Kegagalan tak terduga tetap ditampilkan sebagai pesan yang bisa
      // dipahami kasir; repository sudah memastikan database di-rollback.
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          errorMessage: 'Gagal menyimpan transaksi. Silakan coba lagi.',
        ),
      );
    }
  }

  /// Mengembalikan state ke awal (mis. saat halaman pembayaran ditutup).
  void reset() {
    if (state.isIdle) return;
    emit(const CheckoutState());
  }
}
