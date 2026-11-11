import 'package:intl/intl.dart';

/// Formatter uang Rupiah yang dipakai bersama oleh seluruh fitur.
///
/// Mengapa dipusatkan di `core`?
/// - Seluruh nominal di database disimpan sebagai INTEGER Rupiah tanpa sen,
///   sehingga tampilan cukup memakai satu pola format yang sama.
/// - Bila suatu saat format ingin diubah (mis. memakai pemisah ribuan titik),
///   cukup ubah file ini dan semua halaman ikut menyesuaikan.
///
/// Objek [NumberFormat] dibuat sekali (bukan setiap pemanggilan) karena proses
/// pembuatan formatter relatif mahal bila dilakukan berulang di dalam
/// `build()` sebuah list panjang.
final NumberFormat _rupiahNumberFormat = NumberFormat.decimalPattern('id_ID');

/// Mengubah angka Rupiah menjadi teks siap tampil, contoh: `25000` -> `Rp 25.000`.
///
/// Tidak memakai `NumberFormat.currency` agar simbol "Rp" dan spasinya
/// konsisten di semua platform (beberapa locale menambahkan spasi khusus).
String formatRupiah(int amount) {
  return 'Rp ${_rupiahNumberFormat.format(amount)}';
}
