import '../../../master_data/domain/failures/master_data_failure.dart';
import '../../../master_data/domain/repositories/master_data_repository.dart';
import '../../domain/entities/pos_addon.dart';
import '../../domain/entities/pos_catalog.dart';
import '../../domain/entities/pos_product.dart';
import '../../domain/failures/pos_failure.dart';
import '../../domain/repositories/pos_repository.dart';

/// Implementasi [PosRepository] yang memanfaatkan repository master data.
///
/// Mengapa tidak membuat query SQL baru?
/// - `MasterDataRepository` sudah menjadi satu-satunya pintu baca tabel
///   `products` dan `addons` (termasuk filter `is_deleted = 0`).
/// - Dengan memakai ulang repository tersebut, aturan soft delete dan JOIN
///   kategori tidak ditulis dua kali sehingga tidak ada risiko query yang
///   berbeda hasilnya antar fitur.
///
/// Di sinilah entity master data dipetakan menjadi entity POS yang ringkas.
class PosRepositoryImpl implements PosRepository {
  PosRepositoryImpl(this._masterDataRepository);

  final MasterDataRepository _masterDataRepository;

  @override
  Future<PosCatalog> loadCatalog() async {
    try {
      // Kedua future dimulai bersamaan agar produk dan add-on tidak dimuat
      // bergantian (lebih cepat, terutama saat data cukup banyak).
      final productsFuture = _masterDataRepository.getProducts();
      final addonsFuture = _masterDataRepository.getAddons();

      final products = await productsFuture;
      final addons = await addonsFuture;

      return PosCatalog(
        products: products
            .map(
              (product) => PosProduct(
                id: product.id,
                categoryId: product.categoryId,
                categoryName: product.categoryName,
                name: product.name,
                price: product.price,
                stock: product.stock,
                imagePath: product.imagePath,
              ),
            )
            .toList(growable: false),
        addons: addons
            .map(
              (addon) => PosAddon(
                id: addon.id,
                name: addon.name,
                price: addon.price,
                stock: addon.stock,
              ),
            )
            .toList(growable: false),
      );
    } on MasterDataFailure catch (failure) {
      // Pesan master data sudah ramah pengguna; cukup dibungkus menjadi
      // PosFailure agar tipe kegagalan sesuai konteks layar kasir.
      throw PosFailure(failure.message, type: PosFailureType.loadCatalog);
    } catch (_) {
      throw const PosFailure(
        'Gagal memuat katalog kasir. Silakan coba lagi.',
        type: PosFailureType.loadCatalog,
      );
    }
  }
}
