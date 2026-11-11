import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/failures/master_data_failure.dart';

/// Pengelola file foto produk agar tersimpan **permanen** di perangkat.
///
/// Mengapa foto perlu disalin, bukan sekadar menyimpan path dari image_picker?
/// 1. `image_picker` mengembalikan file di cache sementara. Android/iOS (dan
///    pembersih cache sistem) boleh menghapus file itu kapan saja.
/// 2. Bila yang disimpan ke SQLite adalah path cache, foto produk akan hilang
///    setelah aplikasi di-restart atau penyimpanan dibersihkan.
///
/// Solusinya: file disalin (`File.copy`) ke subfolder `product_images` di
/// dalam Application Documents Directory, diberi nama unik UUID agar tidak
/// bentrok, lalu **path permanen** itulah yang disimpan di kolom
/// `products.image_path`.
///
/// Catatan: file sumber tidak dipindahkan (`rename`) karena file tersebut
/// dimiliki plugin kamera/galeri; menyalin lebih aman dan tidak mengganggu
/// mekanisme internal plugin.
class ProductImageStorage {
  ProductImageStorage({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  /// Provider direktori dokumen aplikasi.
  ///
  /// Bisa diganti saat pengujian unit dengan direktori sementara, sehingga
  /// test tidak menulis ke folder dokumen pengguna.
  final Future<Directory> Function() _documentsDirectoryProvider;

  /// Nama subfolder tempat seluruh foto produk disimpan.
  static const String folderName = 'product_images';

  /// Pola ekstensi file yang diizinkan (mis. `.jpg`, `.jpeg`, `.png`).
  static final RegExp _safeExtensionPattern = RegExp(r'^\.[a-z0-9]{1,5}$');

  /// Menyalin foto dari [sourcePath] ke direktori permanen aplikasi.
  ///
  /// Mengembalikan **path absolut file hasil salinan** yang siap disimpan ke
  /// SQLite. Bila file sumber ternyata sudah berada di folder permanen kita
  /// (misalnya saat edit produk tanpa mengganti foto), file tidak disalin
  /// ulang agar tidak terjadi duplikasi.
  Future<String> persistImage(String sourcePath) async {
    final sourceFile = File(sourcePath);

    try {
      if (!await sourceFile.exists()) {
        throw const MasterDataFailure(
          'File foto tidak ditemukan. Silakan pilih foto ulang.',
          type: MasterDataFailureType.validation,
        );
      }

      final documentsDirectory = await _documentsDirectoryProvider();
      final imageDirectory = Directory(
        p.join(documentsDirectory.path, folderName),
      );

      // Folder dibuat bila belum ada. `recursive: true` aman dipanggil
      // berulang dan tidak error jika folder sudah tersedia.
      if (!await imageDirectory.exists()) {
        await imageDirectory.create(recursive: true);
      }

      final normalizedSource = p.normalize(sourceFile.absolute.path);
      final normalizedDirectory = p.normalize(imageDirectory.absolute.path);

      // File sudah permanen: tidak perlu disalin, cukup kembalikan path-nya.
      if (p.isWithin(normalizedDirectory, normalizedSource)) {
        return normalizedSource;
      }

      // Nama unik memakai UUID v4 sehingga dua foto yang diambil berdekatan
      // tidak akan saling menimpa. Ekstensi dipertahankan agar decoder gambar
      // mengenali format file dengan benar.
      final fileName = '${const Uuid().v4()}${_safeExtension(sourceFile.path)}';
      final destinationPath = p.join(imageDirectory.path, fileName);

      // Inti mekanisme offline photo persistence: salin byte file ke path
      // permanen. Setelah baris ini, foto aman meskipun cache sistem dibersihkan.
      await sourceFile.copy(destinationPath);

      return destinationPath;
    } on MasterDataFailure {
      // Pesan bisnis (mis. file tidak ditemukan) diteruskan apa adanya.
      rethrow;
    } catch (_) {
      // Error I/O (disk penuh, izin ditolak, dsb.) diterjemahkan menjadi pesan
      // yang bisa dipahami kasir, tanpa membocorkan detail teknis.
      throw const MasterDataFailure(
        'Gagal menyimpan foto produk ke penyimpanan aplikasi. '
        'Periksa ruang penyimpanan lalu coba lagi.',
      );
    }
  }

  /// Menghapus file foto lama dari folder permanen aplikasi.
  ///
  /// Dipakai saat foto produk diganti. Penghapusan sengaja dibatasi hanya pada
  /// file di dalam folder `product_images` agar path dari luar (mis. file
  /// pilihan pengguna) tidak ikut terhapus.
  ///
  /// Kegagalan menghapus tidak dilempar ke pemanggil karena operasi utama
  /// (simpan produk) sudah berhasil; paling buruk hanya menyisakan file yatim.
  Future<void> deleteImage(String? path) async {
    if (path == null || path.trim().isEmpty) return;

    try {
      final documentsDirectory = await _documentsDirectoryProvider();
      final normalizedDirectory = p.normalize(
        p.join(documentsDirectory.path, folderName),
      );
      final normalizedTarget = p.normalize(File(path).absolute.path);

      if (!p.isWithin(normalizedDirectory, normalizedTarget)) {
        // Path berada di luar folder yang kita kelola: jangan dihapus.
        return;
      }

      final file = File(normalizedTarget);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Diamkan: penghapusan foto lama bersifat best-effort.
    }
  }

  /// Mengambil ekstensi yang aman untuk nama file baru.
  ///
  /// Bila ekstensi kosong/aneh, dipakai `.jpg` sebagai cadangan agar file
  /// tetap memiliki ekstensi yang bisa dibaca ImageProvider.
  String _safeExtension(String filePath) {
    final extension = p.extension(filePath).toLowerCase();
    if (_safeExtensionPattern.hasMatch(extension)) return extension;
    return '.jpg';
  }
}
