import 'package:equatable/equatable.dart';

import 'receipt_addon.dart';

/// Satu baris produk pada struk digital.
///
/// Nama dan harga di sini adalah **snapshot** saat transaksi, sehingga struk
/// tidak ikut berubah bila harga master produk diperbarui kemudian.
class ReceiptItem extends Equatable {
  const ReceiptItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.lineSubtotal,
    this.addons = const <ReceiptAddon>[],
  });

  /// Id produk asal saat transaksi.
  ///
  /// Nilainya boleh `null` karena kolom `transaction_items.product_id` memakai
  /// `ON DELETE SET NULL`. Saat master produk dihapus, baris riwayat tetap ada
  /// dan struk tetap tampil memakai kolom snapshot di bawah. Artinya struk
  /// historis TIDAK bergantung pada master produk.
  final int? productId;

  /// Nama produk yang tercetak di struk.
  final String productName;

  /// Harga satuan produk tanpa add-on (snapshot).
  final int unitPrice;

  /// Jumlah produk yang dibeli.
  final int quantity;

  /// Subtotal baris = (harga produk + seluruh harga add-on) x quantity.
  final int lineSubtotal;

  /// Add-on yang menempel pada baris ini.
  final List<ReceiptAddon> addons;

  /// Total harga add-on untuk satu unit produk.
  int get addonUnitPrice =>
      addons.fold<int>(0, (total, addon) => total + addon.price);

  @override
  List<Object?> get props => [
    productId,
    productName,
    unitPrice,
    quantity,
    lineSubtotal,
    addons,
  ];
}
