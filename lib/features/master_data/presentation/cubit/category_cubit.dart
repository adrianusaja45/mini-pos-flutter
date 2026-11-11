import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/category.dart';
import '../../domain/failures/master_data_failure.dart';
import '../../domain/repositories/master_data_repository.dart';
import 'category_state.dart';
import 'master_data_status.dart';

/// Cubit pengelola kategori produk.
///
/// Alur umum setiap operasi:
/// UI -> Cubit -> Repository -> SQLite, lalu Cubit memuat ulang daftar agar
/// jumlah produk per kategori dan urutan abjad selalu akurat.
class CategoryCubit extends Cubit<CategoryState> {
  CategoryCubit(this._repository) : super(const CategoryState());

  final MasterDataRepository _repository;

  /// Membaca seluruh kategori dari SQLite.
  Future<void> load() async {
    // Mencegah query ganda saat tombol "coba lagi" ditekan berulang.
    if (state.status == MasterDataStatus.loading) return;

    emit(
      state.copyWith(
        status: MasterDataStatus.loading,
        clearFailure: true,
        clearNotice: true,
      ),
    );

    try {
      final categories = await _repository.getCategories();
      emit(
        CategoryState(status: MasterDataStatus.ready, categories: categories),
      );
    } on MasterDataFailure catch (failure) {
      emit(state.copyWith(status: MasterDataStatus.failure, failure: failure));
    } catch (_) {
      emit(
        state.copyWith(
          status: MasterDataStatus.failure,
          failure: const MasterDataFailure(
            'Gagal memuat daftar kategori. Silakan coba lagi.',
          ),
        ),
      );
    }
  }

  /// Menambah kategori baru.
  ///
  /// Mengembalikan `true` bila berhasil, sehingga form bisa menutup diri.
  Future<bool> createCategory(String name) async {
    return _runMutation(
      action: () => _repository.createCategory(name),
      successNotice: (category) =>
          'Kategori "${category.name}" berhasil ditambahkan.',
    );
  }

  /// Mengubah nama kategori.
  Future<bool> updateCategory({required int id, required String name}) async {
    return _runMutation(
      action: () => _repository.updateCategory(id: id, name: name),
      successNotice: (category) =>
          'Kategori "${category.name}" berhasil diperbarui.',
    );
  }

  /// Menghapus kategori.
  ///
  /// Bila kategori masih dipakai produk, repository melempar
  /// `MasterDataFailure` bertipe `categoryInUse`; UI akan menampilkan dialog
  /// penjelasan (bukan sekadar error teknis).
  Future<bool> deleteCategory(int id) async {
    return _runMutation<Category?>(
      action: () async {
        await _repository.deleteCategory(id);
        return null;
      },
      successNotice: (_) => 'Kategori berhasil dihapus.',
    );
  }

  /// Menjalankan operasi tulis lalu memuat ulang daftar.
  ///
  /// [successNotice] menerima objek hasil operasi untuk menyusun pesan sukses.
  Future<bool> _runMutation<T>({
    required Future<T> Function() action,
    required String Function(T result) successNotice,
  }) async {
    if (state.isSaving) return false;

    emit(state.copyWith(isSaving: true, clearFailure: true, clearNotice: true));

    try {
      final result = await action();

      // Muat ulang dari database supaya data yang tampil benar-benar berasal
      // dari SQLite (termasuk product_count terbaru).
      List<Category> categories;
      try {
        categories = await _repository.getCategories();
      } catch (_) {
        // Operasi tulis sudah sukses; bila muat ulang gagal, daftar lama
        // dipertahankan agar UI tidak menampilkan layar error.
        categories = state.categories;
      }

      emit(
        CategoryState(
          status: MasterDataStatus.ready,
          categories: categories,
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
            'Terjadi kesalahan saat memproses kategori. Silakan coba lagi.',
          ),
        ),
      );
      return false;
    }
  }

  /// Menghapus pesan kegagalan setelah ditampilkan UI.
  void clearFailure() {
    if (state.failure != null) {
      emit(state.copyWith(clearFailure: true));
    }
  }

  /// Menghapus pesan sukses setelah snackbar tampil.
  void clearNotice() {
    if (state.notice != null) {
      emit(state.copyWith(clearNotice: true));
    }
  }
}
