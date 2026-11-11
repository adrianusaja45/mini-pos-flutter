import 'package:sqflite/sqflite.dart';

import '../../domain/entities/addon.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/failures/master_data_failure.dart';
import '../../domain/repositories/master_data_repository.dart';
import '../../domain/validators/master_data_validators.dart';
import '../datasources/addon_local_data_source.dart';
import '../datasources/category_local_data_source.dart';
import '../datasources/product_image_storage.dart';
import '../datasources/product_local_data_source.dart';
import '../models/addon_model.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

/// Implementasi nyata [MasterDataRepository] berbasis SQLite + file lokal.
///
/// Di sinilah seluruh aturan bisnis master data dijalankan:
/// 1. Normalisasi & validasi input (nama, harga, stok).
/// 2. Pencegahan nama kategori/add-on duplikat.
/// 3. Penanganan error FOREIGN KEY `ON DELETE RESTRICT` saat hapus kategori.
/// 4. Penyalinan foto ke direktori permanen sebelum baris produk disimpan.
/// 5. Soft delete produk & add-on (`is_deleted = 1`) demi keutuhan riwayat.
///
/// Seluruh operasi 100% offline; tidak ada pemanggilan jaringan.
class MasterDataRepositoryImpl implements MasterDataRepository {
  MasterDataRepositoryImpl({
    CategoryLocalDataSource? categoryDataSource,
    ProductLocalDataSource? productDataSource,
    AddonLocalDataSource? addonDataSource,
    ProductImageStorage? imageStorage,
  }) : _categoryDataSource = categoryDataSource ?? CategoryLocalDataSource(),
       _productDataSource = productDataSource ?? ProductLocalDataSource(),
       _addonDataSource = addonDataSource ?? AddonLocalDataSource(),
       _imageStorage = imageStorage ?? ProductImageStorage();

  final CategoryLocalDataSource _categoryDataSource;
  final ProductLocalDataSource _productDataSource;
  final AddonLocalDataSource _addonDataSource;
  final ProductImageStorage _imageStorage;

  /// Kode extended result SQLite untuk pelanggaran FOREIGN KEY
  /// (`SQLITE_CONSTRAINT_FOREIGNKEY` = 787).
  static const int _sqliteForeignKeyResultCode = 787;

  // ---------------------------------------------------------------------------
  // Kategori
  // ---------------------------------------------------------------------------

  @override
  Future<List<Category>> getCategories() async {
    try {
      final models = await _categoryDataSource.getAll();
      return models.map((model) => model.toEntity()).toList();
    } catch (_) {
      throw const MasterDataFailure(
        'Gagal memuat daftar kategori. Silakan coba lagi.',
      );
    }
  }

  @override
  Future<Category> createCategory(String name) async {
    final normalizedName = _validatedName(name, label: 'Nama kategori');

    try {
      // Cek duplikat lebih dulu agar pesan error jelas. Constraint UNIQUE di
      // database tetap menjadi pengaman terakhir (lihat catch di bawah).
      if (await _categoryDataSource.existsByName(normalizedName)) {
        throw MasterDataFailure(
          'Kategori "$normalizedName" sudah ada. Gunakan nama lain.',
          type: MasterDataFailureType.duplicateName,
        );
      }

      final createdAt = DateTime.now().toUtc();
      final id = await _categoryDataSource.insert(
        CategoryModel(name: normalizedName, createdAt: createdAt),
      );

      return Category(id: id, name: normalizedName, createdAt: createdAt);
    } on MasterDataFailure {
      rethrow;
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw MasterDataFailure(
          'Kategori "$normalizedName" sudah ada. Gunakan nama lain.',
          type: MasterDataFailureType.duplicateName,
        );
      }
      throw const MasterDataFailure(
        'Gagal menyimpan kategori. Silakan coba lagi.',
      );
    } catch (_) {
      throw const MasterDataFailure(
        'Gagal menyimpan kategori. Silakan coba lagi.',
      );
    }
  }

  @override
  Future<Category> updateCategory({
    required int id,
    required String name,
  }) async {
    final normalizedName = _validatedName(name, label: 'Nama kategori');

    try {
      final existing = await _categoryDataSource.findById(id);
      if (existing == null) {
        throw const MasterDataFailure(
          'Kategori tidak ditemukan. Mungkin sudah dihapus.',
          type: MasterDataFailureType.notFound,
        );
      }

      if (await _categoryDataSource.existsByName(
        normalizedName,
        excludeId: id,
      )) {
        throw MasterDataFailure(
          'Kategori "$normalizedName" sudah ada. Gunakan nama lain.',
          type: MasterDataFailureType.duplicateName,
        );
      }

      final affected = await _categoryDataSource.updateName(id, normalizedName);
      if (affected == 0) {
        throw const MasterDataFailure(
          'Kategori tidak ditemukan. Mungkin sudah dihapus.',
          type: MasterDataFailureType.notFound,
        );
      }

      return Category(
        id: id,
        name: normalizedName,
        createdAt: existing.createdAt,
        productCount: existing.productCount,
      );
    } on MasterDataFailure {
      rethrow;
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw MasterDataFailure(
          'Kategori "$normalizedName" sudah ada. Gunakan nama lain.',
          type: MasterDataFailureType.duplicateName,
        );
      }
      throw const MasterDataFailure(
        'Gagal mengubah kategori. Silakan coba lagi.',
      );
    } catch (_) {
      throw const MasterDataFailure(
        'Gagal mengubah kategori. Silakan coba lagi.',
      );
    }
  }

  @override
  Future<void> deleteCategory(int id) async {
    CategoryModel? category;

    try {
      category = await _categoryDataSource.findById(id);
      if (category == null) {
        throw const MasterDataFailure(
          'Kategori tidak ditemukan. Mungkin sudah dihapus.',
          type: MasterDataFailureType.notFound,
        );
      }

      // PENTING: hitung SEMUA produk, termasuk yang sudah di-soft-delete.
      // FOREIGN KEY ON DELETE RESTRICT tetap menolak penghapusan selama baris
      // produk masih menunjuk kategori ini, meskipun produk tidak tampil di UI.
      final totalProductCount = await _categoryDataSource
          .countProductsInCategory(id, onlyActive: false);
      final activeProductCount = await _categoryDataSource
          .countProductsInCategory(id, onlyActive: true);

      if (totalProductCount > 0) {
        throw MasterDataFailure(
          _categoryInUseMessage(
            categoryName: category.name,
            activeProductCount: activeProductCount,
            totalProductCount: totalProductCount,
          ),
          type: MasterDataFailureType.categoryInUse,
        );
      }

      final affected = await _categoryDataSource.deleteById(id);
      if (affected == 0) {
        throw const MasterDataFailure(
          'Kategori tidak ditemukan. Mungkin sudah dihapus.',
          type: MasterDataFailureType.notFound,
        );
      }
    } on MasterDataFailure {
      rethrow;
    } on DatabaseException catch (error) {
      // Pengaman terakhir: bila ada produk yang masuk di antara pengecekan dan
      // penghapusan, SQLite mengembalikan error FOREIGN KEY. Error teknis ini
      // diterjemahkan menjadi pesan yang bisa dipahami kasir.
      if (_isForeignKeyError(error)) {
        throw MasterDataFailure(
          'Kategori "${category?.name ?? ''}" tidak dapat dihapus karena masih '
          'digunakan oleh produk. Pindahkan produk tersebut ke kategori lain '
          'terlebih dahulu.',
          type: MasterDataFailureType.categoryInUse,
        );
      }
      throw const MasterDataFailure(
        'Gagal menghapus kategori. Silakan coba lagi.',
      );
    } catch (_) {
      throw const MasterDataFailure(
        'Gagal menghapus kategori. Silakan coba lagi.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Produk
  // ---------------------------------------------------------------------------

  @override
  Future<List<Product>> getProducts() async {
    try {
      final models = await _productDataSource.getActiveProducts();
      return models.map((model) => model.toEntity()).toList();
    } catch (_) {
      throw const MasterDataFailure(
        'Gagal memuat daftar produk. Silakan coba lagi.',
      );
    }
  }

  @override
  Future<Product> createProduct({
    required int categoryId,
    required String name,
    required int price,
    required int stock,
    String? photoSourcePath,
  }) async {
    final normalizedName = _validateProductInput(
      name: name,
      price: price,
      stock: stock,
    );

    // Menyimpan path permanen hasil penyalinan foto. `null` berarti produk
    // dibuat tanpa foto.
    String? permanentImagePath;

    try {
      final category = await _categoryDataSource.findById(categoryId);
      if (category == null) {
        throw const MasterDataFailure(
          'Kategori yang dipilih tidak ditemukan. Muat ulang daftar kategori.',
          type: MasterDataFailureType.validation,
        );
      }

      // Foto disalin LEBIH DULU. Bila penyalinan gagal, baris produk tidak
      // dibuat sehingga tidak ada produk dengan path foto yang rusak.
      if (photoSourcePath != null && photoSourcePath.trim().isNotEmpty) {
        permanentImagePath = await _imageStorage.persistImage(photoSourcePath);
      }

      final createdAt = DateTime.now().toUtc();
      final model = ProductModel(
        categoryId: categoryId,
        categoryName: category.name,
        name: normalizedName,
        price: price,
        stock: stock,
        imagePath: permanentImagePath,
        createdAt: createdAt,
      );

      final id = await _productDataSource.insert(model);

      // Membaca ulang dari database memastikan data yang dikembalikan benar-
      // benar sama dengan isi tabel (termasuk nama kategori hasil JOIN).
      final saved = await _productDataSource.findById(id);
      if (saved != null) return saved.toEntity();

      return Product(
        id: id,
        categoryId: categoryId,
        categoryName: category.name,
        name: normalizedName,
        price: price,
        stock: stock,
        imagePath: permanentImagePath,
        createdAt: createdAt,
      );
    } on MasterDataFailure {
      // Rollback manual untuk file: bila insert gagal setelah foto disalin,
      // hapus salinan agar tidak menumpuk file yatim di penyimpanan.
      await _imageStorage.deleteImage(permanentImagePath);
      rethrow;
    } on DatabaseException catch (error) {
      await _imageStorage.deleteImage(permanentImagePath);
      throw _translateProductDatabaseError(error);
    } catch (_) {
      await _imageStorage.deleteImage(permanentImagePath);
      throw const MasterDataFailure(
        'Gagal menyimpan produk. Silakan coba lagi.',
      );
    }
  }

  @override
  Future<Product> updateProduct({
    required int id,
    required int categoryId,
    required String name,
    required int price,
    required int stock,
    String? photoSourcePath,
    bool removePhoto = false,
  }) async {
    final normalizedName = _validateProductInput(
      name: name,
      price: price,
      stock: stock,
    );

    // Hanya berisi file BARU yang perlu dihapus bila update gagal. File lama
    // tidak boleh dihapus sebelum update benar-benar berhasil.
    String? newlyCopiedImagePath;

    try {
      final existing = await _productDataSource.findById(id);
      if (existing == null) {
        throw const MasterDataFailure(
          'Produk tidak ditemukan. Mungkin sudah dihapus.',
          type: MasterDataFailureType.notFound,
        );
      }

      final category = await _categoryDataSource.findById(categoryId);
      if (category == null) {
        throw const MasterDataFailure(
          'Kategori yang dipilih tidak ditemukan. Muat ulang daftar kategori.',
          type: MasterDataFailureType.validation,
        );
      }

      // Tentukan path foto akhir:
      // - hapus foto -> null
      // - pilih foto baru -> path permanen hasil salinan
      // - tidak ada perubahan -> tetap memakai path lama
      var finalImagePath = existing.imagePath;

      if (removePhoto) {
        finalImagePath = null;
      }

      if (photoSourcePath != null && photoSourcePath.trim().isNotEmpty) {
        final persistedPath = await _imageStorage.persistImage(photoSourcePath);
        finalImagePath = persistedPath;

        // Bila hasil salinan ternyata sama dengan path lama (kasir memilih
        // file yang sudah berada di folder permanen), jangan tandai sebagai
        // file baru agar tidak terhapus saat rollback.
        if (persistedPath != existing.imagePath) {
          newlyCopiedImagePath = persistedPath;
        }
      }

      final affected = await _productDataSource.updateById(id, {
        'category_id': categoryId,
        'name': normalizedName,
        'price': price,
        'stock': stock,
        'image_path': finalImagePath,
      });

      if (affected == 0) {
        throw const MasterDataFailure(
          'Produk tidak ditemukan. Mungkin sudah dihapus.',
          type: MasterDataFailureType.notFound,
        );
      }

      // Baru setelah update sukses, foto lama yang tidak dipakai lagi boleh
      // dihapus. Ini mencegah produk kehilangan foto bila update gagal.
      final oldImagePath = existing.imagePath;
      if (oldImagePath != null && oldImagePath != finalImagePath) {
        await _imageStorage.deleteImage(oldImagePath);
      }

      final saved = await _productDataSource.findById(id);
      if (saved != null) return saved.toEntity();

      return Product(
        id: id,
        categoryId: categoryId,
        categoryName: category.name,
        name: normalizedName,
        price: price,
        stock: stock,
        imagePath: finalImagePath,
        createdAt: existing.createdAt,
      );
    } on MasterDataFailure {
      await _imageStorage.deleteImage(newlyCopiedImagePath);
      rethrow;
    } on DatabaseException catch (error) {
      await _imageStorage.deleteImage(newlyCopiedImagePath);
      throw _translateProductDatabaseError(error);
    } catch (_) {
      await _imageStorage.deleteImage(newlyCopiedImagePath);
      throw const MasterDataFailure(
        'Gagal mengubah produk. Silakan coba lagi.',
      );
    }
  }

  @override
  Future<void> deleteProduct(int id) async {
    try {
      // Soft delete: hanya mengubah is_deleted menjadi 1. Baris tetap ada
      // sehingga snapshot riwayat transaksi tidak kehilangan referensi.
      // File foto sengaja TIDAK dihapus agar data tetap bisa dipulihkan dan
      // tidak ada proses penghapusan file yang berisiko gagal di tengah jalan.
      final affected = await _productDataSource.softDelete(id);
      if (affected == 0) {
        throw const MasterDataFailure(
          'Produk tidak ditemukan atau sudah dihapus.',
          type: MasterDataFailureType.notFound,
        );
      }
    } on MasterDataFailure {
      rethrow;
    } catch (_) {
      throw const MasterDataFailure(
        'Gagal menghapus produk. Silakan coba lagi.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Add-on
  // ---------------------------------------------------------------------------

  @override
  Future<List<Addon>> getAddons() async {
    try {
      final models = await _addonDataSource.getActiveAddons();
      return models.map((model) => model.toEntity()).toList();
    } catch (_) {
      throw const MasterDataFailure(
        'Gagal memuat daftar add-on. Silakan coba lagi.',
      );
    }
  }

  @override
  Future<Addon> createAddon({
    required String name,
    required int price,
    required int stock,
  }) async {
    final normalizedName = _validatedName(name, label: 'Nama add-on');
    _validateAddonNumbers(price: price, stock: stock);

    try {
      if (await _addonDataSource.existsByName(normalizedName)) {
        throw MasterDataFailure(
          'Add-on "$normalizedName" sudah ada. Gunakan nama lain.',
          type: MasterDataFailureType.duplicateName,
        );
      }

      final createdAt = DateTime.now().toUtc();
      final id = await _addonDataSource.insert(
        AddonModel(
          name: normalizedName,
          price: price,
          stock: stock,
          createdAt: createdAt,
        ),
      );

      return Addon(
        id: id,
        name: normalizedName,
        price: price,
        stock: stock,
        createdAt: createdAt,
      );
    } on MasterDataFailure {
      rethrow;
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw MasterDataFailure(
          'Add-on "$normalizedName" sudah ada. Gunakan nama lain.',
          type: MasterDataFailureType.duplicateName,
        );
      }
      throw const MasterDataFailure(
        'Gagal menyimpan add-on. Silakan coba lagi.',
      );
    } catch (_) {
      throw const MasterDataFailure(
        'Gagal menyimpan add-on. Silakan coba lagi.',
      );
    }
  }

  @override
  Future<Addon> updateAddon({
    required int id,
    required String name,
    required int price,
    required int stock,
  }) async {
    final normalizedName = _validatedName(name, label: 'Nama add-on');
    _validateAddonNumbers(price: price, stock: stock);

    try {
      final existing = await _addonDataSource.findById(id);
      if (existing == null) {
        throw const MasterDataFailure(
          'Add-on tidak ditemukan. Mungkin sudah dihapus.',
          type: MasterDataFailureType.notFound,
        );
      }

      if (await _addonDataSource.existsByName(normalizedName, excludeId: id)) {
        throw MasterDataFailure(
          'Add-on "$normalizedName" sudah ada. Gunakan nama lain.',
          type: MasterDataFailureType.duplicateName,
        );
      }

      final affected = await _addonDataSource.updateById(id, {
        'name': normalizedName,
        'price': price,
        'stock': stock,
      });

      if (affected == 0) {
        throw const MasterDataFailure(
          'Add-on tidak ditemukan. Mungkin sudah dihapus.',
          type: MasterDataFailureType.notFound,
        );
      }

      return Addon(
        id: id,
        name: normalizedName,
        price: price,
        stock: stock,
        createdAt: existing.createdAt,
      );
    } on MasterDataFailure {
      rethrow;
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw MasterDataFailure(
          'Add-on "$normalizedName" sudah ada. Gunakan nama lain.',
          type: MasterDataFailureType.duplicateName,
        );
      }
      throw const MasterDataFailure(
        'Gagal mengubah add-on. Silakan coba lagi.',
      );
    } catch (_) {
      throw const MasterDataFailure(
        'Gagal mengubah add-on. Silakan coba lagi.',
      );
    }
  }

  @override
  Future<void> deleteAddon(int id) async {
    try {
      // Soft delete, sama seperti produk: add-on tetap tersimpan agar riwayat
      // transaksi yang memakainya tidak berubah.
      final affected = await _addonDataSource.softDelete(id);
      if (affected == 0) {
        throw const MasterDataFailure(
          'Add-on tidak ditemukan atau sudah dihapus.',
          type: MasterDataFailureType.notFound,
        );
      }
    } on MasterDataFailure {
      rethrow;
    } catch (_) {
      throw const MasterDataFailure(
        'Gagal menghapus add-on. Silakan coba lagi.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helper validasi & penerjemahan error
  // ---------------------------------------------------------------------------

  /// Memvalidasi nama dan mengembalikan versi yang sudah di-trim.
  String _validatedName(String value, {required String label}) {
    final error = MasterDataValidators.validateName(value, label: label);
    if (error != null) {
      throw MasterDataFailure(error, type: MasterDataFailureType.validation);
    }
    return value.trim();
  }

  /// Validasi angka produk pada level repository.
  ///
  /// Form sudah memvalidasi teks, tetapi repository menerima `int` sehingga
  /// perlu memastikan nilainya tetap wajar bila dipanggil dari tempat lain.
  String _validateProductInput({
    required String name,
    required int price,
    required int stock,
  }) {
    final normalizedName = _validatedName(name, label: 'Nama produk');

    if (price < 0) {
      throw const MasterDataFailure(
        'Harga jual tidak boleh negatif.',
        type: MasterDataFailureType.validation,
      );
    }
    if (price > MasterDataValidators.maxPrice) {
      throw const MasterDataFailure(
        'Harga jual maksimal Rp 1.000.000.000.',
        type: MasterDataFailureType.validation,
      );
    }
    if (stock < 0) {
      throw const MasterDataFailure(
        'Stok tidak boleh negatif.',
        type: MasterDataFailureType.validation,
      );
    }
    if (stock > MasterDataValidators.maxStock) {
      throw const MasterDataFailure(
        'Stok maksimal 1.000.000.',
        type: MasterDataFailureType.validation,
      );
    }

    return normalizedName;
  }

  /// Validasi harga & stok add-on.
  void _validateAddonNumbers({required int price, required int stock}) {
    if (price < 0) {
      throw const MasterDataFailure(
        'Harga add-on tidak boleh negatif.',
        type: MasterDataFailureType.validation,
      );
    }
    if (price > MasterDataValidators.maxPrice) {
      throw const MasterDataFailure(
        'Harga add-on maksimal Rp 1.000.000.000.',
        type: MasterDataFailureType.validation,
      );
    }
    if (stock < 0) {
      throw const MasterDataFailure(
        'Stok add-on tidak boleh negatif.',
        type: MasterDataFailureType.validation,
      );
    }
    if (stock > MasterDataValidators.maxStock) {
      throw const MasterDataFailure(
        'Stok add-on maksimal 1.000.000.',
        type: MasterDataFailureType.validation,
      );
    }
  }

  /// Menyusun pesan kategori terpakai sesuai kondisi produknya.
  ///
  /// Pesan dibedakan agar kasir paham mengapa kategori yang "sudah tidak
  /// terlihat di katalog" tetap tidak bisa dihapus.
  String _categoryInUseMessage({
    required String categoryName,
    required int activeProductCount,
    required int totalProductCount,
  }) {
    if (activeProductCount > 0) {
      return 'Kategori "$categoryName" masih digunakan oleh '
          '$activeProductCount produk aktif. Pindahkan produk tersebut ke '
          'kategori lain terlebih dahulu.';
    }

    return 'Kategori "$categoryName" masih terhubung dengan '
        '$totalProductCount produk yang sudah dihapus. Data ini dijaga agar '
        'riwayat transaksi tetap utuh, sehingga kategori belum bisa dihapus.';
  }

  /// Menerjemahkan error SQLite pada operasi produk menjadi pesan UI.
  MasterDataFailure _translateProductDatabaseError(DatabaseException error) {
    if (_isForeignKeyError(error)) {
      return const MasterDataFailure(
        'Kategori yang dipilih sudah tidak tersedia. Muat ulang daftar '
        'kategori lalu coba lagi.',
        type: MasterDataFailureType.validation,
      );
    }
    if (error.isUniqueConstraintError()) {
      return const MasterDataFailure(
        'Produk dengan data yang sama sudah ada.',
        type: MasterDataFailureType.duplicateName,
      );
    }
    return const MasterDataFailure(
      'Gagal menyimpan produk. Silakan coba lagi.',
    );
  }

  /// Mendeteksi pelanggaran FOREIGN KEY dari pesan/result code SQLite.
  ///
  /// sqflite belum menyediakan helper khusus seperti `isUniqueConstraintError`
  /// untuk foreign key, sehingga pengecekan dilakukan pada pesan error dan
  /// extended result code (787 = SQLITE_CONSTRAINT_FOREIGNKEY).
  bool _isForeignKeyError(DatabaseException error) {
    if (error.getResultCode() == _sqliteForeignKeyResultCode) return true;
    return error.toString().toLowerCase().contains(
      'foreign key constraint failed',
    );
  }
}
