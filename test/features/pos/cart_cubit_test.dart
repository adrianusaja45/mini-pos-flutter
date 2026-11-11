import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/pos_addon.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/pos_product.dart';
import 'package:mini_pos_offline/features/pos/presentation/cubit/cart_cubit.dart';

/// Pengujian aturan keranjang & *Shared Stock Validation* (Tahap 4).
///
/// Cubit keranjang sengaja tidak menyentuh SQLite, sehingga test ini murni
/// menguji logika bisnis tanpa membuka database.
void main() {
  const kopiSusu = PosProduct(
    id: 1,
    categoryId: 1,
    categoryName: 'Minuman',
    name: 'Kopi Susu',
    price: 18000,
    stock: 3,
  );

  const extraShot = PosAddon(id: 10, name: 'Extra Shot', price: 5000, stock: 2);

  const boba = PosAddon(id: 11, name: 'Boba', price: 4000, stock: 5);

  test('kombinasi produk + add-on identik digabung menjadi satu baris', () {
    // Stok dibuat longgar agar test ini fokus pada aturan penggabungan baris,
    // bukan pada validasi stok (yang diuji terpisah di bawah).
    const produk = PosProduct(
      id: 1,
      categoryId: 1,
      categoryName: 'Minuman',
      name: 'Kopi Susu',
      price: 18000,
      stock: 10,
    );
    const addonA = PosAddon(id: 10, name: 'Extra Shot', price: 5000, stock: 10);
    const addonB = PosAddon(id: 11, name: 'Boba', price: 4000, stock: 10);
    final cubit = CartCubit();

    expect(cubit.addProduct(product: produk).isSuccess, isTrue);
    expect(
      cubit.addProduct(product: produk, addons: [addonA]).isSuccess,
      isTrue,
    );
    expect(
      cubit
          .addProduct(product: produk, addons: [addonA], quantity: 1)
          .isSuccess,
      isTrue,
    );

    // Dua baris: polos dan + Extra Shot.
    expect(cubit.state.items.length, 2);

    final withAddon = cubit.state.items.firstWhere(
      (item) => item.addons.isNotEmpty,
    );
    expect(withAddon.quantity, 2);

    // Urutan centang add-on yang berbeda tetap dianggap kombinasi sama.
    expect(
      cubit.addProduct(product: produk, addons: [addonB, addonA]).isSuccess,
      isTrue,
    );
    expect(
      cubit.addProduct(product: produk, addons: [addonA, addonB]).isSuccess,
      isTrue,
    );
    expect(cubit.state.items.length, 3);
    expect(
      cubit.state.items.firstWhere((item) => item.addons.length == 2).quantity,
      2,
    );
  });

  test('akumulasi stok produk dihitung dari semua varian di keranjang', () {
    // Stok hanya 2, tetapi keranjang akan diisi lewat dua varian berbeda.
    const produkStokDua = PosProduct(
      id: 1,
      categoryId: 1,
      categoryName: 'Minuman',
      name: 'Kopi Susu',
      price: 18000,
      stock: 2,
    );
    final cubit = CartCubit();

    expect(cubit.addProduct(product: produkStokDua).isSuccess, isTrue);
    expect(
      cubit.addProduct(product: produkStokDua, addons: [extraShot]).isSuccess,
      isTrue,
    );

    // Total pemakaian produk = 1 polos + 1 varian = 2 (sudah penuh).
    expect(cubit.state.productUsage(produkStokDua.id), 2);

    // Menambah varian apa pun harus ditolak karena stok bersama sudah habis.
    final result = cubit.addProduct(product: produkStokDua, addons: [boba]);
    expect(result.isSuccess, isFalse);
    expect(result.message, contains('Stok Kopi Susu tidak cukup'));
    expect(cubit.state.errorMessage, contains('Stok Kopi Susu tidak cukup'));
    expect(cubit.state.productUsage(produkStokDua.id), 2);
  });

  test('akumulasi stok add-on dihitung lintas baris keranjang', () {
    const produkStokBanyak = PosProduct(
      id: 2,
      categoryId: 1,
      categoryName: 'Minuman',
      name: 'Teh',
      price: 8000,
      stock: 10,
    );
    const extraShotStokSatu = PosAddon(
      id: 10,
      name: 'Extra Shot',
      price: 5000,
      stock: 1,
    );
    final cubit = CartCubit();

    expect(
      cubit
          .addProduct(product: produkStokBanyak, addons: [extraShotStokSatu])
          .isSuccess,
      isTrue,
    );

    // Add-on yang sama dipakai produk lain -> tetap dihitung bersama.
    final result = cubit.addProduct(
      product: kopiSusu,
      addons: [extraShotStokSatu],
    );
    expect(result.isSuccess, isFalse);
    expect(result.message, contains('Stok add-on Extra Shot tidak cukup'));
    expect(cubit.state.addonUsage(extraShotStokSatu.id), 1);
  });

  test('tombol + ditolak bila akumulasi produk sudah mencapai stok', () {
    const produkStokDua = PosProduct(
      id: 1,
      categoryId: 1,
      categoryName: 'Minuman',
      name: 'Kopi Susu',
      price: 18000,
      stock: 2,
    );
    final cubit = CartCubit();

    cubit.addProduct(product: produkStokDua);
    cubit.addProduct(product: produkStokDua, addons: [extraShot]);

    final signature = cubit.state.items
        .firstWhere((item) => item.addons.isEmpty)
        .signature;

    final result = cubit.increaseQuantity(signature);
    expect(result.isSuccess, isFalse);
    expect(result.message, contains('sudah memakai 2 unit'));
    // Quantity tidak boleh berubah saat validasi gagal.
    expect(
      cubit.state.items
          .firstWhere((item) => item.signature == signature)
          .quantity,
      1,
    );
  });

  test('tombol + ditolak bila akumulasi add-on sudah mencapai stok', () {
    const addonStokSatu = PosAddon(
      id: 10,
      name: 'Extra Shot',
      price: 5000,
      stock: 1,
    );
    final cubit = CartCubit();

    cubit.addProduct(product: kopiSusu, addons: [addonStokSatu]);
    final signature = cubit.state.items.single.signature;

    final result = cubit.increaseQuantity(signature);
    expect(result.isSuccess, isFalse);
    expect(result.message, contains('Stok add-on Extra Shot tidak cukup'));
    expect(cubit.state.items.single.quantity, 1);
  });

  test('tombol - menghapus baris saat quantity tersisa satu', () {
    final cubit = CartCubit();
    cubit.addProduct(product: kopiSusu);

    final signature = cubit.state.items.single.signature;
    expect(cubit.decreaseQuantity(signature).isSuccess, isTrue);
    expect(cubit.state.isEmpty, isTrue);
  });

  test('jumlah nol ditolak sebelum menyentuh keranjang', () {
    final cubit = CartCubit();

    final result = cubit.addProduct(product: kopiSusu, quantity: 0);
    expect(result.isSuccess, isFalse);
    expect(cubit.state.isEmpty, isTrue);
  });
}
