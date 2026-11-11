import '../entities/addon.dart';
import '../entities/category.dart';
import '../entities/product.dart';

/// Kontrak seluruh operasi master data (kategori, produk, add-on).
///
/// Layer domain hanya mendefinisikan **apa** yang bisa dilakukan aplikasi.
/// Implementasi SQLite berada di `MasterDataRepositoryImpl` pada layer data.
/// Dengan pemisahan ini, Cubit dapat diuji memakai repository palsu tanpa
/// membuka database atau menyentuh file foto.
///
/// Semua method melempar `MasterDataFailure` (bukan exception mentah) bila
/// terjadi kesalahan yang bisa dijelaskan ke kasir.
abstract class MasterDataRepository {
  // ---------------------------------------------------------------------------
  // Kategori
  // ---------------------------------------------------------------------------

  /// Mengambil seluruh kategori beserta jumlah produk aktifnya.
  Future<List<Category>> getCategories();

  /// Menambah kategori baru. Nama duplikat ditolak.
  Future<Category> createCategory(String name);

  /// Mengubah nama kategori.
  Future<Category> updateCategory({required int id, required String name});

  /// Menghapus kategori.
  ///
  /// Melempar `MasterDataFailure` bertipe `categoryInUse` bila kategori masih
  /// dirujuk produk, sesuai aturan FOREIGN KEY `ON DELETE RESTRICT`.
  Future<void> deleteCategory(int id);

  // ---------------------------------------------------------------------------
  // Produk
  // ---------------------------------------------------------------------------

  /// Mengambil produk yang belum di-soft-delete, lengkap dengan nama kategori.
  Future<List<Product>> getProducts();

  /// Menambah produk baru.
  ///
  /// [photoSourcePath] adalah path **sementara** hasil image_picker. Repository
  /// akan menyalinnya ke Application Documents Directory sebelum menyimpan
  /// baris SQLite, sehingga yang tercatat adalah path permanen.
  Future<Product> createProduct({
    required int categoryId,
    required String name,
    required int price,
    required int stock,
    String? photoSourcePath,
  });

  /// Mengubah produk.
  ///
  /// [photoSourcePath] diisi bila kasir memilih foto baru. [removePhoto] diisi
  /// `true` bila kasir ingin menghapus foto tanpa menggantinya.
  Future<Product> updateProduct({
    required int id,
    required int categoryId,
    required String name,
    required int price,
    required int stock,
    String? photoSourcePath,
    bool removePhoto = false,
  });

  /// Menghapus produk secara **soft delete** (`is_deleted = 1`).
  ///
  /// Baris tidak dihapus fisik agar riwayat transaksi yang merujuk produk ini
  /// tetap valid.
  Future<void> deleteProduct(int id);

  // ---------------------------------------------------------------------------
  // Add-on
  // ---------------------------------------------------------------------------

  /// Mengambil add-on yang belum di-soft-delete.
  Future<List<Addon>> getAddons();

  /// Menambah add-on baru. Nama duplikat ditolak.
  Future<Addon> createAddon({
    required String name,
    required int price,
    required int stock,
  });

  /// Mengubah data add-on.
  Future<Addon> updateAddon({
    required int id,
    required String name,
    required int price,
    required int stock,
  });

  /// Menghapus add-on secara soft delete (`is_deleted = 1`).
  Future<void> deleteAddon(int id);
}
