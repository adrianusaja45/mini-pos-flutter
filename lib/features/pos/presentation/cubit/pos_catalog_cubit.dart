import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/pos_failure.dart';
import '../../domain/repositories/pos_repository.dart';
import 'pos_catalog_state.dart';

/// Cubit pemuat katalog kasir (produk + add-on).
///
/// Cubit ini hanya mengurus data **katalog**; isi keranjang dikelola
/// [CartCubit] secara terpisah. Pemisahan ini penting agar perubahan pada
/// keranjang (tambah/kurang quantity) tidak memicu query ulang ke SQLite.
class PosCatalogCubit extends Cubit<PosCatalogState> {
  PosCatalogCubit(this._repository) : super(const PosCatalogState());

  final PosRepository _repository;

  /// Memuat katalog dari database.
  ///
  /// Bila pemuatan sedang berjalan, permintaan baru diabaikan agar tombol
  /// "Coba Lagi" yang ditekan berulang tidak menumpuk query.
  Future<void> load() async {
    if (state.status == PosCatalogStatus.loading) return;

    emit(state.copyWith(status: PosCatalogStatus.loading, clearFailure: true));

    try {
      final catalog = await _repository.loadCatalog();
      emit(
        PosCatalogState(
          status: PosCatalogStatus.ready,
          products: catalog.products,
          addons: catalog.addons,
        ),
      );
    } on PosFailure catch (failure) {
      emit(state.copyWith(status: PosCatalogStatus.failure, failure: failure));
    } catch (_) {
      emit(
        state.copyWith(
          status: PosCatalogStatus.failure,
          failure: const PosFailure(
            'Gagal memuat katalog kasir. Silakan coba lagi.',
            type: PosFailureType.loadCatalog,
          ),
        ),
      );
    }
  }
}
