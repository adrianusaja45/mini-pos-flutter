import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pos_offline/core/theme/app_theme.dart';
import 'package:mini_pos_offline/core/utils/currency_formatter.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/checkout_request.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/pos_addon.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/pos_catalog.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/pos_product.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/receipt_addon.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/receipt_item.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/transaction_receipt.dart';
import 'package:mini_pos_offline/features/pos/domain/repositories/pos_repository.dart';
import 'package:mini_pos_offline/features/pos/presentation/pages/pos_page.dart';

/// Repository palsu dengan respons checkout yang bisa dikendalikan test.
class _FakePosRepository implements PosRepository {
  @override
  Future<PosCatalog> loadCatalog() async {
    return const PosCatalog(
      products: [
        PosProduct(
          id: 1,
          categoryId: 1,
          categoryName: 'Minuman',
          name: 'Kopi Susu',
          price: 18000,
          stock: 5,
        ),
      ],
      addons: [PosAddon(id: 10, name: 'Extra Shot', price: 5000, stock: 5)],
    );
  }

  @override
  Future<TransactionReceipt> checkout(CheckoutRequest request) async {
    final subtotal = request.items.fold<int>(
      0,
      (total, item) => total + item.lineTotal,
    );
    final total = subtotal;

    return TransactionReceipt(
      transactionId: 1,
      invoiceNumber: 'INV-20261111-0001',
      cashierName: 'Kasir Uji',
      createdAt: DateTime(2026, 11, 11, 10, 30),
      items: request.items
          .map(
            (item) => ReceiptItem(
              productId: item.productId,
              productName: item.productName,
              unitPrice: item.unitPrice,
              quantity: item.quantity,
              lineSubtotal: item.lineTotal,
              addons: item.addons
                  .map(
                    (addon) => ReceiptAddon(
                      addonId: addon.addonId,
                      name: addon.name,
                      price: addon.price,
                      quantity: item.quantity,
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
      subtotal: subtotal,
      discountType: request.discountType,
      discountValue: request.discountValue,
      discountAmount: 0,
      totalAmount: total,
      cashReceived: request.cashReceived,
      changeAmount: request.cashReceived - total,
    );
  }
}

/// Pengujian alur pembayaran Tahap 5 dari sisi UI.
void main() {
  Widget buildPage() {
    return RepositoryProvider<PosRepository>.value(
      value: _FakePosRepository(),
      child: MaterialApp(theme: AppTheme.light, home: const PosPage()),
    );
  }

  testWidgets('kasir mengisi tunai, melihat kembalian, lalu masuk ke struk', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    // Tambah produk polos lewat bottom sheet add-on (tanpa memilih add-on).
    await tester.tap(find.text('Kopi Susu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    // Buka keranjang (layar ponsel) lalu tekan Bayar.
    await tester.tap(find.text('Keranjang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bayar'));
    await tester.pumpAndSettle();

    // Halaman pembayaran muncul dengan total tagihan 18.000.
    expect(find.text('Pembayaran'), findsOneWidget);
    expect(find.text('Total Tagihan'), findsOneWidget);
    expect(find.text(formatRupiah(18000)), findsWidgets);

    // Uang kurang: kembalian belum muncul, tombol konfirmasi nonaktif.
    await tester.enterText(find.byKey(const ValueKey('cash-input')), '10000');
    await tester.pump();
    expect(find.textContaining('Uang kurang'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Konfirmasi Bayar'))
          .onPressed,
      isNull,
    );

    // Uang cukup: kembalian dihitung real-time.
    await tester.enterText(find.byKey(const ValueKey('cash-input')), '20000');
    await tester.pump();
    expect(find.text('Kembalian ${formatRupiah(2000)}'), findsOneWidget);

    await tester.tap(find.text('Konfirmasi Bayar'));
    await tester.pumpAndSettle();

    // Halaman struk digital menampilkan snapshot transaksi.
    expect(find.text('Struk Digital'), findsOneWidget);
    expect(find.text('Pembayaran berhasil disimpan.'), findsOneWidget);
    expect(find.text('INV-20261111-0001'), findsOneWidget);
    expect(find.text('Kasir Uji'), findsOneWidget);
    expect(find.text('Kopi Susu'), findsOneWidget);
    expect(find.text('Tunai'), findsOneWidget);
    expect(find.text(formatRupiah(2000)), findsWidgets);

    // Tombol Selesai mengosongkan keranjang dan kembali ke katalog POS.
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    expect(find.text('Kasir'), findsOneWidget);
    // Keranjang sudah kosong: bar ringkasan menampilkan 0 unit.
    expect(find.textContaining('0 baris'), findsOneWidget);
  });
}
