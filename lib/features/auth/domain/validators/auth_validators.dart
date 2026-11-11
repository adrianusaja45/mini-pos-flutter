/// Aturan validasi form autentikasi yang dipakai bersama oleh UI dan repository.
///
/// Mengapa dipusatkan di satu kelas?
/// - UI memakai method ini sebagai `validator` TextFormField supaya pesan error
///   muncul langsung saat kasir mengetik.
/// - Repository memakai method yang sama sebagai pengaman terakhir. Dengan
///   begitu, aturan tidak bisa dilewati walaupun nanti ada halaman lain yang
///   memanggil repository tanpa form.
class AuthValidators {
  // Kelas aturan: tidak perlu dibuat menjadi objek.
  const AuthValidators._();

  /// Panjang minimal nama lengkap kasir.
  static const int nameMinLength = 3;

  /// Panjang maksimal nama lengkap (mencegah teks kepanjangan di struk).
  static const int nameMaxLength = 50;

  /// Panjang minimal username.
  static const int usernameMinLength = 3;

  /// Panjang maksimal username.
  static const int usernameMaxLength = 20;

  /// Panjang minimal PIN/password. Angka 4 dipilih karena PIN kasir biasanya
  /// berupa 4 digit, tetapi password teks juga tetap diperbolehkan.
  static const int passwordMinLength = 4;

  /// Panjang maksimal PIN/password.
  static const int passwordMaxLength = 32;

  /// Pola username: huruf kecil, angka, titik, dan garis bawah.
  ///
  /// Spasi dan simbol lain ditolak agar username tidak membingungkan saat
  /// diketik ulang, dan agar konsisten dengan normalisasi ke huruf kecil.
  static final RegExp _usernamePattern = RegExp(r'^[a-z0-9._]+$');

  /// Menyeragamkan username sebelum disimpan/dicari.
  ///
  /// `trim()` membuang spasi tak sengaja dari keyboard, `toLowerCase()`
  /// membuat "Kasir1" dan "kasir1" dianggap akun yang sama sehingga tidak ada
  /// akun duplikat yang membingungkan.
  static String normalizeUsername(String value) => value.trim().toLowerCase();

  /// Validasi nama lengkap kasir.
  static String? validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Nama lengkap wajib diisi.';
    }
    if (name.length < nameMinLength) {
      return 'Nama lengkap minimal $nameMinLength karakter.';
    }
    if (name.length > nameMaxLength) {
      return 'Nama lengkap maksimal $nameMaxLength karakter.';
    }
    // Nama hanya boleh berisi huruf, spasi, titik, koma, tanda hubung, dan
    // apostrof (mis. "M. Ali", "Sri-Wahyuni", "Ahmad, S.Kom").
    if (!RegExp(r"^[A-Za-z.,' -]+$").hasMatch(name)) {
      return 'Nama lengkap hanya boleh berisi huruf, spasi, titik, koma, '
          'tanda hubung, dan apostrof.';
    }
    return null;
  }

  /// Validasi username login.
  static String? validateUsername(String? value) {
    final username = normalizeUsername(value ?? '');
    if (username.isEmpty) {
      return 'Username wajib diisi.';
    }
    if (username.length < usernameMinLength) {
      return 'Username minimal $usernameMinLength karakter.';
    }
    if (username.length > usernameMaxLength) {
      return 'Username maksimal $usernameMaxLength karakter.';
    }
    if (!_usernamePattern.hasMatch(username)) {
      return 'Username hanya boleh berisi huruf, angka, titik, dan garis bawah.';
    }
    return null;
  }

  /// Validasi PIN/password.
  static String? validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'PIN/password wajib diisi.';
    }
    if (password.length < passwordMinLength) {
      return 'PIN/password minimal $passwordMinLength karakter.';
    }
    if (password.length > passwordMaxLength) {
      return 'PIN/password maksimal $passwordMaxLength karakter.';
    }
    // Password tidak boleh berisi spasi saja karena sulit diketik ulang.
    if (password.trim().isEmpty) {
      return 'PIN/password tidak boleh hanya berisi spasi.';
    }
    return null;
  }

  /// Validasi kolom "Ulangi PIN/password" pada form register.
  ///
  /// Dibuat terpisah karena aturannya bergantung pada isi kolom pertama;
  /// tujuannya mencegah kasir terkunci di luar aplikasi akibat salah ketik PIN.
  static String? validatePasswordConfirmation(
    String? value, {
    required String password,
  }) {
    if ((value ?? '').isEmpty) {
      return 'Konfirmasi PIN/password wajib diisi.';
    }
    if (value != password) {
      return 'Konfirmasi PIN/password tidak sama.';
    }
    return null;
  }

  /// Mengumpulkan seluruh pesan error register dalam satu daftar.
  ///
  /// Dipakai repository agar pemanggilan di luar UI tetap tervalidasi.
  /// `@visibleForTesting` tidak dipakai karena method ini memang bagian dari
  /// kontrak domain, bukan hanya alat pengujian.
  static List<String> validateRegistration({
    required String name,
    required String username,
    required String password,
  }) {
    return <String?>[
      validateName(name),
      validateUsername(username),
      validatePassword(password),
    ].whereType<String>().toList();
  }
}
