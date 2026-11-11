import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pos_offline/core/database/database_helper.dart';
import 'package:mini_pos_offline/core/database/db_constants.dart'
    show DbColumns, DbTables;
import 'package:mini_pos_offline/features/auth/domain/entities/auth_session.dart';
import 'package:mini_pos_offline/features/auth/domain/entities/user.dart';
import 'package:mini_pos_offline/features/auth/domain/repositories/auth_repository.dart';
import 'package:mini_pos_offline/features/master_data/data/datasources/addon_local_data_source.dart';
import 'package:mini_pos_offline/features/master_data/data/datasources/category_local_data_source.dart';
import 'package:mini_pos_offline/features/master_data/data/datasources/product_image_storage.dart';
import 'package:mini_pos_offline/features/master_data/data/datasources/product_local_data_source.dart';
import 'package:mini_pos_offline/features/master_data/data/repositories/master_data_repository_impl.dart';
import 'package:mini_pos_offline/features/master_data/domain/entities/addon.dart';
import 'package:mini_pos_offline/features/master_data/domain/entities/category.dart';
import 'package:mini_pos_offline/features/master_data/domain/entities/product.dart';
import 'package:mini_pos_offline/features/master_data/domain/repositories/master_data_repository.dart';
import 'package:mini_pos_offline/features/pos/data/repositories/pos_repository_impl.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/cart_addon.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/cart_item.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/checkout_request.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/discount_type.dart';
import 'package:mini_pos_offline/features/pos/domain/failures/pos_failure.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Repository auth palsu: hanya menyediakan sesi aktif untuk checkout.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.session});

  final AuthSession? session;

  @override
  Future<AuthSession?> getActiveSession() async => session;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<User> register({
    required String name,
    required String username,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {
    throw UnimplementedError();
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    throw UnimplementedError();
  }
}

/// Pengujian Tahap 5: checkout atomik, snapshot riwayat, dan proteksi diskon
/// pada level repository.
///
/// Memakai SQLite in-memory sehingga tidak menyentuh database asli.
void main() {
  late MasterDataRepository masterDataRepository;
  late PosRepositoryImpl posRepository;
  late AuthSession session;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.debugDatabasePath = inMemoryDatabasePath;

    masterDataRepository = MasterDataRepositoryImpl(
      categoryDataSource: CategoryLocalDataSource(),
      productDataSource: ProductLocalDataSource(),
      addonDataSource: AddonLocalDataSource(),
      imageStorage: ProductImageStorage(),
    );

    session = AuthSession(
      user: User(
        id: 1,
        name: 'Kasir Uji',
        username: 'kasir',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      loggedInAt: DateTime.utc(2026, 1, 1),
    );

    await DatabaseHelper.instance.database;

    posRepository = PosRepositoryImpl(
      masterDataRepository,
      _FakeAuthRepository(session: session),
      databaseHelper: DatabaseHelper.instance,
    );
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.debugDatabasePath = null;
  });

  /// Menyiapkan kategori, produk, dan add-on untuk skenario transaksi.
  Future<(Category, Product, Addon)> seedCatalog({
    int productStock = 5,
    int addonStock = 5,
  }) async {
    final category = await masterDataRepository.createCategory('Minuman');
    final product = await masterDataRepository.createProduct(
      categoryId: category.id,
      name: 'Kopi Susu',
      price: 18000,
      stock: productStock,
    );
    final addon = await masterDataRepository.createAddon(
      name: 'Extra Shot',
      price: 5000,
      stock: addonStock,
    );
    return (category, product, addon);
  }

  /// Membuat satu baris keranjang berisi produk + add-on.
  CartItem buildCartItem({
    required Product product,
    Addon? addon,
    int quantity = 1,
  }) {
    return CartItem(
      productId: product.id,
      productName: product.name,
      unitPrice: product.price,
      productStock: product.stock,
      quantity: quantity,
      addons: addon == null
          ? const <CartAddon>[]
          : [
              CartAddon(
                addonId: addon.id,
                name: addon.name,
                price: addon.price,
                stock: addon.stock,
              ),
            ],
    );
  }

  test('checkout menyimpan header, detail snapshot, dan mengurangi stok', () async {
    final (_, product, addon) = await seedCatalog();

    final receipt = await posRepository.checkout(
      CheckoutRequest(
        items: [buildCartItem(product: product, addon: addon, quantity: 2)],
        discountType: DiscountType.percentage,
        discountValue: 10,
        cashReceived: 50000,
      ),
    );

    // Subtotal = (18.000 + 5.000) x 2 = 46.000
    // Diskon 10% = 4.600 -> total 41.400, tunai 50.000 -> kembali 8.600.
    expect(receipt.subtotal, 46000);
    expect(receipt.discountAmount, 4600);
    expect(receipt.totalAmount, 41400);
    expect(receipt.cashReceived, 50000);
    expect(receipt.changeAmount, 8600);
    expect(receipt.cashierName, 'Kasir Uji');
    expect(receipt.invoiceNumber, matches(RegExp(r'^INV-\d{8}-0001$')));

    final db = await DatabaseHelper.instance.database;

    final headers = await db.query(DbTables.transactions);
    expect(headers, hasLength(1));
    final header = headers.single;
    expect(header[DbColumns.cashierName], 'Kasir Uji');
    expect(header[DbColumns.discountType], 'percentage');
    expect(header[DbColumns.discountValue], 10);
    expect(header[DbColumns.discountAmount], 4600);
    expect(header[DbColumns.totalAmount], 41400);
    expect(header[DbColumns.cashReceived], 50000);
    expect(header[DbColumns.changeAmount], 8600);

    final items = await db.query(DbTables.transactionItems);
    expect(items, hasLength(1));
    expect(items.single[DbColumns.productNameSnapshot], 'Kopi Susu');
    expect(items.single[DbColumns.productPriceSnapshot], 18000);
    expect(items.single[DbColumns.quantity], 2);

    final addons = await db.query(DbTables.transactionItemAddons);
    expect(addons, hasLength(1));
    expect(addons.single[DbColumns.addonNameSnapshot], 'Extra Shot');
    expect(addons.single[DbColumns.addonPriceSnapshot], 5000);
    expect(addons.single[DbColumns.quantity], 2);

    // Stok berkurang sesuai total unit yang dibeli.
    final productRows = await db.query(DbTables.products);
    expect(productRows.single[DbColumns.stock], 3);
    final addonRows = await db.query(DbTables.addons);
    expect(addonRows.single[DbColumns.stock], 3);
  });

  test('snapshot riwayat tidak berubah saat master data diganti', () async {
    final (_, product, _) = await seedCatalog();

    await posRepository.checkout(
      CheckoutRequest(
        items: [buildCartItem(product: product)],
        discountType: DiscountType.none,
        discountValue: 0,
        cashReceived: 20000,
      ),
    );

    final db = await DatabaseHelper.instance.database;

    // Simulasi kasir mengganti nama & harga produk di master data.
    await db.update(
      DbTables.products,
      {DbColumns.name: 'Kopi Susu Gula Aren', DbColumns.price: 25000},
      where: '${DbColumns.id} = ?',
      whereArgs: [product.id],
    );

    // Riwayat transaksi tetap memakai salinan saat transaksi terjadi.
    final items = await db.query(DbTables.transactionItems);
    expect(items.single[DbColumns.productNameSnapshot], 'Kopi Susu');
    expect(items.single[DbColumns.productPriceSnapshot], 18000);
  });

  test('stok kurang membatalkan SELURUH transaksi (rollback)', () async {
    // Stok hanya 1, tetapi keranjang meminta 2 unit.
    final (_, product, _) = await seedCatalog(productStock: 1);

    await expectLater(
      posRepository.checkout(
        CheckoutRequest(
          items: [buildCartItem(product: product, quantity: 2)],
          discountType: DiscountType.none,
          discountValue: 0,
          cashReceived: 50000,
        ),
      ),
      throwsA(
        isA<PosFailure>()
            .having((failure) => failure.type, 'type', PosFailureType.validation)
            .having(
              (failure) => failure.message,
              'message',
              contains('Stok produk'),
            ),
      ),
    );

    final db = await DatabaseHelper.instance.database;

    // Header & detail sudah sempat di-insert sebelum stok gagal, tetapi
    // db.transaction harus mengembalikan database ke kondisi awal.
    expect(await db.query(DbTables.transactions), isEmpty);
    expect(await db.query(DbTables.transactionItems), isEmpty);
    expect(await db.query(DbTables.transactionItemAddons), isEmpty);

    final productRows = await db.query(DbTables.products);
    expect(productRows.single[DbColumns.stock], 1);
  });

  test('diskon nominal melebihi subtotal ditolak sebelum menyentuh database',
      () async {
    final (_, product, _) = await seedCatalog();

    await expectLater(
      posRepository.checkout(
        CheckoutRequest(
          items: [buildCartItem(product: product)],
          discountType: DiscountType.nominal,
          discountValue: 20000,
          cashReceived: 20000,
        ),
      ),
      throwsA(
        isA<PosFailure>()
            .having((failure) => failure.type, 'type', PosFailureType.validation)
            .having(
              (failure) => failure.message,
              'message',
              contains('tidak boleh melebihi'),
            ),
      ),
    );

    final db = await DatabaseHelper.instance.database;
    expect(await db.query(DbTables.transactions), isEmpty);
    expect(
      (await db.query(DbTables.products)).single[DbColumns.stock],
      5,
    );
  });

  test('uang tunai kurang ditolak dan tidak menulis transaksi', () async {
    final (_, product, _) = await seedCatalog();

    await expectLater(
      posRepository.checkout(
        CheckoutRequest(
          items: [buildCartItem(product: product)],
          discountType: DiscountType.none,
          discountValue: 0,
          cashReceived: 10000,
        ),
      ),
      throwsA(
        isA<PosFailure>().having(
          (failure) => failure.message,
          'message',
          contains('masih kurang'),
        ),
      ),
    );

    final db = await DatabaseHelper.instance.database;
    expect(await db.query(DbTables.transactions), isEmpty);
  });

  test('nomor invoice berurutan pada hari yang sama', () async {
    final (_, product, _) = await seedCatalog(productStock: 10);

    final first = await posRepository.checkout(
      CheckoutRequest(
        items: [buildCartItem(product: product)],
        discountType: DiscountType.none,
        discountValue: 0,
        cashReceived: 20000,
      ),
    );

    final second = await posRepository.checkout(
      CheckoutRequest(
        items: [buildCartItem(product: product)],
        discountType: DiscountType.none,
        discountValue: 0,
        cashReceived: 20000,
      ),
    );

    expect(first.invoiceNumber, endsWith('-0001'));
    expect(second.invoiceNumber, endsWith('-0002'));
    expect(first.invoiceNumber, isNot(second.invoiceNumber));
  });
}
