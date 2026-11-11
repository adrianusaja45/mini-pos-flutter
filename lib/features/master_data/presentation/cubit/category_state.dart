import 'package:equatable/equatable.dart';

import '../../domain/entities/category.dart';
import '../../domain/failures/master_data_failure.dart';
import 'master_data_status.dart';

/// State untuk daftar & operasi kategori.
class CategoryState extends Equatable {
  const CategoryState({
    this.status = MasterDataStatus.initial,
    this.categories = const <Category>[],
    this.isSaving = false,
    this.failure,
    this.notice,
  });

  /// Status pemuatan daftar.
  final MasterDataStatus status;

  /// Kategori hasil query terakhir.
  final List<Category> categories;

  /// `true` selama proses tambah/ubah/hapus berjalan (tombol dinonaktifkan).
  final bool isSaving;

  /// Kegagalan terakhir yang perlu ditampilkan (snackbar/dialog/banner).
  final MasterDataFailure? failure;

  /// Pesan sukses sekali tampil (mis. "Kategori berhasil ditambahkan").
  final String? notice;

  /// Salinan state dengan sebagian nilai diganti.
  ///
  /// [clearFailure] dan [clearNotice] dipakai karena `null` tidak bisa
  /// dibedakan dari "tidak diubah" bila hanya memakai parameter nullable.
  CategoryState copyWith({
    MasterDataStatus? status,
    List<Category>? categories,
    bool? isSaving,
    MasterDataFailure? failure,
    String? notice,
    bool clearFailure = false,
    bool clearNotice = false,
  }) {
    return CategoryState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      isSaving: isSaving ?? this.isSaving,
      failure: clearFailure ? null : (failure ?? this.failure),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }

  @override
  List<Object?> get props => [status, categories, isSaving, failure, notice];
}
