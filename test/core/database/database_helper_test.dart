import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pos_offline/core/database/database_helper.dart';
import 'package:mini_pos_offline/core/database/db_constants.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pengujian skema database pada Tahap 1.
///
/// Menggunakan `sqflite_common_ffi` agar SQLite bisa berjalan di mesin desktop
/// tanpa emulator. Database dibuat di memori (`inMemoryDatabasePath`) sehingga
/// setiap test dimulai dari kondisi bersih dan tidak menyentuh data asli.
void main() {
  setUpAll(() {
    // Inisialisasi implementasi SQLite untuk unit test.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    // Arahkan helper ke database sementara di memori.
    DatabaseHelper.debugDatabasePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    // Tutup koneksi agar database in-memory ikut terhapus.
    await DatabaseHelper.instance.close();
    DatabaseHelper.debugDatabasePath = null;
  });

  /// Mengambil daftar nama tabel yang benar-benar ada di SQLite.
  Future<List<String>> tableNames(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
    );
    return rows.map((row) => row['name'] as String).toList();
  }

  /// Menyiapkan kategori + produk aktif untuk kebutuhan test transaksi.
  Future<(int, int)> seedCategoryAndProduct(Database db) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final categoryId = await db.insert(DbTables.categories, {
      'name': 'Minuman',
      'created_at': now,
    });
    final productId = await db.insert(DbTables.products, {
      'category_id': categoryId,
      'name': 'Es Teh',
      'price': 5000,
      'stock': 10,
      'created_at': now,
    });
    return (categoryId, productId);
  }

  test('seluruh tabel wajib terbentuk saat database pertama kali dibuat',
      () async {
    final db = await DatabaseHelper.instance.database;
    final tables = await tableNames(db);

    expect(
      tables,
      containsAll([
        DbTables.users,
        DbTables.categories,
        DbTables.products,
        DbTables.addons,
        DbTables.transactions,
        DbTables.transactionItems,
        DbTables.transactionItemAddons,
      ]),
    );
  });

  test('foreign key aktif: produk dengan kategori tidak ada harus ditolak',
      () async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toUtc().toIso8601String();

    // Kategori id 999 tidak pernah dibuat, jadi insert ini harus gagal.
    await expectLater(
      db.insert(DbTables.products, {
        'category_id': 999,
        'name': 'Produk Yatim',
        'price': 1000,
        'stock': 1,
        'created_at': now,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('aturan diskon dijaga di level database', () async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toUtc().toIso8601String();

    // Diskon nominal melebihi subtotal -> melanggar CHECK discount_amount.
    await expectLater(
      db.insert(DbTables.transactions, {
        'invoice_number': 'INV-001',
        'cashier_name': 'Kasir',
        'subtotal': 10000,
        'discount_type': DiscountType.nominal,
        'discount_value': 15000,
        'discount_amount': 15000,
        'total_amount': 0,
        'cash_received': 10000,
        'change_amount': 10000,
        'created_at': now,
      }),
      throwsA(isA<DatabaseException>()),
    );

    // Diskon persentase di atas 100% juga harus ditolak.
    await expectLater(
      db.insert(DbTables.transactions, {
        'invoice_number': 'INV-002',
        'cashier_name': 'Kasir',
        'subtotal': 10000,
        'discount_type': DiscountType.percentage,
        'discount_value': 150,
        'discount_amount': 0,
        'total_amount': 10000,
        'cash_received': 10000,
        'change_amount': 0,
        'created_at': now,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('snapshot detail transaksi tidak berubah walau master produk diubah',
      () async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final (_, productId) = await seedCategoryAndProduct(db);

    final transactionId = await db.insert(DbTables.transactions, {
      'invoice_number': 'INV-100',
      'cashier_name': 'Kasir Satu',
      'subtotal': 10000,
      'discount_type': DiscountType.none,
      'discount_value': 0,
      'discount_amount': 0,
      'total_amount': 10000,
      'cash_received': 20000,
      'change_amount': 10000,
      'created_at': now,
    });

    await db.insert(DbTables.transactionItems, {
      'transaction_id': transactionId,
      'product_id': productId,
      'product_name_snapshot': 'Es Teh',
      'product_price_snapshot': 5000,
      'quantity': 2,
      'subtotal': 10000,
    });

    // Master produk diubah harganya dan di-soft delete setelah transaksi.
    await db.update(
      DbTables.products,
      {'price': 9000, 'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [productId],
    );

    final item = (await db.query(DbTables.transactionItems)).single;
    expect(item['product_name_snapshot'], 'Es Teh');
    expect(item['product_price_snapshot'], 5000);
    expect(item['quantity'], 2);
    expect(item['subtotal'], 10000);
  });

  test('menghapus baris transaksi ikut menghapus add-on detailnya', () async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final (_, productId) = await seedCategoryAndProduct(db);

    final addonId = await db.insert(DbTables.addons, {
      'name': 'Boba',
      'price': 2000,
      'stock': 5,
      'created_at': now,
    });

    final transactionId = await db.insert(DbTables.transactions, {
      'invoice_number': 'INV-200',
      'cashier_name': 'Kasir Satu',
      'subtotal': 7000,
      'discount_type': DiscountType.none,
      'discount_value': 0,
      'discount_amount': 0,
      'total_amount': 7000,
      'cash_received': 10000,
      'change_amount': 3000,
      'created_at': now,
    });

    final itemId = await db.insert(DbTables.transactionItems, {
      'transaction_id': transactionId,
      'product_id': productId,
      'product_name_snapshot': 'Es Teh',
      'product_price_snapshot': 5000,
      'quantity': 1,
      'subtotal': 7000,
    });

    await db.insert(DbTables.transactionItemAddons, {
      'transaction_item_id': itemId,
      'addon_id': addonId,
      'addon_name_snapshot': 'Boba',
      'addon_price_snapshot': 2000,
      'quantity': 1,
    });

    // Hapus header transaksi -> item dan add-on detail harus ikut terhapus.
    await db.delete(
      DbTables.transactions,
      where: 'id = ?',
      whereArgs: [transactionId],
    );

    expect(await db.query(DbTables.transactionItems), isEmpty);
    expect(await db.query(DbTables.transactionItemAddons), isEmpty);
  });
}
