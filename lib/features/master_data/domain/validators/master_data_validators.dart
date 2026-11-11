/// Aturan validasi form master data yang dipakai bersama oleh UI dan repository.
///
/// Sama seperti `AuthValidators`, validasi dipusatkan agar:
/// - form menampilkan pesan error langsung saat kasir mengetik, dan
/// - repository tetap menolak data tidak valid walaupun nantinya ada halaman
///   lain yang memanggil repository tanpa lewat form.
class MasterDataValidators {
  // Kelas aturan: tidak perlu dibuat menjadi objek.
  const MasterDataValidators._();

  /// Panjang minimal nama kategori/produk/add-on.
  static const int nameMinLength = 2;

  /// Panjang maksimal nama agar tetap rapi di daftar maupun struk.
  static const int nameMaxLength = 60;

  /// Batas atas harga yang wajar dimasukkan (Rp 1 miliar).
  ///
  /// Tujuannya mencegah salah ketik ekstrem (mis. menekan angka 0 terlalu
  /// banyak) yang membuat laporan penjualan tidak realistis.
  static const int maxPrice = 1000000000;

  /// Batas atas stok agar nilai tetap masuk akal untuk toko kecil.
  static const int maxStock = 1000000;

  /// Pola angka bulat tanpa tanda minus/titik, sesuai input Rupiah & stok.
  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  /// Validasi nama kategori, produk, atau add-on.
  ///
  /// [label] dipakai agar pesan error menyebut field yang benar, misal
  /// "Nama kategori wajib diisi." atau "Nama produk wajib diisi.".
  static String? validateName(String? value, {String label = 'Nama'}) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return '$label wajib diisi.';
    }
    if (name.length < nameMinLength) {
      return '$label minimal $nameMinLength karakter.';
    }
    if (name.length > nameMaxLength) {
      return '$label maksimal $nameMaxLength karakter.';
    }
    return null;
  }

  /// Validasi harga jual / harga tambahan (Rupiah utuh).
  static String? validatePrice(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Harga wajib diisi.';
    }
    if (!_digitsOnly.hasMatch(text)) {
      return 'Harga hanya boleh berisi angka (tanpa titik/koma).';
    }
    final price = int.tryParse(text);
    if (price == null) {
      return 'Harga tidak valid.';
    }
    if (price > maxPrice) {
      return 'Harga maksimal Rp 1.000.000.000.';
    }
    return null;
  }

  /// Validasi jumlah stok.
  static String? validateStock(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Stok wajib diisi (isi 0 bila belum ada barang).';
    }
    if (!_digitsOnly.hasMatch(text)) {
      return 'Stok hanya boleh berisi angka bulat.';
    }
    final stock = int.tryParse(text);
    if (stock == null) {
      return 'Stok tidak valid.';
    }
    if (stock > maxStock) {
      return 'Stok maksimal $maxStock.';
    }
    return null;
  }

  /// Mengubah teks harga menjadi angka.
  ///
  /// Mengembalikan `null` bila teks bukan angka; pemanggil wajib memvalidasi
  /// lebih dulu melalui [validatePrice].
  static int? parsePrice(String? value) => int.tryParse(value?.trim() ?? '');

  /// Mengubah teks stok menjadi angka (lihat catatan pada [parsePrice]).
  static int? parseStock(String? value) => int.tryParse(value?.trim() ?? '');
}
