import '../entities/pos_catalog.dart';

/// Kontrak pengambilan data katalog untuk layar kasir.
///
/// Layer domain hanya tahu bahwa katalog bisa dimuat. Detail bahwa data
/// berasal dari tabel `products` & `addons` SQLite berada di layer data.
/// Dengan pemisahan ini, Cubit katalog dapat diuji memakai repository palsu.
abstract class PosRepository {
  /// Memuat produk aktif beserta seluruh add-on aktif dalam satu kali panggil.
  ///
  /// Melempar `PosFailure` bila katalog tidak bisa dibaca, sehingga UI dapat
  /// menampilkan pesan yang bisa dimengerti kasir.
  Future<PosCatalog> loadCatalog();
}
