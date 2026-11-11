import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pos_offline/core/database/database_helper.dart';
import 'package:mini_pos_offline/core/database/db_constants.dart';
import 'package:mini_pos_offline/features/master_data/data/datasources/addon_local_data_source.dart';
import 'package:mini_pos_offline/features/master_data/data/datasources/category_local_data_source.dart';
import 'package:mini_pos_offline/features/master_data/data/datasources/product_image_storage.dart';
import 'package:mini_pos_offline/features/master_data/data/datasources/product_local_data_source.dart';
import 'package:mini_pos_offline/features/master_data/data/repositories/master_data_repository_impl.dart';
import 'package:mini_pos_offline/features/master_data/domain/failures/master_data_failure.dart';
import 'package:mini_pos_offline/features/master_data/domain/repositories/master_data_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pengujian fitur master data (Tahap 3).
///
/// Memakai SQLite in-memory dan direktori sementara untuk foto, sehingga test
/// tidak menyentuh database maupun dokumen asli pengguna.
void main() {
  late MasterDataRepository repository;
  late Directory tempRoot;
  late Directory documentsDirectory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.debugDatabasePath = inMemoryDatabasePath;

    // Direktori sementara meniru Application Documents Directory.
    tempRoot = await Directory.systemTemp.createTemp('mini_pos_master_data_');
    documentsDirectory = Directory(p.join(tempRoot.path, 'documents'));

    repository = MasterDataRepositoryImpl(
      categoryDataSource: CategoryLocalDataSource(),
      productDataSource: ProductLocalDataSource(),
      addonDataSource: AddonLocalDataSource(),
      imageStorage: ProductImageStorage(
        documentsDirectoryProvider: () async => documentsDirectory,
      ),
    );

    // Pastikan seluruh tabel sudah dibuat sebelum skenario berjalan.
    await DatabaseHelper.instance.database;
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.debugDatabasePath = null;
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test(
    'kategori duplikat ditolak tanpa membedakan huruf besar/kecil',
    () async {
      await repository.createCategory('Minuman');

      await expectLater(
        repository.createCategory('minuman'),
        throwsA(
          isA<MasterDataFailure>().having(
            (failure) => failure.type,
            'type',
            MasterDataFailureType.duplicateName,
          ),
        ),
      );
    },
  );

  test('kategori tidak bisa dihapus selama masih dipakai produk', () async {
    final category = await repository.createCategory('Makanan');
    final product = await repository.createProduct(
      categoryId: category.id,
      name: 'Nasi Goreng',
      price: 20000,
      stock: 5,
    );

    // productCount harus mencerminkan produk aktif.
    final categories = await repository.getCategories();
    expect(categories.single.productCount, 1);

    await expectLater(
      repository.deleteCategory(category.id),
      throwsA(
        isA<MasterDataFailure>().having(
          (failure) => failure.type,
          'type',
          MasterDataFailureType.categoryInUse,
        ),
      ),
    );

    // Produk di-soft delete: barisnya masih ada, sehingga FOREIGN KEY
    // ON DELETE RESTRICT tetap menolak penghapusan kategori.
    await repository.deleteProduct(product.id);

    await expectLater(
      repository.deleteCategory(category.id),
      throwsA(
        isA<MasterDataFailure>().having(
          (failure) => failure.type,
          'type',
          MasterDataFailureType.categoryInUse,
        ),
      ),
    );

    final db = await DatabaseHelper.instance.database;
    expect(await db.query(DbTables.categories), hasLength(1));
  });

  test('foto produk disalin ke direktori permanen dan path-nya tersimpan', () async {
    final category = await repository.createCategory('Minuman');

    // File sumber meniru hasil image_picker di cache sementara.
    final sourcePhoto = File(p.join(tempRoot.path, 'foto_sementara.jpg'));
    await sourcePhoto.writeAsBytes(List<int>.filled(64, 7));

    final product = await repository.createProduct(
      categoryId: category.id,
      name: 'Es Teh',
      price: 5000,
      stock: 10,
      photoSourcePath: sourcePhoto.path,
    );

    expect(product.imagePath, isNotNull);

    final permanentPath = product.imagePath!;
    final expectedFolder = p.join(
      documentsDirectory.path,
      ProductImageStorage.folderName,
    );

    // Path yang disimpan harus berada di folder permanen aplikasi, bukan cache.
    expect(p.isWithin(expectedFolder, permanentPath), isTrue);
    expect(await File(permanentPath).exists(), isTrue);

    final db = await DatabaseHelper.instance.database;
    final row = (await db.query(DbTables.products)).single;
    expect(row[DbColumns.imagePath], permanentPath);
  });

  test('mengganti foto menghapus file lama setelah update berhasil', () async {
    final category = await repository.createCategory('Minuman');

    final firstPhoto = File(p.join(tempRoot.path, 'foto_pertama.jpg'));
    await firstPhoto.writeAsBytes(List<int>.filled(16, 1));

    final product = await repository.createProduct(
      categoryId: category.id,
      name: 'Es Teh',
      price: 5000,
      stock: 10,
      photoSourcePath: firstPhoto.path,
    );

    final oldPath = product.imagePath!;
    final secondPhoto = File(p.join(tempRoot.path, 'foto_kedua.jpg'));
    await secondPhoto.writeAsBytes(List<int>.filled(16, 2));

    final updated = await repository.updateProduct(
      id: product.id,
      categoryId: category.id,
      name: 'Es Teh',
      price: 5000,
      stock: 10,
      photoSourcePath: secondPhoto.path,
    );

    expect(updated.imagePath, isNotNull);
    expect(updated.imagePath, isNot(oldPath));
    expect(await File(oldPath).exists(), isFalse);
    expect(await File(updated.imagePath!).exists(), isTrue);
  });

  test(
    'hapus produk memakai soft delete dan menyembunyikannya dari katalog',
    () async {
      final category = await repository.createCategory('Minuman');
      final product = await repository.createProduct(
        categoryId: category.id,
        name: 'Es Teh',
        price: 5000,
        stock: 10,
      );

      await repository.deleteProduct(product.id);

      // Katalog tidak lagi menampilkan produk.
      expect(await repository.getProducts(), isEmpty);

      // Baris tetap ada dengan is_deleted = 1.
      final db = await DatabaseHelper.instance.database;
      final row = (await db.query(DbTables.products)).single;
      expect(row[DbColumns.id], product.id);
      expect(row[DbColumns.isDeleted], 1);
    },
  );

  test('add-on dapat ditambah, diubah, lalu di-soft-delete', () async {
    final addon = await repository.createAddon(
      name: 'Extra Keju',
      price: 5000,
      stock: 10,
    );

    expect(addon.name, 'Extra Keju');

    final updated = await repository.updateAddon(
      id: addon.id,
      name: 'Extra Keju',
      price: 6000,
      stock: 8,
    );
    expect(updated.price, 6000);
    expect(updated.stock, 8);

    await repository.deleteAddon(addon.id);
    expect(await repository.getAddons(), isEmpty);

    final db = await DatabaseHelper.instance.database;
    final row = (await db.query(DbTables.addons)).single;
    expect(row[DbColumns.isDeleted], 1);
  });
}
