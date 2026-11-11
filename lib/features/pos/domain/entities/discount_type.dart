/// Jenis diskon yang bisa diterapkan pada satu transaksi.
///
/// Nilai enum sengaja dipisahkan dari string yang disimpan di SQLite. Dengan
/// begitu kode Dart aman dari salah ketik, sedangkan isi database tetap berupa
/// teks yang mudah dibaca saat diperiksa manual (lihat [storageValue]).
enum DiscountType {
  /// Tidak ada diskon (default keranjang).
  none,

  /// Potongan nominal Rupiah langsung, mis. Rp 5.000.
  nominal,

  /// Potongan persentase dari subtotal, rentang 0 - 100.
  percentage;

  /// Nilai teks yang disimpan di kolom `transactions.discount_type`.
  ///
  /// Harus sama persis dengan `DiscountType` pada `core/database/db_constants`
  /// karena kolom tersebut memiliki `CHECK` constraint.
  String get storageValue {
    switch (this) {
      case DiscountType.none:
        return 'none';
      case DiscountType.nominal:
        return 'nominal';
      case DiscountType.percentage:
        return 'percentage';
    }
  }

  /// Label singkat untuk tombol pilihan di UI.
  String get label {
    switch (this) {
      case DiscountType.none:
        return 'Tanpa diskon';
      case DiscountType.nominal:
        return 'Nominal (Rp)';
      case DiscountType.percentage:
        return 'Persentase (%)';
    }
  }

  /// Mengubah nilai kolom database kembali menjadi enum.
  ///
  /// Nilai tak dikenal diperlakukan sebagai [none] agar pembacaan data lama
  /// atau data yang rusak tidak membuat aplikasi berhenti.
  static DiscountType fromStorage(String? value) {
    switch (value) {
      case 'nominal':
        return DiscountType.nominal;
      case 'percentage':
        return DiscountType.percentage;
      default:
        return DiscountType.none;
    }
  }
}
