import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pos_offline/core/database/database_helper.dart';
import 'package:mini_pos_offline/core/database/db_constants.dart';
import 'package:mini_pos_offline/features/report/data/repositories/report_repository_impl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pengujian Tahap 6: laporan penjualan dan pembuktian *immutability*.
///
/// Fokus pengujian:
/// 1. Ringkasan (revenue & jumlah transaksi) dihitung dari tabel transaksi.
/// 2. Riwayat diurutkan dari yang terbaru.
/// 3. Struk historis TIDAK berubah setelah master produk/add-on diubah
///    harganya maupun dihapus dari database.
///
/// Memakai SQLite in-memory sehingga tidak menyentuh database asli.
void main() {
  late Database db;
  late ReportRepositoryImpl repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.debugDatabasePath = inMemoryDatabasePath;
    db = await DatabaseHelper.instance.database;
    repository = ReportRepositoryImpl();
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.debugDatabasePath = null;
  });

  /// Menyiapkan kategori, produk, dan add-on sebagai master data.
  Future<(int categoryId, int productId, int addonId)> seedMasterData() async {
    final now = DateTime.utc(2026, 11, 11).toIso8601String();

    final categoryId = await db.insert(DbTables.categories, {
      DbColumns.name: 'Minuman',
      DbColumns.createdAt: now,
    });
    final productId = await db.insert(DbTables.products, {
      DbColumns.categoryId: categoryId,
      DbColumns.name: 'Kopi Susu',
      DbColumns.price: 18000,
      DbColumns.stock: 10,
      DbColumns.createdAt: now,
    });
    final addonId = await db.insert(DbTables.addons, {
      DbColumns.name: 'Extra Shot',
      DbColumns.price: 5000,
      DbColumns.stock: 10,
      DbColumns.createdAt: now,
    });

    return (categoryId, productId, addonId);
  }

  /// Menyisipkan satu transaksi lengkap beserta detail snapshot-nya.
  Future<int> insertTransaction({
    required String invoiceNumber,
    required DateTime createdAt,
    required int productId,
    required int addonId,
    String cashierName = 'Kasir Uji',
    String productName = 'Kopi Susu',
    int productPrice = 18000,
    String addonName = 'Extra Shot',
    int addonPrice = 5000,
    int quantity = 2,
  }) async {
    // Harga satu unit = harga produk + seluruh add-on.
    final lineTotal = (productPrice + addonPrice) * quantity;

    final transactionId = await db.insert(DbTables.transactions, {
      DbColumns.invoiceNumber: invoiceNumber,
      DbColumns.cashierName: cashierName,
      DbColumns.subtotal: lineTotal,
      DbColumns.discountType: 'none',
      DbColumns.discountValue: 0,
      DbColumns.discountAmount: 0,
      DbColumns.totalAmount: lineTotal,
      DbColumns.cashReceived: lineTotal + 10000,
      DbColumns.changeAmount: 10000,
      DbColumns.createdAt: createdAt.toUtc().toIso8601String(),
    });

    final itemId = await db.insert(DbTables.transactionItems, {
      DbColumns.transactionId: transactionId,
      DbColumns.productId: productId,
      DbColumns.productNameSnapshot: productName,
      DbColumns.productPriceSnapshot: productPrice,
      DbColumns.quantity: quantity,
      DbColumns.subtotal: lineTotal,
    });

    await db.insert(DbTables.transactionItemAddons, {
      DbColumns.transactionItemId: itemId,
      DbColumns.addonId: addonId,
      DbColumns.addonNameSnapshot: addonName,
      DbColumns.addonPriceSnapshot: addonPrice,
      DbColumns.quantity: quantity,
    });

    return transactionId;
  }

  test('ringkasan menghitung revenue dan jumlah transaksi sukses', () async {
    final (_, productId, addonId) = await seedMasterData();

    await insertTransaction(
      invoiceNumber: 'INV-20261110-0001',
      createdAt: DateTime.utc(2026, 11, 10, 9),
      productId: productId,
      addonId: addonId,
    );
    await insertTransaction(
      invoiceNumber: 'INV-20261111-0001',
      createdAt: DateTime.utc(2026, 11, 11, 10),
      productId: productId,
      addonId: addonId,
      productPrice: 20000,
    );

    final summary = await repository.getSalesSummary();

    expect(summary.totalTransactions, 2);
    // Transaksi 1: (18000 + 5000) * 2 = 46000.
    // Transaksi 2: (20000 + 5000) * 2 = 50000.
    expect(summary.totalRevenue, 96000);
  });

  test('riwayat transaksi diurutkan dari yang terbaru', () async {
    final (_, productId, addonId) = await seedMasterData();

    await insertTransaction(
      invoiceNumber: 'INV-20261110-0001',
      createdAt: DateTime.utc(2026, 11, 10, 9),
      productId: productId,
      addonId: addonId,
    );
    await insertTransaction(
      invoiceNumber: 'INV-20261111-0001',
      createdAt: DateTime.utc(2026, 11, 11, 10),
      productId: productId,
      addonId: addonId,
    );

    final history = await repository.getTransactions();

    expect(history, hasLength(2));
    expect(history.first.invoiceNumber, 'INV-20261111-0001');
    expect(history.last.invoiceNumber, 'INV-20261110-0001');
  });

  test(
    'struk historis tetap utuh walau master produk/add-on diubah dan dihapus',
    () async {
      final (_, productId, addonId) = await seedMasterData();
      final transactionId = await insertTransaction(
        invoiceNumber: 'INV-20261111-0001',
        createdAt: DateTime.utc(2026, 11, 11, 10),
        productId: productId,
        addonId: addonId,
      );

      // Kondisi awal: struk memakai snapshot saat transaksi.
      final firstRead = await repository.getReceipt(transactionId);
      expect(firstRead.items.single.productName, 'Kopi Susu');
      expect(firstRead.items.single.unitPrice, 18000);
      expect(firstRead.items.single.addons.single.name, 'Extra Shot');
      expect(firstRead.items.single.addons.single.price, 5000);
      expect(firstRead.totalAmount, 46000);

      // (1) Master data diubah: nama & harga baru tidak boleh bocor ke struk.
      await db.update(
        DbTables.products,
        {DbColumns.name: 'Kopi Gula Aren', DbColumns.price: 99999},
        where: '${DbColumns.id} = ?',
        whereArgs: [productId],
      );
      await db.update(
        DbTables.addons,
        {DbColumns.name: 'Extra Jumbo', DbColumns.price: 88888},
        where: '${DbColumns.id} = ?',
        whereArgs: [addonId],
      );

      final afterUpdate = await repository.getReceipt(transactionId);
      expect(afterUpdate.items.single.productName, 'Kopi Susu');
      expect(afterUpdate.items.single.unitPrice, 18000);
      expect(afterUpdate.items.single.addons.single.name, 'Extra Shot');
      expect(afterUpdate.items.single.addons.single.price, 5000);

      // (2) Master data dihapus fisik. Foreign key ON DELETE SET NULL membuat
      //     product_id/addon_id menjadi null, tetapi struk tetap bisa dibaca
      //     karena nama & harga berasal dari kolom snapshot.
      await db.delete(
        DbTables.products,
        where: '${DbColumns.id} = ?',
        whereArgs: [productId],
      );
      await db.delete(
        DbTables.addons,
        where: '${DbColumns.id} = ?',
        whereArgs: [addonId],
      );

      final afterDelete = await repository.getReceipt(transactionId);
      expect(afterDelete.items.single.productName, 'Kopi Susu');
      expect(afterDelete.items.single.unitPrice, 18000);
      expect(afterDelete.items.single.productId, isNull);
      expect(afterDelete.items.single.addons.single.name, 'Extra Shot');
      expect(afterDelete.items.single.addons.single.price, 5000);
      expect(afterDelete.items.single.addons.single.addonId, isNull);
      expect(afterDelete.totalAmount, 46000);
      expect(afterDelete.cashierName, 'Kasir Uji');

      // Ringkasan juga tetap sama karena hanya membaca tabel transaksi.
      final summary = await repository.getSalesSummary();
      expect(summary.totalRevenue, 46000);
      expect(summary.totalTransactions, 1);
    },
  );
}
