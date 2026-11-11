/// Helper kecil untuk membaca nilai kolom SQLite dengan aman.
///
/// SQLite (lewat sqflite) mengembalikan `int`, `double`, `String`, atau `null`.
/// Casting langsung seperti `map['price'] as int` bisa melempar error bila
/// suatu saat nilainya tersimpan sebagai `double`. Helper ini membuat model
/// tetap tahan terhadap variasi tersebut.
library;

/// Membaca tanggal ISO-8601 dan mengubahnya menjadi UTC.
///
/// Bila data lama rusak, dipakai waktu epoch agar aplikasi tidak crash saat
/// membaca tabel.
DateTime parseUtcDate(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

/// Membaca angka bulat dengan nilai cadangan bila kosong/tidak valid.
int parseInteger(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// Membaca kolom SQLite yang menyimpan boolean sebagai 0/1.
bool parseBool(Object? value) => parseInteger(value) == 1;
