import 'package:equatable/equatable.dart';

import '../../domain/entities/cart_item.dart';
import '../../domain/entities/discount_type.dart';
import '../../domain/services/discount_calculator.dart';

/// State keranjang kasir.
///
/// Menyimpan daftar baris item, pilihan diskon, dan pesan kesalahan terakhir.
/// Semua kalkulasi turunan (subtotal, nominal diskon, total akhir) diletakkan
/// di sini agar UI hanya menampilkan angka dan Cubit tetap fokus pada aturan
/// perubahan data.
///
/// PENTING: nilai total akhir tidak pernah disimpan sebagai field terpisah.
/// Nilai tersebut selalu dihitung dari item + diskon, sehingga tidak mungkin
/// ada kondisi state yang "basi" (mis. total lama masih tersimpan setelah item
/// dihapus).
class CartState extends Equatable {
  const CartState({
    this.items = const <CartItem>[],
    this.discountType = DiscountType.none,
    this.discountValue = 0,
    this.errorMessage,
  });

  /// Baris-baris keranjang. Satu baris = satu kombinasi produk + add-on.
  final List<CartItem> items;

  /// Jenis diskon yang sedang dipakai keranjang.
  final DiscountType discountType;

  /// Nilai diskon sesuai input kasir: Rupiah bila [DiscountType.nominal],
  /// atau angka 0-100 bila [DiscountType.percentage].
  final int discountValue;

  /// Pesan kegagalan terakhir (mis. stok tidak cukup / diskon tidak sah).
  ///
  /// Disimpan di state agar panel keranjang dapat menampilkan peringatan
  /// secara langsung. Ini penting pada layar ponsel: keranjang tampil sebagai
  /// bottom sheet, sehingga snackbar di balik sheet tidak akan terlihat.
  final String? errorMessage;

  bool get isEmpty => items.isEmpty;

  /// Jumlah baris (bukan jumlah unit). Dipakai label "n item".
  int get lineCount => items.length;

  /// Total unit fisik yang akan diambil dari stok produk.
  int get totalQuantity =>
      items.fold<int>(0, (total, item) => total + item.quantity);

  /// Total belanja sebelum diskon.
  int get subtotal =>
      items.fold<int>(0, (total, item) => total + item.lineTotal);

  /// Nominal diskon yang BENAR-BENAR dipotong (Rupiah).
  ///
  /// Dihitung lewat [DiscountCalculator] agar hasilnya identik dengan angka
  /// yang nanti disimpan repository. Nominal selalu dijepit pada rentang
  /// `0..subtotal`, sehingga [totalAmount] tidak pernah minus walaupun kasir
  /// lebih dulu memberi diskon nominal besar lalu menghapus sebagian item.
  int get discountAmount => DiscountCalculator.amount(
    subtotal: subtotal,
    type: discountType,
    value: discountValue,
  );

  /// Total akhir yang harus dibayar pembeli. Dijamin `>= 0`.
  int get totalAmount => DiscountCalculator.total(
    subtotal: subtotal,
    type: discountType,
    value: discountValue,
  );

  /// `true` bila transaksi memakai diskon yang benar-benar memotong harga.
  bool get hasDiscount =>
      discountType != DiscountType.none && discountValue > 0 && subtotal > 0;

  /// `true` bila diskon nominal yang diinput melebihi subtotal saat ini.
  ///
  /// Kondisi ini bisa terjadi bila kasir menerapkan diskon lebih dulu, lalu
  /// mengurangi quantity/ menghapus item. Pemotongan otomatis (clamping)
  /// menjaga total tetap aman; UI memakai flag ini untuk menampilkan catatan
  /// agar kasir tahu nominal diskonnya ikut menyesuaikan.
  bool get isDiscountClamped =>
      hasDiscount &&
      discountType == DiscountType.nominal &&
      discountValue > subtotal;

  /// Teks ringkas diskon untuk panel keranjang, mis. "10%".
  String get discountLabel {
    switch (discountType) {
      case DiscountType.none:
        return '-';
      case DiscountType.nominal:
        return 'Nominal';
      case DiscountType.percentage:
        return '$discountValue%';
    }
  }

  /// Total pemakaian stok sebuah produk dari SELURUH baris keranjang.
  ///
  /// Inilah inti *Shared Stock Validation*: semua baris dengan `productId`
  /// sama dijumlahkan, walaupun add-on tiap baris berbeda. Contoh: satu baris
  /// "Kopi Susu" qty 1 dan satu baris "Kopi Susu + Extra Shot" qty 2 berarti
  /// produk Kopi Susu terpakai 3 unit.
  int productUsage(int productId) {
    var total = 0;
    for (final item in items) {
      if (item.productId == productId) {
        total += item.quantity;
      }
    }
    return total;
  }

  /// Total pemakaian stok sebuah add-on dari SELURUH baris keranjang.
  ///
  /// Satu unit baris keranjang memakai satu unit setiap add-on yang menempel.
  /// Jadi baris "Kopi + Extra Shot" qty 2 memakai 2 stok Extra Shot, berapa pun
  /// produk yang memakainya.
  int addonUsage(int addonId) {
    var total = 0;
    for (final item in items) {
      for (final addon in item.addons) {
        if (addon.addonId == addonId) {
          total += item.quantity;
        }
      }
    }
    return total;
  }

  /// Mencari baris berdasarkan signature kombinasi produk + add-on.
  CartItem? findBySignature(String signature) {
    for (final item in items) {
      if (item.signature == signature) return item;
    }
    return null;
  }

  CartState copyWith({
    List<CartItem>? items,
    DiscountType? discountType,
    int? discountValue,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CartState(
      items: items ?? this.items,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    items,
    discountType,
    discountValue,
    errorMessage,
  ];
}
