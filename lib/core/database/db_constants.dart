/// Kumpulan nama tabel, nama kolom, dan nilai enum yang dipakai di database.
///
/// Tujuannya agar seluruh layer (repository, cubit, dsb.) memakai satu sumber
/// kebenaran. Jika suatu saat nama tabel/kolom berubah, kita hanya perlu
/// mengubahnya di satu tempat ini sehingga risiko *typo* pada string SQL
/// mentah dapat ditekan.
class DbTables {
  // Konstruktor privat: kelas ini hanya berisi konstanta, tidak untuk dibuat
  // menjadi objek.
  const DbTables._();

  /// Menyimpan akun kasir/admin beserta kredensial login.
  static const String users = 'users';

  /// Menyimpan kategori produk (misal: Makanan, Minuman).
  static const String categories = 'categories';

  /// Master data produk yang dijual.
  static const String products = 'products';

  /// Master data add-on (topping/tambahan) yang bisa dipilih pada produk.
  static const String addons = 'addons';

  /// Header transaksi penjualan (satu baris = satu struk).
  static const String transactions = 'transactions';

  /// Detail baris produk di dalam sebuah transaksi.
  static const String transactionItems = 'transaction_items';

  /// Detail add-on yang menempel pada satu baris produk transaksi.
  static const String transactionItemAddons = 'transaction_item_addons';
}

/// Nama kolom yang dipakai bersama oleh lebih dari satu tabel.
///
/// Kolom yang hanya dipakai satu tabel ditulis langsung di SQL agar kode tetap
/// ringkas dan mudah dibaca berurutan dengan definisi tabelnya.
class DbColumns {
  const DbColumns._();

  // Kolom umum
  static const String id = 'id';
  static const String name = 'name';
  static const String createdAt = 'created_at';

  // Produk & add-on
  static const String categoryId = 'category_id';
  static const String price = 'price';
  static const String stock = 'stock';
  static const String imagePath = 'image_path';
  static const String isDeleted = 'is_deleted';

  // Transaksi
  static const String transactionId = 'transaction_id';
  static const String invoiceNumber = 'invoice_number';
  static const String cashierName = 'cashier_name';
  static const String subtotal = 'subtotal';
  static const String discountType = 'discount_type';
  static const String discountValue = 'discount_value';
  static const String discountAmount = 'discount_amount';
  static const String totalAmount = 'total_amount';
  static const String cashReceived = 'cash_received';
  static const String changeAmount = 'change_amount';

  // Detail transaksi (snapshot)
  static const String productId = 'product_id';
  static const String productNameSnapshot = 'product_name_snapshot';
  static const String productPriceSnapshot = 'product_price_snapshot';
  static const String quantity = 'quantity';
  static const String transactionItemId = 'transaction_item_id';
  static const String addonId = 'addon_id';
  static const String addonNameSnapshot = 'addon_name_snapshot';
  static const String addonPriceSnapshot = 'addon_price_snapshot';
}

/// Nilai yang valid untuk kolom `transactions.discount_type`.
///
/// Disimpan sebagai teks (bukan angka) supaya isi database mudah dibaca saat
/// di-*debug* maupun saat membuat laporan manual.
class DiscountType {
  const DiscountType._();

  /// Tanpa diskon.
  static const String none = 'none';

  /// Diskon berupa potongan nominal Rupiah langsung.
  static const String nominal = 'nominal';

  /// Diskon berupa persentase dari subtotal (0 - 100).
  static const String percentage = 'percentage';
}
