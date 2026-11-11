import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/product.dart';
import '../../domain/failures/master_data_failure.dart';
import '../../domain/repositories/master_data_repository.dart';
import 'master_data_status.dart';
import 'product_state.dart';

/// Cubit pengelola master produk, termasuk penyimpanan foto permanen.
///
/// Cubit **tidak** menyentuh file secara langsung. Ia hanya meneruskan path
/// sementara hasil image_picker ke repository; repository yang menyalin file
/// ke Application Documents Directory lalu menyimpan path permanennya ke
/// SQLite. Pemisahan ini membuat UI tetap ringkas dan mudah diuji.
class ProductCubit extends Cubit<ProductState> {
  ProductCubit(this._repository) : super(const ProductState());

  final MasterDataRepository _repository;

  /// Membaca produk aktif (belum di-soft-delete) dari SQLite.
  Future<void> load() async {
    if (state.status == MasterDataStatus.loading) return;

    emit(
      state.copyWith(
        status: MasterDataStatus.loading,
        clearFailure: true,
        clearNotice: true,
      ),
    );

    try {
      final products = await _repository.getProducts();
      emit(ProductState(status: MasterDataStatus.ready, products: products));
    } on MasterDataFailure catch (failure) {
      emit(state.copyWith(status: MasterDataStatus.failure, failure: failure));
    } catch (_) {
      emit(
        state.copyWith(
          status: MasterDataStatus.failure,
          failure: const MasterDataFailure(
            'Gagal memuat daftar produk. Silakan coba lagi.',
          ),
        ),
      );
    }
  }

  /// Menambah produk baru.
  ///
  /// [photoSourcePath] adalah path sementara dari kamera/galeri. Bila diisi,
  /// repository akan menyalinnya ke folder permanen sebelum INSERT.
  Future<bool> createProduct({
    required int categoryId,
    required String name,
    required int price,
    required int stock,
    String? photoSourcePath,
  }) async {
    return _runMutation(
      action: () => _repository.createProduct(
        categoryId: categoryId,
        name: name,
        price: price,
        stock: stock,
        photoSourcePath: photoSourcePath,
      ),
      successNotice: (product) =>
          'Produk "${product.name}" berhasil ditambahkan.',
    );
  }

  /// Mengubah produk, termasuk mengganti atau menghapus fotonya.
  Future<bool> updateProduct({
    required int id,
    required int categoryId,
    required String name,
    required int price,
    required int stock,
    String? photoSourcePath,
    bool removePhoto = false,
  }) async {
    return _runMutation(
      action: () => _repository.updateProduct(
        id: id,
        categoryId: categoryId,
        name: name,
        price: price,
        stock: stock,
        photoSourcePath: photoSourcePath,
        removePhoto: removePhoto,
      ),
      successNotice: (product) =>
          'Produk "${product.name}" berhasil diperbarui.',
    );
  }

  /// Soft delete produk agar riwayat transaksi tetap aman.
  Future<bool> deleteProduct(int id) async {
    return _runMutation<Product?>(
      action: () async {
        await _repository.deleteProduct(id);
        return null;
      },
      successNotice: (_) =>
          'Produk dihapus dari katalog. Riwayat transaksi tetap tersimpan.',
    );
  }

  /// Menjalankan operasi tulis lalu memuat ulang daftar produk.
  Future<bool> _runMutation<T>({
    required Future<T> Function() action,
    required String Function(T result) successNotice,
  }) async {
    if (state.isSaving) return false;

    emit(state.copyWith(isSaving: true, clearFailure: true, clearNotice: true));

    try {
      final result = await action();

      List<Product> products;
      try {
        products = await _repository.getProducts();
      } catch (_) {
        // Tulis sudah berhasil; pertahankan daftar lama bila reload gagal.
        products = state.products;
      }

      emit(
        ProductState(
          status: MasterDataStatus.ready,
          products: products,
          notice: successNotice(result),
        ),
      );
      return true;
    } on MasterDataFailure catch (failure) {
      emit(state.copyWith(isSaving: false, failure: failure));
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isSaving: false,
          failure: const MasterDataFailure(
            'Terjadi kesalahan saat memproses produk. Silakan coba lagi.',
          ),
        ),
      );
      return false;
    }
  }

  void clearFailure() {
    if (state.failure != null) {
      emit(state.copyWith(clearFailure: true));
    }
  }

  void clearNotice() {
    if (state.notice != null) {
      emit(state.copyWith(clearNotice: true));
    }
  }
}
