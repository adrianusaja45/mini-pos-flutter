import 'package:equatable/equatable.dart';

import '../../domain/entities/cart_item.dart';

/// State keranjang kasir.
///
/// Menyimpan daftar baris item sekaligus menyediakan kalkulasi turunan yang
/// dipakai UI (subtotal, jumlah item) dan dipakai validasi stok (pemakaian
/// produk/add-on). Perhitungan diletakkan di state agar Cubit tetap fokus pada
/// aturan perubahan data.
class CartState extends Equatable {
  const CartState({this.items = const <CartItem>[], this.errorMessage});

  /// Baris-baris keranjang. Satu baris = satu kombinasi produk + add-on.
  final List<CartItem> items;

  /// Pesan kegagalan terakhir (mis. stok tidak cukup).
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

  /// Total belanja sebelum diskon (belum termasuk fitur pembayaran).
  int get subtotal =>
      items.fold<int>(0, (total, item) => total + item.lineTotal);

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
    String? errorMessage,
    bool clearError = false,
  }) {
    return CartState(
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [items, errorMessage];
}
