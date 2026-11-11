import '../entities/checkout_request.dart';
import '../entities/pos_catalog.dart';
import '../entities/transaction_receipt.dart';

/// Kontrak pengambilan data katalog dan penyimpanan transaksi untuk layar kasir.
///
/// Layer domain hanya tahu bahwa katalog bisa dimuat dan transaksi bisa
/// disimpan. Detail bahwa data berasal dari tabel `products`, `addons`,
/// `transactions`, dan tabel detailnya di SQLite berada di layer data.
/// Dengan pemisahan ini, Cubit dapat diuji memakai repository palsu.
abstract class PosRepository {
  /// Memuat produk aktif beserta seluruh add-on aktif dalam satu kali panggil.
  ///
  /// Melempar `PosFailure` bila katalog tidak bisa dibaca, sehingga UI dapat
  /// menampilkan pesan yang bisa dimengerti kasir.
  Future<PosCatalog> loadCatalog();

  /// Menyimpan satu transaksi penjualan secara **atomik**.
  ///
  /// Implementasi WAJIB menjalankan seluruh langkah (header, detail snapshot,
  /// pengurangan stok) di dalam satu `db.transaction`, sehingga kegagalan pada
  /// salah satu langkah membatalkan seluruh perubahan.
  ///
  /// Melempar `PosFailure` bila keranjang kosong, diskon tidak sah, uang tunai
  /// kurang, stok tidak mencukupi, atau sesi kasir tidak ditemukan.
  Future<TransactionReceipt> checkout(CheckoutRequest request);
}
