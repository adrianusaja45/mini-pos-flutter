import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pos_offline/core/theme/app_theme.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/discount_type.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/receipt_addon.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/receipt_item.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/transaction_receipt.dart';
import 'package:mini_pos_offline/features/report/domain/entities/report_transaction.dart';
import 'package:mini_pos_offline/features/report/domain/entities/sales_summary.dart';
import 'package:mini_pos_offline/features/report/domain/repositories/report_repository.dart';
import 'package:mini_pos_offline/features/report/presentation/pages/report_page.dart';

/// Repository laporan palsu: mengembalikan data tetap tanpa menyentuh SQLite.
class _FakeReportRepository implements ReportRepository {
  @override
  Future<SalesSummary> getSalesSummary() async {
    return const SalesSummary(totalRevenue: 96000, totalTransactions: 2);
  }

  @override
  Future<List<ReportTransaction>> getTransactions() async {
    return [
      ReportTransaction(
        transactionId: 2,
        invoiceNumber: 'INV-20261111-0001',
        cashierName: 'Kasir Uji',
        createdAt: DateTime.utc(2026, 11, 11, 10),
        totalAmount: 46000,
      ),
      ReportTransaction(
        transactionId: 1,
        invoiceNumber: 'INV-20261110-0001',
        cashierName: 'Kasir Uji',
        createdAt: DateTime.utc(2026, 11, 10, 9),
        totalAmount: 50000,
      ),
    ];
  }

  @override
  Future<TransactionReceipt> getReceipt(int transactionId) async {
    return TransactionReceipt(
      transactionId: transactionId,
      invoiceNumber: 'INV-20261111-0001',
      cashierName: 'Kasir Uji',
      createdAt: DateTime.utc(2026, 11, 11, 10).toLocal(),
      items: [
        ReceiptItem(
          productId: 1,
          productName: 'Kopi Susu',
          unitPrice: 18000,
          quantity: 2,
          lineSubtotal: 46000,
          addons: const [
            ReceiptAddon(
              addonId: 1,
              name: 'Extra Shot',
              price: 5000,
              quantity: 2,
            ),
          ],
        ),
      ],
      subtotal: 46000,
      discountType: DiscountType.none,
      discountValue: 0,
      discountAmount: 0,
      totalAmount: 46000,
      cashReceived: 56000,
      changeAmount: 10000,
    );
  }
}

/// Pengujian tampilan halaman laporan: ringkasan, riwayat, dan struk historis.
void main() {
  /// Menyiapkan ukuran layar ponsel agar pengujian mirip perangkat kasir.
  Future<void> pumpReportPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      // Provider diletakkan DI ATAS MaterialApp agar route baru (halaman struk)
      // tetap bisa membaca repository, sama seperti komposisi di main.dart.
      RepositoryProvider<ReportRepository>.value(
        value: _FakeReportRepository(),
        child: MaterialApp(theme: AppTheme.light, home: const ReportPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan ringkasan dan daftar riwayat transaksi', (
    tester,
  ) async {
    await pumpReportPage(tester);

    expect(find.text('Ringkasan Penjualan'), findsOneWidget);
    expect(find.text('Rp 96.000'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Riwayat Transaksi'), findsOneWidget);
    expect(find.text('INV-20261111-0001'), findsOneWidget);
    expect(find.text('INV-20261110-0001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mengetuk riwayat membuka struk hasil snapshot', (tester) async {
    await pumpReportPage(tester);

    await tester.tap(find.text('INV-20261111-0001'));
    await tester.pumpAndSettle();

    expect(find.text('Struk Historis'), findsOneWidget);
    expect(find.text('Struk dari riwayat transaksi'), findsOneWidget);
    // Nama & harga produk dari snapshot tampil di kartu struk.
    expect(find.text('Kopi Susu'), findsOneWidget);
    expect(find.text('+ Extra Shot x 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
