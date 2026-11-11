import 'package:equatable/equatable.dart';

import '../../domain/entities/product.dart';
import '../../domain/failures/master_data_failure.dart';
import 'master_data_status.dart';

/// State untuk daftar & operasi produk.
class ProductState extends Equatable {
  const ProductState({
    this.status = MasterDataStatus.initial,
    this.products = const <Product>[],
    this.isSaving = false,
    this.failure,
    this.notice,
  });

  final MasterDataStatus status;

  /// Produk aktif hasil query terakhir (belum termasuk yang soft delete).
  final List<Product> products;

  /// `true` selama proses simpan/hapus berjalan.
  final bool isSaving;

  final MasterDataFailure? failure;
  final String? notice;

  ProductState copyWith({
    MasterDataStatus? status,
    List<Product>? products,
    bool? isSaving,
    MasterDataFailure? failure,
    String? notice,
    bool clearFailure = false,
    bool clearNotice = false,
  }) {
    return ProductState(
      status: status ?? this.status,
      products: products ?? this.products,
      isSaving: isSaving ?? this.isSaving,
      failure: clearFailure ? null : (failure ?? this.failure),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }

  @override
  List<Object?> get props => [status, products, isSaving, failure, notice];
}
