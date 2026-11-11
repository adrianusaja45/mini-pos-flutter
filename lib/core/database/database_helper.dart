import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'db_constants.dart';

/// Kelas pusat pengelola koneksi SQLite untuk aplikasi Mini POS Offline.
///
/// Mengapa memakai *singleton*?
/// - Aplikasi hanya boleh membuka satu koneksi database agar konsisten dan
///   hemat memori.
/// - Dengan satu instance, seluruh repository berbagi koneksi yang sama
///   sehingga transaksi atomik (misal pengurangan stok saat checkout) dapat
///   dijalankan dengan aman.
class DatabaseHelper {
  // ---------------------------------------------------------------------------
  // Konstruktor & Singleton
  // ---------------------------------------------------------------------------

  // Konstruktor privat agar objek tidak bisa dibuat dari luar kelas.
  DatabaseHelper._internal();

  // Instance tunggal yang dipakai seluruh aplikasi.
  static final DatabaseHelper instance = DatabaseHelper._internal();

  /// Alias agar pemanggilan `DatabaseHelper()` tetap mengarah ke instance yang
  /// sama (memudahkan penulisan di repository).
  factory DatabaseHelper() => instance;

  // ---------------------------------------------------------------------------
  // Konfigurasi Database
  // ---------------------------------------------------------------------------

  /// Nama file database di dalam direktori database aplikasi.
  static const String databaseName = 'mini_pos.db';

  /// Versi skema database.
  ///
  /// Setiap kali struktur tabel berubah, naikkan angka ini dan tambahkan
  /// langkah migrasinya di [_onUpgrade] agar data pengguna tidak hilang.
  ///
  /// Riwayat versi:
  /// - 1: tabel pengguna, kategori, produk, add-on, dan transaksi.
  /// - 2: menambah tabel `user_sessions` untuk menyimpan sesi login kasir.
  static const int databaseVersion = 2;

  /// Path alternatif khusus pengujian (misal `inMemoryDatabasePath`).
  ///
  /// Pada aplikasi nyata nilainya `null`, sehingga database disimpan permanen
  /// di direktori database aplikasi.
  static String? debugDatabasePath;

  /// Koneksi database yang sedang aktif.
  Database? _database;

  /// Menyimpan proses pembukaan yang sedang berjalan.
  ///
  /// Mencegah database terbuka dua kali ketika beberapa repository meminta
  /// koneksi secara bersamaan (race condition saat aplikasi baru start).
  Future<Database>? _opening;

  /// Mengembalikan koneksi database, membukanya lebih dulu bila belum ada.
  Future<Database> get database async {
    final existing = _database;
    // Koneksi yang masih terbuka bisa langsung dipakai.
    if (existing != null && existing.isOpen) return existing;

    // Jika proses pembukaan sedang berjalan, tunggu future yang sama.
    return _opening ??= _openAndCache();
  }

  /// Membuka file database lalu menyimpannya ke [_database].
  Future<Database> _openAndCache() async {
    try {
      final path =
          debugDatabasePath ?? p.join(await getDatabasesPath(), databaseName);

      final db = await openDatabase(
        path,
        version: databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      _database = db;
      return db;
    } finally {
      // Apa pun hasilnya, penanda proses dibersihkan agar percobaan berikutnya
      // bisa membuka ulang koneksi bila sebelumnya gagal.
      _opening = null;
    }
  }

  /// Menutup koneksi database.
  ///
  /// Dipakai saat pengujian atau ketika aplikasi benar-benar berhenti, agar
  /// file database tidak dalam keadaan terkunci.
  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  /// Menghapus file database secara fisik (reset total / keperluan development).
  ///
  /// Aplikasi tidak memanggil ini pada alur normal karena akan menghapus
  /// seluruh data penjualan.
  Future<void> deleteDatabaseFile() async {
    await close();
    final path =
        debugDatabasePath ?? p.join(await getDatabasesPath(), databaseName);
    await databaseFactory.deleteDatabase(path);
  }

  // ---------------------------------------------------------------------------
  // Callback Sqflite
  // ---------------------------------------------------------------------------

  /// Dipanggil setiap kali koneksi dibuka, sebelum tabel dibuat/dimigrasi.
  ///
  /// `PRAGMA foreign_keys = ON` WAJIB diaktifkan karena SQLite mematikan
  /// pengecekan relasi secara default. Tanpa ini, data detail transaksi bisa
  /// menunjuk ke produk yang tidak ada.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Membuat seluruh tabel saat database pertama kali dibuat.
  ///
  /// Urutan pembuatan penting: tabel induk (`categories`, `products`,
  /// `transactions`) harus ada sebelum tabel anak yang memiliki FOREIGN KEY.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_createUsersTable);
    await db.execute(_createUserSessionsTable);
    await db.execute(_createCategoriesTable);
    await db.execute(_createProductsTable);
    await db.execute(_createAddonsTable);
    await db.execute(_createTransactionsTable);
    await db.execute(_createTransactionItemsTable);
    await db.execute(_createTransactionItemAddonsTable);

    // Index dibuat terpisah agar mempercepat query yang sering dipakai
    // (filter produk per kategori, laporan per tanggal, detail per transaksi).
    for (final sql in _createIndexes) {
      await db.execute(sql);
    }
  }

  /// Menangani perubahan skema pada versi aplikasi berikutnya.
  ///
  /// Migrasi dijalankan dari versi lama menuju versi terbaru secara berurutan,
  /// sehingga pengguna yang memperbarui aplikasi tetap memakai database lama
  /// tanpa kehilangan data.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Versi 2 menambahkan tabel sesi login kasir.
    if (oldVersion < 2) {
      await db.execute(_createUserSessionsTable);
    }

    // Contoh pola migrasi di masa depan:
    // if (oldVersion < 3) {
    //   await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT');
    // }
  }

  // ---------------------------------------------------------------------------
  // Definisi Skema (SQL)
  // ---------------------------------------------------------------------------
  //
  // Catatan penting soal tipe data uang:
  // Seluruh nominal (harga, subtotal, total, diskon) disimpan sebagai INTEGER
  // dalam satuan Rupiah utuh (tanpa sen). Alasannya, Rupiah tidak memakai
  // pecahan dan tipe REAL (floating point) berisiko menimbulkan galat
  // pembulatan saat penjumlahan laporan. Perhitungan persentase dilakukan di
  // Dart lalu dibulatkan sebelum disimpan.

  /// Tabel akun pengguna aplikasi (kasir/admin).
  static const String _createUsersTable = '''
    CREATE TABLE ${DbTables.users} (
      -- Primary key unik tiap pengguna.
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      -- Nama lengkap kasir; nantinya disalin ke transactions.cashier_name
      -- sebagai snapshot agar riwayat tetap benar walau nama diubah.
      name TEXT NOT NULL,
      -- Username untuk login, harus unik (tidak boleh ada dua akun sama).
      username TEXT NOT NULL UNIQUE,
      -- PIN/password yang sudah di-hash (JANGAN pernah simpan teks asli).
      -- Hash dipakai supaya kebocoran file database tidak langsung
      -- membuka akses akun.
      password_hash TEXT NOT NULL,
      -- Waktu pembuatan akun, format ISO-8601 UTC agar mudah diurutkan.
      created_at TEXT NOT NULL
    )
  ''';

  /// Tabel sesi login kasir yang sedang aktif.
  ///
  /// Mengapa memakai tabel, bukan variabel di memori?
  /// - Sesi harus tetap ada setelah aplikasi ditutup, sehingga kasir tidak
  ///   perlu login ulang setiap membuka aplikasi.
  /// - `CHECK (id = 1)` memastikan tabel hanya boleh berisi satu baris, jadi
  ///   mustahil ada dua kasir aktif sekaligus di satu perangkat.
  ///
  /// `user_name` dan `username` sengaja disalin (snapshot) agar halaman Home
  /// bisa langsung menampilkan identitas kasir tanpa query tambahan.
  static const String _createUserSessionsTable = '''
    CREATE TABLE ${DbTables.userSessions} (
      -- Selalu bernilai 1: kunci agar hanya ada satu sesi aktif.
      id INTEGER PRIMARY KEY CHECK (id = 1),
      -- Akun kasir yang sedang login. ON DELETE CASCADE menghapus sesi
      -- otomatis bila akun tersebut dihapus dari tabel users.
      user_id INTEGER NOT NULL,
      -- Salinan nama lengkap kasir untuk ditampilkan di Home/struk.
      user_name TEXT NOT NULL,
      -- Salinan username kasir (huruf kecil) untuk ditampilkan di Home.
      username TEXT NOT NULL,
      -- Waktu login terakhir (ISO-8601 UTC).
      logged_in_at TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES ${DbTables.users} (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
    )
  ''';

  /// Tabel kategori produk.
  static const String _createCategoriesTable = '''
    CREATE TABLE ${DbTables.categories} (
      -- Primary key kategori.
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      -- Nama kategori; COLLATE NOCASE membuat "Minuman" dan "minuman"
      -- dianggap sama sehingga tidak ada kategori duplikat.
      name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      -- Waktu kategori dibuat (ISO-8601 UTC).
      created_at TEXT NOT NULL
    )
  ''';

  /// Tabel master produk.
  static const String _createProductsTable = '''
    CREATE TABLE ${DbTables.products} (
      -- Primary key produk.
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      -- Kategori produk. ON DELETE RESTRICT mencegah kategori dihapus
      -- selama masih dipakai produk, supaya tidak ada produk "tanpa induk".
      category_id INTEGER NOT NULL,
      -- Nama produk yang tampil di katalog dan struk.
      name TEXT NOT NULL,
      -- Harga jual satuan dalam Rupiah (INTEGER, tanpa sen).
      price INTEGER NOT NULL CHECK (price >= 0),
      -- Stok tersedia. CHECK mencegah stok menjadi negatif yang berarti
      -- penjualan melebihi barang yang ada.
      stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
      -- Path permanen foto produk di Application Documents Directory.
      -- Boleh NULL jika produk tidak difoto. Path disimpan permanen agar
      -- gambar tidak hilang saat cache dibersihkan.
      image_path TEXT,
      -- Soft delete (0 = aktif, 1 = dihapus). Produk tidak dihapus fisik
      -- karena id-nya masih dirujuk riwayat transaksi.
      is_deleted INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0, 1)),
      -- Waktu produk dibuat (ISO-8601 UTC).
      created_at TEXT NOT NULL,
      FOREIGN KEY (category_id) REFERENCES ${DbTables.categories} (id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
    )
  ''';

  /// Tabel master add-on (topping/tambahan).
  static const String _createAddonsTable = '''
    CREATE TABLE ${DbTables.addons} (
      -- Primary key add-on.
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      -- Nama add-on, unik tanpa membedakan huruf besar/kecil.
      name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      -- Harga tambahan per unit dalam Rupiah (INTEGER, tanpa sen).
      price INTEGER NOT NULL CHECK (price >= 0),
      -- Stok add-on; dipantau terpisah dari stok produk karena satu add-on
      -- bisa dipakai banyak produk. CHECK menjaga stok tidak negatif.
      stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
      -- Soft delete (0 = aktif, 1 = dihapus) agar riwayat transaksi lama
      -- yang memakai add-on ini tetap utuh.
      is_deleted INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0, 1)),
      -- Waktu add-on dibuat (ISO-8601 UTC).
      created_at TEXT NOT NULL
    )
  ''';

  /// Tabel header transaksi (satu baris = satu struk).
  static const String _createTransactionsTable = '''
    CREATE TABLE ${DbTables.transactions} (
      -- Primary key transaksi.
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      -- Nomor nota yang tercetak di struk, unik agar tidak ada nota ganda.
      invoice_number TEXT NOT NULL UNIQUE,
      -- Snapshot nama kasir saat transaksi terjadi. Disimpan sebagai teks
      -- (bukan foreign key ke users) supaya struk lama tidak berubah bila
      -- akun kasir diubah namanya atau dihapus.
      cashier_name TEXT NOT NULL,
      -- Subtotal = jumlah (harga produk + harga add-on) x qty, sebelum diskon.
      subtotal INTEGER NOT NULL CHECK (subtotal >= 0),
      -- Jenis diskon: 'none', 'nominal', atau 'percentage'.
      discount_type TEXT NOT NULL DEFAULT '${DiscountType.none}'
        CHECK (discount_type IN (
          '${DiscountType.none}',
          '${DiscountType.nominal}',
          '${DiscountType.percentage}'
        )),
      -- Nilai diskon sesuai input kasir: Rupiah bila 'nominal', atau angka
      -- 0-100 bila 'percentage'. Dibatasi 100 agar diskon tidak melebihi
      -- 100% (aturan proteksi diskon).
      discount_value INTEGER NOT NULL DEFAULT 0
        CHECK (discount_value >= 0)
        CHECK (discount_type <> '${DiscountType.percentage}'
          OR discount_value <= 100),
      -- Hasil akhir perhitungan diskon dalam Rupiah. Dibatasi tidak boleh
      -- melebihi subtotal sehingga total tagihan tidak mungkin minus.
      discount_amount INTEGER NOT NULL DEFAULT 0
        CHECK (discount_amount >= 0 AND discount_amount <= subtotal),
      -- Total yang harus dibayar = subtotal - discount_amount.
      -- CHECK total_amount >= 0 adalah pengaman terakhir aturan bisnis.
      total_amount INTEGER NOT NULL CHECK (total_amount >= 0),
      -- Uang tunai yang diterima kasir (INTEGER Rupiah).
      cash_received INTEGER NOT NULL DEFAULT 0 CHECK (cash_received >= 0),
      -- Kembalian = cash_received - total_amount, tidak boleh negatif.
      change_amount INTEGER NOT NULL DEFAULT 0 CHECK (change_amount >= 0),
      -- Waktu transaksi (ISO-8601 UTC); dipakai untuk filter laporan harian.
      created_at TEXT NOT NULL
    )
  ''';

  /// Tabel detail produk per transaksi.
  ///
  /// Kolom snapshot (`product_name_snapshot`, `product_price_snapshot`) WAJIB
  /// diisi saat checkout. Tujuannya agar struk dan laporan tetap menampilkan
  /// nama/harga yang benar meskipun master produk kemudian diubah harganya
  /// atau dihapus (soft delete). Inilah prinsip *immutability* riwayat.
  static const String _createTransactionItemsTable = '''
    CREATE TABLE ${DbTables.transactionItems} (
      -- Primary key baris detail.
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      -- Transaksi induk. ON DELETE CASCADE: detail ikut terhapus bila
      -- header transaksi dihapus (dalam praktik header tidak dihapus).
      transaction_id INTEGER NOT NULL,
      -- Referensi ke master produk. Boleh NULL dan memakai ON DELETE SET NULL
      -- karena riwayat tidak bergantung pada master; nama & harga sudah
      -- disalin ke kolom snapshot di bawah.
      product_id INTEGER,
      -- Salinan nama produk saat transaksi (snapshot).
      product_name_snapshot TEXT NOT NULL,
      -- Salinan harga satuan produk saat transaksi (snapshot, Rupiah).
      product_price_snapshot INTEGER NOT NULL
        CHECK (product_price_snapshot >= 0),
      -- Jumlah produk yang dibeli, minimal 1.
      quantity INTEGER NOT NULL CHECK (quantity > 0),
      -- Subtotal baris = (harga produk + total harga add-on) x quantity.
      subtotal INTEGER NOT NULL CHECK (subtotal >= 0),
      FOREIGN KEY (transaction_id) REFERENCES ${DbTables.transactions} (id)
        ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES ${DbTables.products} (id)
        ON DELETE SET NULL
    )
  ''';

  /// Tabel detail add-on yang menempel pada satu baris transaksi.
  ///
  /// Snapshot nama & harga add-on membuat riwayat tetap akurat walaupun
  /// master add-on berubah atau dihapus.
  static const String _createTransactionItemAddonsTable = '''
    CREATE TABLE ${DbTables.transactionItemAddons} (
      -- Primary key baris add-on.
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      -- Baris produk transaksi yang memiliki add-on ini.
      -- ON DELETE CASCADE menjaga tidak ada add-on yatim.
      transaction_item_id INTEGER NOT NULL,
      -- Referensi master add-on; boleh NULL dengan ON DELETE SET NULL karena
      -- data yang ditampilkan di struk berasal dari kolom snapshot.
      addon_id INTEGER,
      -- Salinan nama add-on saat transaksi (snapshot).
      addon_name_snapshot TEXT NOT NULL,
      -- Salinan harga satuan add-on saat transaksi (snapshot, Rupiah).
      addon_price_snapshot INTEGER NOT NULL CHECK (addon_price_snapshot >= 0),
      -- Jumlah add-on untuk baris tersebut, minimal 1.
      quantity INTEGER NOT NULL CHECK (quantity > 0),
      FOREIGN KEY (transaction_item_id)
        REFERENCES ${DbTables.transactionItems} (id)
        ON DELETE CASCADE,
      FOREIGN KEY (addon_id) REFERENCES ${DbTables.addons} (id)
        ON DELETE SET NULL
    )
  ''';

  /// Daftar index untuk mempercepat query yang paling sering dipakai.
  static const List<String> _createIndexes = [
    // Katalog produk biasanya difilter per kategori dan hanya yang aktif.
    'CREATE INDEX idx_products_category ON ${DbTables.products} (category_id)',
    'CREATE INDEX idx_products_active ON ${DbTables.products} (is_deleted)',
    // Laporan penjualan diurutkan/difilter berdasarkan tanggal transaksi.
    'CREATE INDEX idx_transactions_created_at '
        'ON ${DbTables.transactions} (created_at)',
    // Struk memuat seluruh detail berdasarkan transaction_id.
    'CREATE INDEX idx_transaction_items_transaction '
        'ON ${DbTables.transactionItems} (transaction_id)',
    // Detail add-on diambil per baris transaksi.
    'CREATE INDEX idx_transaction_item_addons_item '
        'ON ${DbTables.transactionItemAddons} (transaction_item_id)',
  ];
}
