import 'package:equatable/equatable.dart';

import '../../domain/entities/addon.dart';
import '../../domain/failures/master_data_failure.dart';
import 'master_data_status.dart';

/// State untuk daftar & operasi add-on.
class AddonState extends Equatable {
  const AddonState({
    this.status = MasterDataStatus.initial,
    this.addons = const <Addon>[],
    this.isSaving = false,
    this.failure,
    this.notice,
  });

  final MasterDataStatus status;

  /// Add-on aktif hasil query terakhir.
  final List<Addon> addons;

  /// `true` selama proses simpan/hapus berjalan.
  final bool isSaving;

  final MasterDataFailure? failure;
  final String? notice;

  AddonState copyWith({
    MasterDataStatus? status,
    List<Addon>? addons,
    bool? isSaving,
    MasterDataFailure? failure,
    String? notice,
    bool clearFailure = false,
    bool clearNotice = false,
  }) {
    return AddonState(
      status: status ?? this.status,
      addons: addons ?? this.addons,
      isSaving: isSaving ?? this.isSaving,
      failure: clearFailure ? null : (failure ?? this.failure),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }

  @override
  List<Object?> get props => [status, addons, isSaving, failure, notice];
}
