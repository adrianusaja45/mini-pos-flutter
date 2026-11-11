import '../../../../core/utils/currency_formatter.dart';
import '../entities/discount_type.dart';

/// Satu-satunya tempat perhitungan & validasi diskon di fitur POS.
///
/// Mengapa dipusatkan?
/// - Diskon dipakai di empat tempat berbeda: `CartState` (tampilan total),
///   `CartCubit` (validasi saat kasir menerapkan diskon), `DiscountSheet`
///   (pratinjau langsung), dan `PosRepositoryImpl` (pengaman terakhir sebelum
///   data ditulis ke SQLite).
/// - Bila rumusnya ditulis ulang di setiap tempat, sangat mudah muncul
///   perbedaan hasil (mis. satu tempat memakai pembulatan ke bawah, tempat lain
///   ke atas). Dengan satu kalkulator, seluruh layar menampilkan angka yang
///   sama dengan angka yang disimpan ke database.
///
/// ATURAN PROTEKSI DISKON (wajib dipenuhi):
/// 1. Diskon persentase tidak boleh melebihi 100%.
/// 2. Diskon nominal tidak boleh melebihi subtotal belanja.
/// 3. Nominal diskon yang benar-benar dipotong selalu dijepit pada rentang
///    `0 .. subtotal`, sehingga total tagihan TIDAK PERNAH minus.
class DiscountCalculator {
  // Konstruktor privat: kelas ini hanya berisi fungsi statis.
  const DiscountCalculator._();

  /// Batas maksimum diskon persentase.
  static const int maxPercentage = 100;

  /// Menghitung nominal diskon (Rupiah) yang benar-benar dipotong.
  ///
  /// Nilai balik dijamin berada di antara `0` dan [subtotal]. Penjepitan ini
  /// adalah jaring pengaman terakhir: walaupun ada pemanggil yang mengirim
  /// nilai tidak wajar (mis. nominal lebih besar dari subtotal), total tagihan
  /// tetap tidak mungkin minus.
  static int amount({
    required int subtotal,
    required DiscountType type,
    required int value,
  }) {
    // Tanpa item / tanpa diskon -> tidak ada potongan sama sekali.
    if (type == DiscountType.none || value <= 0 || subtotal <= 0) return 0;

    switch (type) {
      case DiscountType.none:
        return 0;

      case DiscountType.percentage:
        // Persentase di atas 100 tetap diperlakukan sebagai 100% agar hasil
        // perhitungan tidak pernah melebihi subtotal, meskipun validasi input
        // seharusnya sudah menolaknya lebih dulu.
        final percent = value > maxPercentage ? maxPercentage : value;
        final raw = (subtotal * percent / 100).round();
        // Pembulatan bisa menghasilkan angka 1 Rupiah di atas subtotal pada
        // kasus ekstrem, jadi hasil akhir tetap dijepit.
        if (raw > subtotal) return subtotal;
        return raw < 0 ? 0 : raw;

      case DiscountType.nominal:
        // Nominal tidak boleh melebihi subtotal: kelebihan dipotong (dijepit),
        // bukan dibiarkan menghasilkan total negatif.
        return value > subtotal ? subtotal : value;
    }
  }

  /// Total tagihan setelah diskon. Selalu `>= 0`.
  static int total({
    required int subtotal,
    required DiscountType type,
    required int value,
  }) {
    final total = subtotal - amount(subtotal: subtotal, type: type, value: value);
    // Pengaman ganda: secara matematis hasil di atas tidak pernah negatif,
    // tetapi pengecekan eksplisit membuat aturan bisnis ini terbaca jelas.
    return total < 0 ? 0 : total;
  }

  /// Memvalidasi input diskon sebelum diterapkan.
  ///
  /// Mengembalikan pesan kesalahan yang siap ditampilkan ke kasir, atau `null`
  /// bila input sah. Dipakai oleh UI (menonaktifkan tombol "Terapkan") dan oleh
  /// `CartCubit` (menolak perubahan state), sehingga kasir tidak pernah melihat
  /// tombol aktif untuk nilai yang pasti ditolak.
  static String? validate({
    required int subtotal,
    required DiscountType type,
    required int value,
  }) {
    // Jenis "none" berarti kasir menghapus diskon; selalu sah.
    if (type == DiscountType.none) return null;

    if (subtotal <= 0) {
      return 'Tambahkan item ke keranjang sebelum memberi diskon.';
    }

    if (value < 0) {
      return 'Nilai diskon tidak boleh negatif.';
    }

    // Nilai 0 diperlakukan sebagai "tidak ada diskon", bukan kesalahan.
    if (value == 0) return null;

    if (type == DiscountType.percentage && value > maxPercentage) {
      return 'Diskon persentase tidak boleh melebihi $maxPercentage%. '
          'Nilai yang dimasukkan $value%.';
    }

    if (type == DiscountType.nominal && value > subtotal) {
      return 'Diskon nominal ${formatRupiah(value)} tidak boleh melebihi '
          'subtotal belanja ${formatRupiah(subtotal)}.';
    }

    return null;
  }
}
