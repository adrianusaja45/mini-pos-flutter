import 'package:equatable/equatable.dart';

import 'cart_item.dart';
import 'discount_type.dart';

/// Data yang dikirim Cubit ke repository saat kasir mengonfirmasi pembayaran.
///
/// Entity ini hanya membawa **input mentah** dari keranjang: daftar item,
/// pilihan diskon, dan uang tunai yang diterima. Subtotal, nominal diskon,
/// total, serta kembalian sengaja TIDAK dikirim dari UI. Repository menghitung
/// ulang semuanya dari data item, sehingga:
/// - nilai uang tidak bisa dimanipulasi dari layer tampilan,
/// - hanya ada satu sumber kebenaran perhitungan saat data ditulis ke SQLite.
class CheckoutRequest extends Equatable {
  const CheckoutRequest({
    required this.items,
    required this.discountType,
    required this.discountValue,
    required this.cashReceived,
  });

  /// Baris keranjang beserta snapshot nama & harga yang akan disalin ke tabel
  /// detail transaksi.
  final List<CartItem> items;

  /// Jenis diskon yang dipilih kasir.
  final DiscountType discountType;

  /// Nilai diskon sesuai input kasir: Rupiah (nominal) atau 0-100 (persentase).
  final int discountValue;

  /// Uang tunai yang diserahkan pembeli.
  final int cashReceived;

  @override
  List<Object?> get props => [
    items,
    discountType,
    discountValue,
    cashReceived,
  ];
}
