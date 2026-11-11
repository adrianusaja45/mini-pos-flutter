import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/database/db_constants.dart' show DbColumns, DbTables;
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../master_data/domain/failures/master_data_failure.dart';
import '../../../master_data/domain/repositories/master_data_repository.dart';
import '../../domain/entities/checkout_request.dart';
import '../../domain/entities/pos_addon.dart';
import '../../domain/entities/pos_catalog.dart';
import '../../domain/entities/pos_product.dart';
import '../../domain/entities/receipt_addon.dart';
import '../../domain/entities/receipt_item.dart';
import '../../domain/entities/transaction_receipt.dart';
import '../../domain/failures/pos_failure.dart';
import '../../domain/repositories/pos_repository.dart';
import '../../domain/services/discount_calculator.dart';

/// Implementasi [PosRepository] berbasis SQLite.
///
/// Dua tanggung jawab utama:
/// 1. **Katalog** — memanfaatkan `MasterDataRepository` agar filter soft delete
///    dan JOIN kategori tidak ditulis dua kali.
/// 2. **Checkout** — menyimpan transaksi secara atomik: header, detail
///    snapshot, dan pengurangan stok dalam satu `db.transaction`.
///
/// Sesi kasir dibaca dari `AuthRepository` saat checkout. Nama kasir disalin
/// (snapshot) ke `transactions.cashier_name` sehingga struk lama tetap benar
/// meskipun akun kasir nanti diubah namanya.
class PosRepositoryImpl implements PosRepository {
  PosRepositoryImpl(
    this._masterDataRepository,
    this._authRepository, {
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final MasterDataRepository _masterDataRepository;
  final AuthRepository _authRepository;
  final DatabaseHelper _databaseHelper;

  // ===========================================================================
  // KATALOG
  // ===========================================================================

  @override
  Future<PosCatalog> loadCatalog() async {
    try {
      // Kedua future dimulai bersamaan agar produk dan add-on tidak dimuat
      // bergantian (lebih cepat, terutama saat data cukup banyak).
      final productsFuture = _masterDataRepository.getProducts();
      final addonsFuture = _masterDataRepository.getAddons();

      final products = await productsFuture;
      final addons = await addonsFuture;

      return PosCatalog(
        products: products
            .map(
              (product) => PosProduct(
                id: product.id,
                categoryId: product.categoryId,
                categoryName: product.categoryName,
                name: product.name,
                price: product.price,
                stock: product.stock,
                imagePath: product.imagePath,
              ),
            )
            .toList(growable: false),
        addons: addons
            .map(
              (addon) => PosAddon(
                id: addon.id,
                name: addon.name,
                price: addon.price,
                stock: addon.stock,
              ),
            )
            .toList(growable: false),
      );
    } on MasterDataFailure catch (failure) {
      // Pesan master data sudah ramah pengguna; cukup dibungkus menjadi
      // PosFailure agar tipe kegagalan sesuai konteks layar kasir.
      throw PosFailure(failure.message, type: PosFailureType.loadCatalog);
    } catch (_) {
      throw const PosFailure(
        'Gagal memuat katalog kasir. Silakan coba lagi.',
        type: PosFailureType.loadCatalog,
      );
    }
  }

  // ===========================================================================
  // CHECKOUT (ATOMIC TRANSACTION)
  // ===========================================================================

  /// Menyimpan transaksi penjualan secara atomik.
  ///
  /// Urutan kerja:
  /// 1. Validasi bisnis di Dart (keranjang, diskon, uang tunai) SEBELUM
  ///    menyentuh database. Validasi ini murah dan mencegah transaksi masuk
  ///    ke SQLite dalam keadaan tidak sah.
  /// 2. Baca sesi kasir aktif. Sengaja dilakukan di luar `db.transaction`
  ///    karena query ini memakai koneksi database yang sama; memanggilnya di
  ///    dalam transaksi berisiko *deadlock* (sqflite mengunci koneksi selama
  ///    transaksi berjalan). Nama kasir langsung dijadikan snapshot.
  /// 3. Jalankan seluruh penulisan di dalam SATU `db.transaction`.
  /// 4. Terjemahkan kegagalan SQLite menjadi pesan yang bisa dipahami kasir.
  @override
  Future<TransactionReceipt> checkout(CheckoutRequest request) async {
    // -------------------------------------------------------------------------
    // LANGKAH 1: validasi bisnis & hitung ulang seluruh nominal
    // -------------------------------------------------------------------------
    final items = request.items;
    if (items.isEmpty) {
      throw const PosFailure(
        'Keranjang masih kosong. Tambahkan produk sebelum membayar.',
        type: PosFailureType.validation,
      );
    }

    // Subtotal dihitung ULANG dari item; nilai dari UI tidak dipercaya begitu
    // saja supaya tidak bisa dimanipulasi dari layer tampilan.
    final subtotal = items.fold<int>(0, (total, item) => total + item.lineTotal);

    // Diskon divalidasi & dihitung memakai kalkulator yang sama dengan Cubit.
    // Bila nilainya tidak sah (mis. persen > 100 atau nominal > subtotal),
    // transaksi dibatalkan sebelum ada baris database yang ditulis.
    final discountError = DiscountCalculator.validate(
      subtotal: subtotal,
      type: request.discountType,
      value: request.discountValue,
    );
    if (discountError != null) {
      throw PosFailure(discountError, type: PosFailureType.validation);
    }

    final discountAmount = DiscountCalculator.amount(
      subtotal: subtotal,
      type: request.discountType,
      value: request.discountValue,
    );

    // Total akhir tidak mungkin negatif karena `discountAmount` sudah dijepit
    // pada rentang 0..subtotal. Pengecekan ini adalah pengaman eksplisit agar
    // aturan "total tidak boleh minus" tetap terlihat di kode.
    final totalAmount = subtotal - discountAmount;
    if (totalAmount < 0) {
      throw const PosFailure(
        'Total tagihan tidak boleh minus. Periksa kembali diskon.',
        type: PosFailureType.validation,
      );
    }

    if (request.cashReceived < totalAmount) {
      throw PosFailure(
        'Uang tunai ${formatRupiah(request.cashReceived)} masih kurang dari '
        'total tagihan ${formatRupiah(totalAmount)}.',
        type: PosFailureType.validation,
      );
    }

    // Kembalian dihitung di sini (bukan di UI) agar angka yang tersimpan di
    // database selalu konsisten dengan total tagihan.
    final changeAmount = request.cashReceived - totalAmount;

    // -------------------------------------------------------------------------
    // LANGKAH 2: ambil nama kasir dari sesi login aktif
    // -------------------------------------------------------------------------
    final AuthSession? session;
    try {
      session = await _authRepository.getActiveSession();
    } catch (_) {
      throw const PosFailure(
        'Gagal membaca sesi kasir. Silakan login ulang lalu coba lagi.',
        type: PosFailureType.checkout,
      );
    }

    if (session == null) {
      throw const PosFailure(
        'Sesi login kasir tidak ditemukan. Silakan login ulang sebelum '
        'melakukan pembayaran.',
        type: PosFailureType.checkout,
      );
    }

    // Snapshot nama kasir: perubahan nama akun di masa depan tidak mengubah
    // struk yang sudah tersimpan.
    final cashierName = session.cashierName;

    // -------------------------------------------------------------------------
    // LANGKAH 3: db.transaction -> semua berhasil atau semua dibatalkan
    // -------------------------------------------------------------------------
    //
    // MENGAPA db.transaction WAJIB?
    // Transaksi penjualan terdiri dari banyak query yang saling bergantung:
    //   (a) insert header `transactions`,
    //   (b) insert `transaction_items` + `transaction_item_addons`,
    //   (c) UPDATE stok `products` & `addons`.
    // Tanpa transaksi, kegagalan di tengah jalan bisa menghasilkan kondisi
    // merusak, misalnya: header & detail tersimpan tetapi stok tidak berkurang
    // (barang bisa terjual melebihi stok), atau stok sudah berkurang tetapi
    // struk tidak ada (penjualan hilang dari laporan).
    //
    // CARA KERJA:
    // - `database.transaction` membuat blok BEGIN ... COMMIT secara otomatis.
    // - Semua query WAJIB memakai objek `txn` (bukan `database`), karena `txn`
    //   yang memegang kunci transaksi.
    // - Bila callback melempar exception (termasuk PosFailure di bawah), sqflite
    //   menjalankan ROLLBACK sehingga TIDAK ADA satu baris pun yang tersimpan.
    // - Bila callback selesai normal, sqflite menjalankan COMMIT sehingga semua
    //   perubahan tersimpan sekaligus.
    final database = await _databaseHelper.database;

    try {
      final receipt = await database.transaction<TransactionReceipt>((txn) async {
        // Waktu transaksi: disimpan UTC (mudah diurutkan untuk laporan),
        // sedangkan struk menampilkan versi waktu lokal perangkat.
        final now = DateTime.now();
        final createdAt = now.toUtc().toIso8601String();

        // ---------------------------------------------------------------
        // (a) HEADER TRANSAKSI
        // ---------------------------------------------------------------
        // Nomor invoice dibuat unik per hari, mis. INV-20261111-0001.
        final invoiceNumber = await _generateInvoiceNumber(txn, now);

        final transactionId = await txn.insert(DbTables.transactions, {
          DbColumns.invoiceNumber: invoiceNumber,
          // Snapshot nama kasir (bukan foreign key ke tabel users).
          DbColumns.cashierName: cashierName,
          DbColumns.subtotal: subtotal,
          DbColumns.discountType: request.discountType.storageValue,
          DbColumns.discountValue: request.discountValue,
          DbColumns.discountAmount: discountAmount,
          DbColumns.totalAmount: totalAmount,
          DbColumns.cashReceived: request.cashReceived,
          DbColumns.changeAmount: changeAmount,
          DbColumns.createdAt: createdAt,
        });

        if (transactionId <= 0) {
          // Melempar exception di dalam transaksi = ROLLBACK otomatis.
          throw const PosFailure(
            'Gagal menyimpan header transaksi. Silakan coba lagi.',
            type: PosFailureType.checkout,
          );
        }

        // ---------------------------------------------------------------
        // (b) DETAIL TRANSAKSI (SNAPSHOT / IMMUTABILITY)
        // ---------------------------------------------------------------
        // Nama & harga disalin ke kolom *_snapshot. Kolom product_id/addon_id
        // hanya disimpan sebagai referensi; struk dan laporan SELALU membaca
        // kolom snapshot sehingga perubahan harga/hapus master data di masa
        // depan tidak mengubah riwayat transaksi.
        final receiptItems = <ReceiptItem>[];

        for (final item in items) {
          final itemId = await txn.insert(DbTables.transactionItems, {
            DbColumns.transactionId: transactionId,
            DbColumns.productId: item.productId,
            DbColumns.productNameSnapshot: item.productName,
            DbColumns.productPriceSnapshot: item.unitPrice,
            DbColumns.quantity: item.quantity,
            DbColumns.subtotal: item.lineTotal,
          });

          if (itemId <= 0) {
            throw const PosFailure(
              'Gagal menyimpan detail produk transaksi. Silakan coba lagi.',
              type: PosFailureType.checkout,
            );
          }

          final receiptAddons = <ReceiptAddon>[];

          for (final addon in item.addons) {
            await txn.insert(DbTables.transactionItemAddons, {
              DbColumns.transactionItemId: itemId,
              DbColumns.addonId: addon.addonId,
              DbColumns.addonNameSnapshot: addon.name,
              DbColumns.addonPriceSnapshot: addon.price,
              // Satu unit baris produk memakai satu unit add-on.
              DbColumns.quantity: item.quantity,
            });

            receiptAddons.add(
              ReceiptAddon(
                addonId: addon.addonId,
                name: addon.name,
                price: addon.price,
                quantity: item.quantity,
              ),
            );
          }

          receiptItems.add(
            ReceiptItem(
              productId: item.productId,
              productName: item.productName,
              unitPrice: item.unitPrice,
              quantity: item.quantity,
              lineSubtotal: item.lineTotal,
              addons: receiptAddons,
            ),
          );
        }

        // ---------------------------------------------------------------
        // (c) PENGURANGAN STOK PRODUK & ADD-ON
        // ---------------------------------------------------------------
        // Pemakaian diakumulasikan per id lebih dulu. Alasannya sama dengan
        // *Shared Stock Validation* di keranjang: produk yang sama bisa muncul
        // di beberapa baris karena kombinasi add-on-nya berbeda. Dengan
        // agregasi, satu produk hanya di-update sekali memakai total unit.
        final productQuantities = <int, int>{};
        final productNames = <int, String>{};
        final addonQuantities = <int, int>{};
        final addonNames = <int, String>{};

        for (final item in items) {
          productQuantities[item.productId] =
              (productQuantities[item.productId] ?? 0) + item.quantity;
          productNames[item.productId] = item.productName;

          for (final addon in item.addons) {
            addonQuantities[addon.addonId] =
                (addonQuantities[addon.addonId] ?? 0) + item.quantity;
            addonNames[addon.addonId] = addon.name;
          }
        }

        for (final entry in productQuantities.entries) {
          final quantity = entry.value;

          // `stock = stock - ?` dihitung langsung oleh SQLite (bukan dibaca
          // dulu lalu ditulis) agar tidak ada celah *lost update*.
          // Syarat `stock >= ?` membuat UPDATE gagal (0 baris) bila stok
          // ternyata tidak cukup, sehingga transaksi dibatalkan seluruhnya.
          final affected = await txn.rawUpdate(
            'UPDATE ${DbTables.products} '
            'SET ${DbColumns.stock} = ${DbColumns.stock} - ? '
            'WHERE ${DbColumns.id} = ? AND ${DbColumns.stock} >= ?',
            [quantity, entry.key, quantity],
          );

          if (affected != 1) {
            throw PosFailure(
              'Stok produk "${productNames[entry.key] ?? entry.key}" tidak '
              'mencukupi. Stok mungkin berubah sejak katalog dimuat. '
              'Periksa kembali keranjang lalu coba lagi.',
              type: PosFailureType.validation,
            );
          }
        }

        for (final entry in addonQuantities.entries) {
          final quantity = entry.value;

          final affected = await txn.rawUpdate(
            'UPDATE ${DbTables.addons} '
            'SET ${DbColumns.stock} = ${DbColumns.stock} - ? '
            'WHERE ${DbColumns.id} = ? AND ${DbColumns.stock} >= ?',
            [quantity, entry.key, quantity],
          );

          if (affected != 1) {
            throw PosFailure(
              'Stok add-on "${addonNames[entry.key] ?? entry.key}" tidak '
              'mencukupi. Stok mungkin berubah sejak katalog dimuat. '
              'Periksa kembali keranjang lalu coba lagi.',
              type: PosFailureType.validation,
            );
          }
        }

        // Semua langkah berhasil -> kembalikan struk dari data snapshot yang
        // baru saja ditulis. Callback selesai tanpa exception, sehingga
        // sqflite melakukan COMMIT.
        return TransactionReceipt(
          transactionId: transactionId,
          invoiceNumber: invoiceNumber,
          cashierName: cashierName,
          // Struk ditampilkan dalam waktu lokal perangkat.
          createdAt: now,
          items: receiptItems,
          subtotal: subtotal,
          discountType: request.discountType,
          discountValue: request.discountValue,
          discountAmount: discountAmount,
          totalAmount: totalAmount,
          cashReceived: request.cashReceived,
          changeAmount: changeAmount,
        );
      });

      return receipt;
    } on PosFailure {
      // Kegagalan bisnis (mis. stok tidak cukup) sudah memiliki pesan ramah.
      // db.transaction sudah melakukan ROLLBACK sebelum exception sampai ke
      // sini, jadi tidak ada data setengah jadi yang tertinggal.
      rethrow;
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const PosFailure(
          'Nomor invoice bentrok dengan transaksi lain. Silakan ulangi '
          'pembayaran.',
          type: PosFailureType.checkout,
        );
      }
      throw const PosFailure(
        'Gagal menyimpan transaksi ke database. Seluruh perubahan sudah '
        'dibatalkan, stok tidak berkurang. Silakan coba lagi.',
        type: PosFailureType.checkout,
      );
    } catch (_) {
      throw const PosFailure(
        'Gagal menyimpan transaksi. Seluruh perubahan sudah dibatalkan. '
        'Silakan coba lagi.',
        type: PosFailureType.checkout,
      );
    }
  }

  // ===========================================================================
  // HELPER
  // ===========================================================================

  /// Membuat nomor invoice unik berformat `INV-yyyyMMdd-####`.
  ///
  /// Nomor urut dihitung dari jumlah transaksi pada tanggal yang sama
  /// (prefix invoice). Query dijalankan memakai [txn] agar berada di dalam
  /// transaksi yang sama, sehingga tidak ada transaksi lain yang bisa menyisip
  /// di antara proses hitung dan insert pada koneksi yang sama.
  ///
  /// Kolom `invoice_number` memiliki constraint UNIQUE sebagai pengaman
  /// terakhir bila nomor tetap bentrok (mis. karena data dimigrasi manual).
  Future<String> _generateInvoiceNumber(Transaction txn, DateTime now) async {
    final dateKey =
        '${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}';
    final prefix = 'INV-$dateKey-';

    final rows = await txn.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DbTables.transactions} '
      'WHERE ${DbColumns.invoiceNumber} LIKE ?',
      ['$prefix%'],
    );

    final used = (rows.first['total'] as int?) ?? 0;
    final sequence = used + 1;

    return '$prefix${sequence.toString().padLeft(4, '0')}';
  }

  /// Menambahkan angka 0 di depan bila nilainya satu digit.
  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
