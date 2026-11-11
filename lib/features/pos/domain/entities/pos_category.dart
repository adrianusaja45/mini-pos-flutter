import 'package:equatable/equatable.dart';

/// Pilihan filter kategori pada katalog kasir.
///
/// Dibentuk dari produk yang berhasil dimuat, sehingga chip kategori hanya
/// menampilkan kategori yang benar-benar memiliki produk aktif. Ini mencegah
/// kasir memilih kategori kosong dan melihat layar tanpa hasil.
class PosCategory extends Equatable {
  const PosCategory({required this.id, required this.name});

  /// Primary key kategori (dipakai untuk mencocokkan `categoryId` produk).
  final int id;

  /// Nama kategori yang tampil pada chip.
  final String name;

  @override
  List<Object?> get props => [id, name];
}
