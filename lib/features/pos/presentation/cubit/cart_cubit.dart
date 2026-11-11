import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/cart_addon.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/discount_type.dart';
import '../../domain/entities/pos_addon.dart';
import '../../domain/entities/pos_product.dart';
import '../../domain/services/discount_calculator.dart';
import 'cart_state.dart';

/// Hasil satu operasi keranjang.
///
/// UI memakai objek ini untuk menampilkan snackbar kesalahan. Mengapa hasil
/// dikembalikan langsung (bukan hanya disimpan di state)? Karena kegagalan
/// validasi stok bersifat sesaat dan harus muncul tepat pada aksi kasir yang
/// gagal, bukan menempel di state sampai aksi berikutnya.
class CartMutationResult {
  const CartMutationResult._({required this.isSuccess, this.message});

  /// Operasi berhasil mengubah keranjang.
  const CartMutationResult.success() : this._(isSuccess: true);

  /// Operasi ditolak; [message] berisi alasan yang siap ditampilkan.
  const CartMutationResult.failure(String message)
    : this._(isSuccess: false, message: message);

  final bool isSuccess;

  /// Alasan kegagalan (mis. stok tidak cukup). `null` saat berhasil.
  final String? message;
}

/// Cubit keranjang kasir beserta **Shared Stock Validation** dan
/// **Proteksi Diskon**.
///
/// Cubit ini sengaja tidak menyentuh SQLite: seluruh data yang dibutuhkan
/// (harga & stok) dibawa oleh [PosProduct]/[PosAddon] dan disalin sebagai
/// snapshot ke [CartItem]. Dengan begitu, menambah/mengurangi quantity tidak
/// pernah memicu query database sehingga layar kasir tetap responsif.
///
/// Penyimpanan transaksi ke SQLite dilakukan oleh `CheckoutCubit` lewat
/// repository, bukan oleh Cubit ini.
class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  // ===========================================================================
  // SHARED STOCK VALIDATION
  // ===========================================================================
  //
  // ATURAN BISNIS:
  // Stok yang boleh dipakai dihitung dari AKUMULASI SELURUH BARIS keranjang
  // untuk id yang sama, bukan hanya baris yang sedang diubah.
  //
  // Contoh kasus nyata (produk "Kopi Susu" stok database = 3):
  //   Baris 1: Kopi Susu polos                       qty 1  -> pakai 1
  //   Baris 2: Kopi Susu + Extra Shot                qty 1  -> pakai 1
  //   Baris 3: Kopi Susu + Extra Shot + Boba         qty 1  -> pakai 1
  //   ---------------------------------------------------------------
  //   Total pemakaian produk Kopi Susu                           = 3
  //
  // Jika kasir menekan "+" pada baris mana pun, permintaan tersebut akan
  // membuat total menjadi 4 > 3, sehingga WAJIB ditolak walaupun masing-masing
  // baris terlihat "masih kecil". Inilah yang membedakan validasi naif
  // (cek `item.quantity < stok`) dengan validasi bersama yang benar.
  //
  // Pola yang sama berlaku untuk add-on: stok "Extra Shot" dipakai bersama
  // oleh semua baris/produk yang memilih add-on tersebut.
  //
  // CARA KERJA (dipakai oleh [addProduct] dan [increaseQuantity]):
  //   1. `state.productUsage(id)` menjumlahkan quantity semua baris dengan
  //      product_id sama. Ini angka pemakaian saat ini.
  //   2. Angka tersebut ditambah permintaan baru (`additionalQuantity`).
  //   3. Jika hasilnya melebihi stok di database -> tolak dan kembalikan pesan
  //      yang menjelaskan sisa stok serta pemakaian yang sudah ada.
  //   4. Untuk setiap add-on yang dipilih, ulangi langkah 1-3 memakai
  //      `state.addonUsage(id)`. Satu unit baris memakai satu unit add-on.
  //   5. Bila semua batas aman, barulah state keranjang diubah.
  //
  // PENTING: validasi dijalankan SEBELUM emit, sehingga tidak pernah ada
  // kondisi keranjang sementara yang sudah melebihi stok.

  /// Menambahkan produk (dengan add-on opsional) ke keranjang.
  ///
  /// [quantity] adalah jumlah yang ingin ditambahkan pada aksi ini.
  /// Bila kombinasi produk + add-on sudah ada, baris tersebut digabung
  /// (quantity ditambah); bila berbeda, dibuat baris baru.
  CartMutationResult addProduct({
    required PosProduct product,
    List<PosAddon> addons = const <PosAddon>[],
    int quantity = 1,
  }) {
    if (quantity < 1) {
      return _reject('Jumlah produk minimal 1. Pilih jumlah yang benar.');
    }

    // Menghilangkan add-on duplikat agar satu add-on tidak dihitung dua kali.
    final selectedAddons = _uniqueAddons(addons);

    // LANGKAH KUNCI: validasi akumulasi stok sebelum menyentuh state.
    final stockError = _validateSharedStock(
      productId: product.id,
      productName: product.name,
      productStock: product.stock,
      addonStocks: {for (final addon in selectedAddons) addon.id: addon.stock},
      addonNames: {for (final addon in selectedAddons) addon.id: addon.name},
      additionalQuantity: quantity,
    );
    if (stockError != null) {
      return _reject(stockError);
    }

    // Signature menentukan apakah baris digabung atau dibuat baru.
    final signature = CartItem.buildSignature(
      product.id,
      selectedAddons.map((addon) => addon.id),
    );
    final existingIndex = state.items.indexWhere(
      (item) => item.signature == signature,
    );

    final updatedItems = List<CartItem>.from(state.items);

    if (existingIndex >= 0) {
      // Kombinasi identik -> tambah quantity pada baris yang sudah ada.
      final existing = updatedItems[existingIndex];
      updatedItems[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      // Kombinasi berbeda -> baris baru dengan snapshot data saat ini.
      updatedItems.add(
        CartItem(
          productId: product.id,
          productName: product.name,
          unitPrice: product.price,
          productStock: product.stock,
          quantity: quantity,
          imagePath: product.imagePath,
          addons: selectedAddons
              .map(
                (addon) => CartAddon(
                  addonId: addon.id,
                  name: addon.name,
                  price: addon.price,
                  stock: addon.stock,
                ),
              )
              .toList(growable: false),
        ),
      );
    }

    _commitItems(updatedItems);
    return const CartMutationResult.success();
  }

  /// Menambah quantity satu baris keranjang (tombol "+").
  ///
  /// Validasi memakai batas stok yang tersimpan pada baris (snapshot) dan
  /// tetap menghitung akumulasi seluruh baris lain dengan produk/add-on sama.
  CartMutationResult increaseQuantity(String signature) {
    final index = state.items.indexWhere((item) => item.signature == signature);
    if (index < 0) {
      return _reject('Item keranjang tidak ditemukan. Mungkin sudah dihapus.');
    }

    final item = state.items[index];

    final stockError = _validateSharedStock(
      productId: item.productId,
      productName: item.productName,
      productStock: item.productStock,
      addonStocks: {
        for (final addon in item.addons) addon.addonId: addon.stock,
      },
      addonNames: {for (final addon in item.addons) addon.addonId: addon.name},
      additionalQuantity: 1,
    );
    if (stockError != null) {
      return _reject(stockError);
    }

    final updatedItems = List<CartItem>.from(state.items);
    updatedItems[index] = item.copyWith(quantity: item.quantity + 1);
    _commitItems(updatedItems);
    return const CartMutationResult.success();
  }

  /// Mengurangi quantity satu baris (tombol "-").
  ///
  /// Bila quantity tersisa 1 lalu dikurangi, baris langsung dihapus karena
  /// item dengan jumlah 0 tidak boleh ada di keranjang.
  CartMutationResult decreaseQuantity(String signature) {
    final index = state.items.indexWhere((item) => item.signature == signature);
    if (index < 0) {
      return _reject('Item keranjang tidak ditemukan. Mungkin sudah dihapus.');
    }

    final updatedItems = List<CartItem>.from(state.items);
    final item = updatedItems[index];

    if (item.quantity <= 1) {
      updatedItems.removeAt(index);
    } else {
      updatedItems[index] = item.copyWith(quantity: item.quantity - 1);
    }

    _commitItems(updatedItems);
    return const CartMutationResult.success();
  }

  /// Menghapus satu baris keranjang tanpa mempedulikan quantity.
  void removeItem(String signature) {
    final updatedItems = state.items
        .where((item) => item.signature != signature)
        .toList(growable: false);
    if (updatedItems.length == state.items.length) return;
    _commitItems(updatedItems);
  }

  /// Mengosongkan seluruh keranjang (mis. kasir membatalkan transaksi atau
  /// menekan "Selesai" setelah struk ditampilkan).
  void clear() {
    if (state.isEmpty) return;
    // State baru tanpa items juga otomatis menghapus diskon & pesan lama,
    // karena transaksi berikutnya harus dimulai dari nol.
    emit(const CartState());
  }

  /// Menghapus pesan kesalahan setelah kasir membacanya.
  void clearError() {
    if (state.errorMessage != null) {
      emit(state.copyWith(clearError: true));
    }
  }

  // ===========================================================================
  // PROTEKSI DISKON
  // ===========================================================================
  //
  // ATURAN BISNIS yang WAJIB dijaga:
  // 1. Diskon persentase maksimal 100%.
  // 2. Diskon nominal tidak boleh melebihi subtotal belanja.
  // 3. Total akhir tidak boleh minus (< 0).
  //
  // MENGAPA validasi dilakukan di Cubit, bukan hanya di UI?
  // - UI (form diskon) memang memvalidasi agar tombol "Terapkan" tidak bisa
  //   ditekan untuk nilai salah. Namun UI bersifat "permintaan"; Cubit adalah
  //   tempat aturan bisnis ditegakkan. Bila suatu saat ada tombol atau jalur
  //   lain yang memanggil [applyDiscount], aturan tetap sama.
  // - Repository juga memvalidasi ulang sebelum menulis ke SQLite (lapisan
  //   pertahanan ketiga). Jadi ada tiga lapis: UI -> Cubit -> Repository,
  //   ditambah CHECK constraint di skema database sebagai lapis terakhir.
  //
  // MENGAPA total tidak pernah minus?
  // [CartState.discountAmount] memakai [DiscountCalculator] yang selalu
  // menjepit nominal diskon pada rentang `0..subtotal`. Dengan begitu total
  // adalah `subtotal - discountAmount` dan hasilnya tidak mungkin negatif,
  // bahkan jika kasir memberi diskon nominal besar lalu menghapus sebagian
  // item dari keranjang (subtotal mengecil).
  //
  // CATATAN PENTING soal perubahan isi keranjang:
  // Diskon yang sudah diterapkan TIDAK dihapus saat quantity berubah. Nominal
  // diskon persentase otomatis menyesuaikan subtotal baru, sedangkan diskon
  // nominal yang kini melebihi subtotal akan otomatis dijepit oleh kalkulator.
  // Perilaku ini dipilih agar kasir tidak kehilangan input diskon hanya karena
  // salah menekan tombol "-". Bila keranjang menjadi kosong, diskon ikut
  // direset lewat [clear] / [_commitItems].

  /// Menerapkan diskon pada keranjang.
  ///
  /// [type] menentukan cara potong (nominal atau persentase), [value] adalah
  /// nilainya. Memanggil dengan `type: DiscountType.none` atau `value: 0`
  /// berarti menghapus diskon.
  ///
  /// Mengembalikan [CartMutationResult.failure] berisi alasan bila input tidak
  /// sah. State TIDAK berubah saat validasi gagal.
  CartMutationResult applyDiscount({
    required DiscountType type,
    required int value,
  }) {
    // Validasi tunggal yang juga dipakai UI & repository. Hasilnya berupa
    // pesan siap tampil atau `null` bila aman.
    final error = DiscountCalculator.validate(
      subtotal: state.subtotal,
      type: type,
      value: value,
    );
    if (error != null) {
      return _reject(error);
    }

    // Nilai nol / jenis "none" diperlakukan sebagai permintaan menghapus
    // diskon, bukan sebagai diskon 0 yang aneh di riwayat transaksi.
    if (type == DiscountType.none || value <= 0) {
      emit(
        state.copyWith(
          discountType: DiscountType.none,
          discountValue: 0,
          clearError: true,
        ),
      );
      return const CartMutationResult.success();
    }

    emit(
      state.copyWith(
        discountType: type,
        discountValue: value,
        clearError: true,
      ),
    );

    // Pemeriksaan eksplisit sebagai dokumentasi hidup: apa pun input kasir,
    // state yang dihasilkan tidak boleh menghasilkan total negatif.
    assert(
      state.totalAmount >= 0,
      'Total tagihan tidak boleh minus setelah diskon diterapkan.',
    );

    return const CartMutationResult.success();
  }

  /// Menghapus diskon yang sedang aktif tanpa menyentuh item keranjang.
  void clearDiscount() {
    if (state.discountType == DiscountType.none &&
        state.discountValue == 0 &&
        state.errorMessage == null) {
      return;
    }
    emit(
      state.copyWith(
        discountType: DiscountType.none,
        discountValue: 0,
        clearError: true,
      ),
    );
  }

  /// Mencatat kegagalan ke state (agar tampil di panel keranjang) sekaligus
  /// mengembalikannya ke pemanggil (agar layar katalog bisa menampilkan
  /// snackbar).
  CartMutationResult _reject(String message) {
    emit(state.copyWith(errorMessage: message));
    return CartMutationResult.failure(message);
  }

  /// Menyimpan daftar item terbaru lalu membersihkan pesan kesalahan lama.
  ///
  /// Dipusatkan di satu helper karena semua aksi item (tambah, kurangi, hapus)
  /// punya kebutuhan yang sama:
  /// - bila keranjang menjadi kosong, diskon harus ikut direset (state baru),
  /// - bila masih ada item, diskon yang sudah dipilih dipertahankan.
  ///
  /// Pemusatan ini juga memastikan perubahan item tidak pernah "lupa" memakai
  /// state terbaru, yang bisa membuat diskon menempel pada subtotal lama.
  void _commitItems(List<CartItem> updatedItems) {
    if (updatedItems.isEmpty) {
      // Keranjang kosong: mulai dari state bersih tanpa diskon.
      if (state.discountType != DiscountType.none ||
          state.discountValue != 0 ||
          state.errorMessage != null) {
        emit(const CartState());
        return;
      }
      emit(state.copyWith(items: updatedItems, clearError: true));
      return;
    }

    emit(state.copyWith(items: updatedItems, clearError: true));
  }

  // ---------------------------------------------------------------------------
  // Helper validasi stok
  // ---------------------------------------------------------------------------

  /// Inti dari *Shared Stock Validation*.
  ///
  /// Mengembalikan pesan kesalahan bila penambahan [additionalQuantity] akan
  /// membuat akumulasi pemakaian melebihi stok; mengembalikan `null` bila aman.
  ///
  /// Alasan memakai satu helper untuk produk dan add-on: aturan bisnisnya
  /// identik (akumulasi lintas baris), sehingga tidak ada risiko dua tempat
  /// validasi yang perilakunya berbeda.
  ///
  /// Parameter:
  /// - [productId]/[productName]/[productStock]: identitas & stok produk.
  /// - [addonStocks]: id add-on -> stok database (snapshot baris).
  /// - [addonNames]: id add-on -> nama untuk pesan kesalahan.
  /// - [additionalQuantity]: jumlah unit yang ingin ditambahkan.
  String? _validateSharedStock({
    required int productId,
    required String productName,
    required int productStock,
    required Map<int, String> addonNames,
    required Map<int, int> addonStocks,
    required int additionalQuantity,
  }) {
    // ---- Langkah 1-3: validasi akumulasi stok PRODUK ----
    // `usedProduct` berasal dari SELURUH baris keranjang dengan product_id ini,
    // termasuk baris yang memiliki add-on berbeda.
    final usedProduct = state.productUsage(productId);
    final requestedProduct = usedProduct + additionalQuantity;

    if (requestedProduct > productStock) {
      return 'Stok $productName tidak cukup. Stok tersedia $productStock, '
          'sedangkan keranjang sudah memakai $usedProduct unit dari semua '
          'varian produk ini. Permintaan $additionalQuantity unit ditolak. '
          'Kurangi jumlah atau pilih varian lain.';
    }

    // ---- Langkah 4-5: validasi akumulasi stok setiap ADD-ON ----
    // Satu unit baris keranjang = satu unit setiap add-on yang menempel.
    // Karena itu `additionalQuantity` juga dipakai sebagai tambahan add-on.
    for (final entry in addonStocks.entries) {
      final addonId = entry.key;
      final addonStock = entry.value;
      final addonName = addonNames[addonId] ?? 'Add-on';

      final usedAddon = state.addonUsage(addonId);
      final requestedAddon = usedAddon + additionalQuantity;

      if (requestedAddon > addonStock) {
        return 'Stok add-on $addonName tidak cukup. Stok tersedia '
            '$addonStock, sedangkan keranjang sudah memakai $usedAddon unit '
            'dari semua produk yang memakai add-on ini. Permintaan '
            '$additionalQuantity unit ditolak. Kurangi jumlah atau lepas '
            'add-on tersebut.';
      }
    }

    // Semua batas aman.
    return null;
  }

  /// Membuang add-on dengan id duplikat, menyisakan kemunculan terakhir.
  List<PosAddon> _uniqueAddons(List<PosAddon> addons) {
    final byId = <int, PosAddon>{};
    for (final addon in addons) {
      byId[addon.id] = addon;
    }
    return byId.values.toList(growable: false);
  }
}
