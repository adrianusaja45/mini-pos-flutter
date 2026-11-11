import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/addon.dart';
import '../../domain/failures/master_data_failure.dart';
import '../../domain/repositories/master_data_repository.dart';
import 'addon_state.dart';
import 'master_data_status.dart';

/// Cubit pengelola master add-on (topping/tambahan).
///
/// Sama seperti produk, penghapusan memakai soft delete agar riwayat transaksi
/// yang memakai add-on ini tetap utuh.
class AddonCubit extends Cubit<AddonState> {
  AddonCubit(this._repository) : super(const AddonState());

  final MasterDataRepository _repository;

  /// Membaca add-on aktif dari SQLite.
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
      final addons = await _repository.getAddons();
      emit(AddonState(status: MasterDataStatus.ready, addons: addons));
    } on MasterDataFailure catch (failure) {
      emit(state.copyWith(status: MasterDataStatus.failure, failure: failure));
    } catch (_) {
      emit(
        state.copyWith(
          status: MasterDataStatus.failure,
          failure: const MasterDataFailure(
            'Gagal memuat daftar add-on. Silakan coba lagi.',
          ),
        ),
      );
    }
  }

  /// Menambah add-on baru.
  Future<bool> createAddon({
    required String name,
    required int price,
    required int stock,
  }) async {
    return _runMutation(
      action: () =>
          _repository.createAddon(name: name, price: price, stock: stock),
      successNotice: (addon) => 'Add-on "${addon.name}" berhasil ditambahkan.',
    );
  }

  /// Mengubah data add-on.
  Future<bool> updateAddon({
    required int id,
    required String name,
    required int price,
    required int stock,
  }) async {
    return _runMutation(
      action: () => _repository.updateAddon(
        id: id,
        name: name,
        price: price,
        stock: stock,
      ),
      successNotice: (addon) => 'Add-on "${addon.name}" berhasil diperbarui.',
    );
  }

  /// Soft delete add-on.
  Future<bool> deleteAddon(int id) async {
    return _runMutation<Addon?>(
      action: () async {
        await _repository.deleteAddon(id);
        return null;
      },
      successNotice: (_) =>
          'Add-on dihapus dari katalog. Riwayat transaksi tetap tersimpan.',
    );
  }

  /// Menjalankan operasi tulis lalu memuat ulang daftar add-on.
  Future<bool> _runMutation<T>({
    required Future<T> Function() action,
    required String Function(T result) successNotice,
  }) async {
    if (state.isSaving) return false;

    emit(state.copyWith(isSaving: true, clearFailure: true, clearNotice: true));

    try {
      final result = await action();

      List<Addon> addons;
      try {
        addons = await _repository.getAddons();
      } catch (_) {
        // Tulis sudah berhasil; pertahankan daftar lama bila reload gagal.
        addons = state.addons;
      }

      emit(
        AddonState(
          status: MasterDataStatus.ready,
          addons: addons,
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
            'Terjadi kesalahan saat memproses add-on. Silakan coba lagi.',
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
