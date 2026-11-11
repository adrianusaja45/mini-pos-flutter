import '../../../../core/database/db_constants.dart' show DbColumns;
import '../../../../core/database/sql_parsers.dart';
import '../../../pos/domain/entities/discount_type.dart';
import '../../../pos/domain/entities/receipt_addon.dart';
import '../../../pos/domain/entities/receipt_item.dart';
import '../../../pos/domain/entities/transaction_receipt.dart';

/// Kumpulan model pembentuk struk historis dari kolom **snapshot**.
///
/// Model-model ini sengaja tidak memiliki relasi ke master `products`/`addons`.
/// Semua nama dan harga dibaca dari kolom `*_snapshot`, sehingga struk tetap
/// utuh meskipun master data berubah atau dihapus.

/// Header transaksi (`transactions`) yang dibutuhkan struk.
class ReceiptHeaderModel {
  const ReceiptHeaderModel({
    required this.id,
    required this.invoiceNumber,
    required this.cashierName,
    required this.subtotal,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.totalAmount,
    required this.cashReceived,
    required this.changeAmount,
    required this.createdAt,
  });

  final int id;
  final String invoiceNumber;
  final String cashierName;
  final int subtotal;
  final DiscountType discountType;
  final int discountValue;
  final int discountAmount;
  final int totalAmount;
  final int cashReceived;
  final int changeAmount;

  /// Waktu transaksi dalam UTC.
  final DateTime createdAt;

  /// Membaca baris tabel `transactions`.
  factory ReceiptHeaderModel.fromMap(Map<String, Object?> map) {
    return ReceiptHeaderModel(
      id: parseInteger(map[DbColumns.id]),
      invoiceNumber: (map[DbColumns.invoiceNumber] as String?) ?? '-',
      // Nama kasir adalah snapshot: tidak diambil dari tabel users.
      cashierName: (map[DbColumns.cashierName] as String?) ?? '-',
      subtotal: parseInteger(map[DbColumns.subtotal]),
      discountType: DiscountType.fromStorage(
        map[DbColumns.discountType] as String?,
      ),
      discountValue: parseInteger(map[DbColumns.discountValue]),
      discountAmount: parseInteger(map[DbColumns.discountAmount]),
      totalAmount: parseInteger(map[DbColumns.totalAmount]),
      cashReceived: parseInteger(map[DbColumns.cashReceived]),
      changeAmount: parseInteger(map[DbColumns.changeAmount]),
      createdAt: parseUtcDate(map[DbColumns.createdAt]),
    );
  }

  /// Menggabungkan header dengan detail item menjadi [TransactionReceipt].
  ///
  /// Waktu diubah ke zona waktu perangkat (`toLocal()`) agar struk menampilkan
  /// jam yang sama seperti saat transaksi dilakukan.
  TransactionReceipt toReceipt(List<ReceiptItem> items) {
    return TransactionReceipt(
      transactionId: id,
      invoiceNumber: invoiceNumber,
      cashierName: cashierName,
      createdAt: createdAt.toLocal(),
      items: items,
      subtotal: subtotal,
      discountType: discountType,
      discountValue: discountValue,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
      cashReceived: cashReceived,
      changeAmount: changeAmount,
    );
  }
}

/// Satu baris produk (`transaction_items`) berisi snapshot nama & harga.
class ReceiptItemSnapshotModel {
  const ReceiptItemSnapshotModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    required this.lineSubtotal,
  });

  /// Primary key baris; dipakai untuk mencocokkan daftar add-on.
  final int id;

  /// Referensi produk; `null` bila master produk pernah dihapus.
  final int? productId;

  /// Nama produk saat transaksi (snapshot).
  final String productName;

  /// Harga satuan produk saat transaksi (snapshot).
  final int productPrice;

  final int quantity;

  /// Subtotal baris sudah termasuk seluruh add-on.
  final int lineSubtotal;

  /// Membaca baris tabel `transaction_items`.
  factory ReceiptItemSnapshotModel.fromMap(Map<String, Object?> map) {
    return ReceiptItemSnapshotModel(
      id: parseInteger(map[DbColumns.id]),
      // Sengaja boleh null: riwayat tidak boleh error saat master dihapus.
      productId: map[DbColumns.productId] == null
          ? null
          : parseInteger(map[DbColumns.productId]),
      productName: (map[DbColumns.productNameSnapshot] as String?) ?? '-',
      productPrice: parseInteger(map[DbColumns.productPriceSnapshot]),
      quantity: parseInteger(map[DbColumns.quantity], fallback: 1),
      lineSubtotal: parseInteger(map[DbColumns.subtotal]),
    );
  }

  /// Mengubah model menjadi entity struk beserta add-on miliknya.
  ReceiptItem toEntity(List<ReceiptAddon> addons) {
    return ReceiptItem(
      productId: productId,
      productName: productName,
      unitPrice: productPrice,
      quantity: quantity,
      lineSubtotal: lineSubtotal,
      addons: addons,
    );
  }
}

/// Satu baris add-on (`transaction_item_addons`) berisi snapshot nama & harga.
class ReceiptAddonSnapshotModel {
  const ReceiptAddonSnapshotModel({
    required this.transactionItemId,
    required this.addonId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  /// Baris produk pemilik add-on ini; dipakai saat mengelompokkan.
  final int transactionItemId;

  /// Referensi master add-on; `null` bila pernah dihapus.
  final int? addonId;

  /// Nama add-on saat transaksi (snapshot).
  final String name;

  /// Harga satuan add-on saat transaksi (snapshot).
  final int price;

  final int quantity;

  /// Membaca baris tabel `transaction_item_addons`.
  factory ReceiptAddonSnapshotModel.fromMap(Map<String, Object?> map) {
    return ReceiptAddonSnapshotModel(
      transactionItemId: parseInteger(map[DbColumns.transactionItemId]),
      addonId: map[DbColumns.addonId] == null
          ? null
          : parseInteger(map[DbColumns.addonId]),
      name: (map[DbColumns.addonNameSnapshot] as String?) ?? '-',
      price: parseInteger(map[DbColumns.addonPriceSnapshot]),
      quantity: parseInteger(map[DbColumns.quantity], fallback: 1),
    );
  }

  /// Mengubah model menjadi entity add-on struk.
  ReceiptAddon toEntity() {
    return ReceiptAddon(
      addonId: addonId,
      name: name,
      price: price,
      quantity: quantity,
    );
  }
}

/// Gabungan seluruh baris yang membentuk satu struk historis.
///
/// Detail add-on disimpan sebagai list datar lalu dikelompokkan berdasarkan
/// `transaction_item_id` di repository. Pendekatan ini menghindari query
/// tambahan per item (N+1 query) saat struk berisi banyak produk.
class ReceiptSnapshot {
  const ReceiptSnapshot({
    required this.header,
    required this.items,
    required this.addons,
  });

  final ReceiptHeaderModel header;
  final List<ReceiptItemSnapshotModel> items;
  final List<ReceiptAddonSnapshotModel> addons;
}
