import 'package:equatable/equatable.dart';

import 'discount_type.dart';
import 'receipt_item.dart';

/// Data lengkap satu struk digital yang ditampilkan setelah checkout berhasil.
///
/// Entity ini dibentuk dari data yang BARU SAJA ditulis ke database. Karena
/// isinya snapshot, struk bisa ditampilkan berulang kali (mis. pratinjau
/// langsung setelah bayar) tanpa perlu query ulang ke SQLite.
class TransactionReceipt extends Equatable {
  const TransactionReceipt({
    required this.transactionId,
    required this.invoiceNumber,
    required this.cashierName,
    required this.createdAt,
    required this.items,
    required this.subtotal,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.totalAmount,
    required this.cashReceived,
    required this.changeAmount,
  });

  /// Primary key header transaksi di tabel `transactions`.
  final int transactionId;

  /// Nomor nota unik, format `INV-yyyyMMdd-####`.
  final String invoiceNumber;

  /// Nama kasir hasil snapshot dari sesi login saat transaksi.
  final String cashierName;

  /// Waktu transaksi dalam zona waktu perangkat (untuk ditampilkan).
  final DateTime createdAt;

  /// Rincian produk & add-on (snapshot).
  final List<ReceiptItem> items;

  /// Total belanja sebelum diskon.
  final int subtotal;

  /// Jenis diskon yang dipakai.
  final DiscountType discountType;

  /// Nilai diskon sesuai input kasir (Rp atau persen).
  final int discountValue;

  /// Nominal diskon yang benar-benar dipotong (Rupiah).
  final int discountAmount;

  /// Total akhir yang harus dibayar = subtotal - discountAmount.
  final int totalAmount;

  /// Uang tunai yang diterima kasir.
  final int cashReceived;

  /// Kembalian = cashReceived - totalAmount.
  final int changeAmount;

  /// `true` bila transaksi memakai diskon.
  bool get hasDiscount =>
      discountType != DiscountType.none && discountAmount > 0;

  /// Label diskon untuk struk, mis. "Diskon 10%" atau "Diskon".
  String get discountLabel {
    if (discountType == DiscountType.percentage) {
      return 'Diskon $discountValue%';
    }
    return 'Diskon';
  }

  @override
  List<Object?> get props => [
    transactionId,
    invoiceNumber,
    cashierName,
    createdAt,
    items,
    subtotal,
    discountType,
    discountValue,
    discountAmount,
    totalAmount,
    cashReceived,
    changeAmount,
  ];
}
