/// Status umum pemuatan data master.
///
/// Dipakai ketiga Cubit (kategori, produk, add-on) agar UI dapat memakai pola
/// tampilan yang sama: spinner saat memuat, daftar saat siap, dan tombol coba
/// lagi saat gagal.
enum MasterDataStatus {
  /// Belum pernah memuat data.
  initial,

  /// Sedang membaca tabel dari SQLite.
  loading,

  /// Data berhasil dimuat (bisa saja daftarnya kosong).
  ready,

  /// Pemuatan gagal; pesan ada di `failure` pada state masing-masing.
  failure,
}
