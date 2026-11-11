import '../../../../core/database/database_helper.dart';
import '../../../../core/database/db_constants.dart';
import '../models/receipt_snapshot_models.dart';
import '../models/report_transaction_model.dart';
import '../models/sales_summary_model.dart';

/// Gerbang query SQLite khusus Laporan Penjualan.
///
/// Seluruh query di kelas ini **hanya membaca** tabel transaksi:
/// `transactions`, `transaction_items`, dan `transaction_item_addons`.
///
/// ATURAN PENTING (immutability riwayat):
/// Tidak ada satu pun query yang melakukan JOIN ke `products` atau `addons`.
/// Nama dan harga selalu diambil dari kolom `*_snapshot`, sehingga laporan dan
/// struk historis tidak berubah walaupun master data diedit atau dihapus.
class ReportLocalDataSource {
  ReportLocalDataSource({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  /// Menghitung ringkasan penjualan dari tabel `transactions`.
  ///
  /// Cara kerja query:
  /// - `COUNT(*)` menghitung banyaknya transaksi. Setiap baris di tabel ini
  ///   pasti transaksi sukses karena checkout menyimpan header dan detail
  ///   dalam satu `db.transaction` (gagal di tengah jalan = ROLLBACK total).
  /// - `SUM(total_amount)` menjumlahkan uang yang benar-benar diterima toko.
  ///   Memakai `total_amount` (sudah dipotong diskon), bukan `subtotal`.
  /// - `COALESCE(..., 0)` membuat hasil tetap 0 saat tabel masih kosong,
  ///   sehingga aplikasi tidak perlu menangani nilai NULL.
  Future<SalesSummaryModel> getSalesSummary() async {
    final db = await _databaseHelper.database;

    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS ${SalesSummaryModel.transactionCountAlias},
        COALESCE(
          SUM(${DbColumns.totalAmount}),
          0
        ) AS ${SalesSummaryModel.revenueAlias}
      FROM ${DbTables.transactions}
    ''');

    // Query agregat selalu mengembalikan satu baris, tetapi pengecekan ini
    // menjaga aplikasi tetap aman bila hasilnya tidak terduga.
    if (rows.isEmpty) {
      return const SalesSummaryModel(totalRevenue: 0, totalTransactions: 0);
    }
    return SalesSummaryModel.fromMap(rows.first);
  }

  /// Mengambil seluruh riwayat transaksi, terbaru lebih dulu.
  ///
  /// Cara kerja query:
  /// - Hanya kolom yang tampil di daftar yang dibaca agar ringan.
  /// - `ORDER BY created_at DESC` memakai format ISO-8601 UTC yang bisa
  ///   diurutkan secara leksikografis, sehingga transaksi terbaru berada di
  ///   paling atas. Index `idx_transactions_created_at` mempercepat urutan ini.
  /// - `id DESC` menjadi penentu kedua bila dua transaksi punya `created_at`
  ///   sama (mis. dibuat pada milidetik yang sama), supaya urutannya stabil.
  Future<List<ReportTransactionModel>> getTransactions() async {
    final db = await _databaseHelper.database;

    final rows = await db.rawQuery('''
      SELECT
        ${DbColumns.id},
        ${DbColumns.invoiceNumber},
        ${DbColumns.cashierName},
        ${DbColumns.totalAmount},
        ${DbColumns.createdAt}
      FROM ${DbTables.transactions}
      ORDER BY ${DbColumns.createdAt} DESC, ${DbColumns.id} DESC
    ''');

    return rows.map(ReportTransactionModel.fromMap).toList(growable: false);
  }

  /// Membaca satu struk historis lengkap dari kolom snapshot.
  ///
  /// Struk dibaca dengan tiga query terpisah (header, item, add-on). Tujuannya
  /// agar tidak ada JOIN ke master data sama sekali:
  /// 1. Header `transactions` — memuat invoice, kasir, diskon, dan total.
  /// 2. `transaction_items` — memuat `product_name_snapshot` dan
  ///    `product_price_snapshot` yang disalin saat transaksi.
  /// 3. `transaction_item_addons` — memuat `addon_name_snapshot` dan
  ///    `addon_price_snapshot`.
  ///
  /// Query add-on memakai klausa `IN (...)` agar seluruh add-on diambil dalam
  /// satu kali perjalanan ke database (bukan satu query per baris produk).
  ///
  /// Mengembalikan `null` bila header transaksi tidak ada.
  Future<ReceiptSnapshot?> getReceipt(int transactionId) async {
    final db = await _databaseHelper.database;

    // (1) Header transaksi: sumber nomor invoice, nama kasir (snapshot),
    //     nominal diskon, total, tunai, kembalian, dan waktu transaksi.
    final headerRows = await db.rawQuery(
      '''
      SELECT
        ${DbColumns.id},
        ${DbColumns.invoiceNumber},
        ${DbColumns.cashierName},
        ${DbColumns.subtotal},
        ${DbColumns.discountType},
        ${DbColumns.discountValue},
        ${DbColumns.discountAmount},
        ${DbColumns.totalAmount},
        ${DbColumns.cashReceived},
        ${DbColumns.changeAmount},
        ${DbColumns.createdAt}
      FROM ${DbTables.transactions}
      WHERE ${DbColumns.id} = ?
      LIMIT 1
      ''',
      [transactionId],
    );

    if (headerRows.isEmpty) return null;

    // (2) Detail produk: HANYA kolom snapshot yang dibaca. Kolom product_id
    //     boleh NULL bila master produk dihapus, tetapi nama & harga tetap
    //     tersedia dari kolom snapshot sehingga struk tidak error.
    final itemRows = await db.rawQuery(
      '''
      SELECT
        ${DbColumns.id},
        ${DbColumns.productId},
        ${DbColumns.productNameSnapshot},
        ${DbColumns.productPriceSnapshot},
        ${DbColumns.quantity},
        ${DbColumns.subtotal}
      FROM ${DbTables.transactionItems}
      WHERE ${DbColumns.transactionId} = ?
      ORDER BY ${DbColumns.id} ASC
      ''',
      [transactionId],
    );

    final items = itemRows
        .map(ReceiptItemSnapshotModel.fromMap)
        .toList(growable: false);

    // Tanpa baris produk, tidak ada add-on yang perlu dicari.
    if (items.isEmpty) {
      return ReceiptSnapshot(
        header: ReceiptHeaderModel.fromMap(headerRows.first),
        items: const [],
        addons: const [],
      );
    }

    // Placeholder `?` dibuat sebanyak jumlah baris produk. Nilai id dikirim
    // sebagai parameter (bukan disisipkan ke string SQL) agar aman dari SQL
    // injection sekaligus membuat query tetap bisa memakai index.
    final itemIds = items.map((item) => item.id).toList(growable: false);
    final placeholders = List.filled(itemIds.length, '?').join(', ');

    // (3) Detail add-on: nama & harga diambil dari kolom snapshot, bukan dari
    //     tabel master addons.
    final addonRows = await db.rawQuery('''
      SELECT
        ${DbColumns.transactionItemId},
        ${DbColumns.addonId},
        ${DbColumns.addonNameSnapshot},
        ${DbColumns.addonPriceSnapshot},
        ${DbColumns.quantity}
      FROM ${DbTables.transactionItemAddons}
      WHERE ${DbColumns.transactionItemId} IN ($placeholders)
      ORDER BY ${DbColumns.id} ASC
      ''', itemIds);

    return ReceiptSnapshot(
      header: ReceiptHeaderModel.fromMap(headerRows.first),
      items: items,
      addons: addonRows
          .map(ReceiptAddonSnapshotModel.fromMap)
          .toList(growable: false),
    );
  }
}
