import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pos_offline/core/theme/app_theme.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/pos_addon.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/pos_catalog.dart';
import 'package:mini_pos_offline/features/pos/domain/entities/pos_product.dart';
import 'package:mini_pos_offline/features/pos/domain/repositories/pos_repository.dart';
import 'package:mini_pos_offline/features/pos/presentation/pages/pos_page.dart';
import 'package:mini_pos_offline/features/pos/presentation/widgets/cart_panel.dart';

/// Repository palsu agar test UI tidak membuka SQLite.
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
          stock: 2,
        ),
        PosProduct(
          id: 2,
          categoryId: 1,
          categoryName: 'Minuman',
          name: 'Es Teh',
          price: 8000,
          stock: 0,
        ),
      ],
      addons: [PosAddon(id: 10, name: 'Extra Shot', price: 5000, stock: 5)],
    );
  }
}

/// Pengujian alur layar kasir (Tahap 4).
void main() {
  Widget buildPage() {
    return RepositoryProvider<PosRepository>.value(
      value: _FakePosRepository(),
      child: MaterialApp(theme: AppTheme.light, home: const PosPage()),
    );
  }

  testWidgets('katalog menampilkan produk, sisa stok, dan overlay habis', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('Kopi Susu'), findsOneWidget);
    expect(find.text('Sisa 2'), findsOneWidget);

    // Produk stok 0 tetap tampil tetapi ditandai HABIS.
    expect(find.text('HABIS'), findsOneWidget);
  });

  testWidgets('pencarian instan menyaring katalog berdasarkan nama', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'teh');
    await tester.pump();

    expect(find.text('Es Teh'), findsOneWidget);
    expect(find.text('Kopi Susu'), findsNothing);
  });

  testWidgets('produk dengan add-on dibuka lewat bottom sheet lalu masuk '
      'keranjang', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    // Ketuk kartu produk -> bottom sheet pemilihan add-on.
    await tester.tap(find.text('Kopi Susu'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih add-on (opsional)'), findsOneWidget);

    await tester.tap(find.text('Extra Shot'));
    await tester.pump();
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    // Sisa stok produk di kartu langsung berkurang setelah masuk keranjang.
    expect(find.text('Sisa 1'), findsOneWidget);

    // Buka keranjang pada layar ponsel.
    await tester.tap(find.text('Keranjang'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(CartPanel),
        matching: find.text('Kopi Susu'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(CartPanel),
        matching: find.text('Extra Shot'),
      ),
      findsOneWidget,
    );
    // Total = (18.000 + 5.000) x 1.
    expect(
      find.descendant(
        of: find.byType(CartPanel),
        matching: find.text('Rp 23.000'),
      ),
      findsWidgets,
    );
  });
}
