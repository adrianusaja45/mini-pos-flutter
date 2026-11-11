import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/pos_category.dart';
import '../../domain/entities/pos_product.dart';
import '../../domain/repositories/pos_repository.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/cart_state.dart';
import '../cubit/pos_catalog_cubit.dart';
import '../cubit/pos_catalog_state.dart';
import '../widgets/addon_selection_sheet.dart';
import '../widgets/cart_panel.dart';
import '../widgets/cart_snackbar.dart';
import '../widgets/product_catalog_card.dart';

/// Layar kasir (POS) untuk memilih produk dan menyiapkan keranjang.
///
/// Layout responsif:
/// - Layar lebar (>= 900 px): katalog di kiri, panel keranjang menetap di kanan.
/// - Layar ponsel: katalog penuh, keranjang dibuka lewat bar ringkasan di bawah.
///
/// Tahap ini sengaja berhenti pada keranjang; pembayaran belum dibuat.
class PosPage extends StatelessWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Repository POS disediakan di main.dart dan membungkus repository master
    // data, sehingga tidak ada query SQL baru di fitur ini.
    final repository = context.read<PosRepository>();

    return MultiBlocProvider(
      providers: [
        // Cubit katalog memuat produk + add-on sekali saat halaman dibuka.
        BlocProvider(create: (_) => PosCatalogCubit(repository)..load()),
        // Cubit keranjang murni in-memory; tidak menyentuh database.
        BlocProvider(create: (_) => CartCubit()),
      ],
      child: const _PosView(),
    );
  }
}

class _PosView extends StatefulWidget {
  const _PosView();

  @override
  State<_PosView> createState() => _PosViewState();
}

class _PosViewState extends State<_PosView> {
  final _searchController = TextEditingController();

  /// Kategori yang sedang dipilih; `null` berarti chip "Semua".
  int? _selectedCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCatalogCubit, PosCatalogState>(
      builder: (context, catalogState) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Ambang 900 px dipilih agar tablet lanskap sudah bisa memakai
            // panel keranjang menetap (kasir tidak perlu buka-tutup sheet).
            final isWide = constraints.maxWidth >= 900;

            return Scaffold(
              appBar: AppBar(title: const Text('Kasir')),
              body: _buildBody(context, catalogState, isWide),
              bottomNavigationBar:
                  !isWide &&
                      catalogState.status == PosCatalogStatus.ready &&
                      catalogState.products.isNotEmpty
                  ? _CartSummaryBar(onOpenCart: () => _openCartSheet(context))
                  : null,
            );
          },
        );
      },
    );
  }

  /// Menentukan isi halaman sesuai status katalog & lebar layar.
  Widget _buildBody(
    BuildContext context,
    PosCatalogState catalogState,
    bool isWide,
  ) {
    if (catalogState.status == PosCatalogStatus.loading &&
        catalogState.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (catalogState.status == PosCatalogStatus.failure &&
        catalogState.products.isEmpty) {
      return _buildLoadFailure(context, catalogState);
    }

    if (catalogState.products.isEmpty) {
      return _buildEmptyCatalog(context);
    }

    final catalog = _buildCatalog(context, catalogState);

    if (!isWide) return catalog;

    return Row(
      children: [
        Expanded(child: catalog),
        const VerticalDivider(width: 1),
        const SizedBox(width: 360, child: CartPanel()),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Katalog
  // ---------------------------------------------------------------------------

  /// Kolom pencarian + chip kategori + grid produk.
  Widget _buildCatalog(BuildContext context, PosCatalogState state) {
    final categories = state.categories;
    // Bila kategori terpilih sudah tidak ada (mis. karena data berubah),
    // filter dianggap "Semua" agar layar tidak kosong tanpa alasan jelas.
    final activeCategoryId =
        categories.any((category) => category.id == _selectedCategoryId)
        ? _selectedCategoryId
        : null;

    final products = _filteredProducts(state, activeCategoryId);

    return Column(
      children: [
        _buildSearchField(),
        if (categories.isNotEmpty)
          _buildCategoryChips(categories, activeCategoryId),
        Expanded(
          child: BlocBuilder<CartCubit, CartState>(
            builder: (context, cartState) {
              if (products.isEmpty) return _buildNoResult(context);

              return LayoutBuilder(
                builder: (context, constraints) {
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridColumnCount(constraints.maxWidth),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 212,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      // Sisa stok = stok database - akumulasi pemakaian di
                      // keranjang dari SEMUA varian produk tersebut.
                      final remaining = math.max(
                        0,
                        product.stock - cartState.productUsage(product.id),
                      );

                      return ProductCatalogCard(
                        product: product,
                        remainingStock: remaining,
                        addonCount: state.addons.length,
                        onTap: () => _handleProductTap(
                          context,
                          product,
                          state,
                          cartState,
                        ),
                        onQuickAdd: () => _quickAddPlain(context, product),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Jumlah kolom grid mengikuti lebar area katalog (bukan lebar layar) agar
  /// tetap proporsional saat panel keranjang memakan ruang di layar lebar.
  int _gridColumnCount(double width) {
    if (width >= 1200) return 5;
    if (width >= 900) return 4;
    if (width >= 620) return 3;
    return 2;
  }

  /// Filter instan di memori: kategori + pencarian nama produk.
  ///
  /// Tidak ada query ulang ke SQLite karena katalog sudah dimuat utuh; ini
  /// membuat pencarian terasa instan saat kasir mengetik cepat.
  List<PosProduct> _filteredProducts(
    PosCatalogState state,
    int? activeCategoryId,
  ) {
    final query = _searchController.text.trim().toLowerCase();

    return state.products
        .where((product) {
          final matchesCategory =
              activeCategoryId == null ||
              product.categoryId == activeCategoryId;
          final matchesQuery =
              query.isEmpty || product.name.toLowerCase().contains(query);
          return matchesCategory && matchesQuery;
        })
        .toList(growable: false);
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cari nama produk...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Hapus pencarian',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close),
                ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  /// Chip filter kategori, termasuk chip "Semua" untuk mereset filter.
  Widget _buildCategoryChips(
    List<PosCategory> categories,
    int? activeCategoryId,
  ) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('Semua'),
              selected: activeCategoryId == null,
              onSelected: (_) => setState(() => _selectedCategoryId = null),
            ),
          ),
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(category.name),
                selected: activeCategoryId == category.id,
                onSelected: (_) =>
                    setState(() => _selectedCategoryId = category.id),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Aksi produk
  // ---------------------------------------------------------------------------

  /// Aksi saat kartu produk diketuk.
  ///
  /// - Tanpa add-on aktif: produk langsung masuk keranjang (satu ketukan).
  /// - Ada add-on: buka bottom sheet agar kasir bisa memilih varian.
  Future<void> _handleProductTap(
    BuildContext context,
    PosProduct product,
    PosCatalogState catalog,
    CartState cart,
  ) async {
    final remainingProduct = math.max(
      0,
      product.stock - cart.productUsage(product.id),
    );
    if (remainingProduct <= 0) return;

    final cartCubit = context.read<CartCubit>();

    if (!catalog.hasAddons) {
      showCartResultMessage(context, cartCubit.addProduct(product: product));
      return;
    }

    // Sisa stok add-on dihitung dengan aturan yang sama seperti validasi:
    // stok database - akumulasi add-on tersebut di seluruh keranjang.
    final remainingAddonStock = {
      for (final addon in catalog.addons)
        addon.id: math.max(0, addon.stock - cart.addonUsage(addon.id)),
    };

    final selection = await showModalBottomSheet<AddonSelectionResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddonSelectionSheet(
        product: product,
        addons: catalog.addons,
        remainingProductStock: remainingProduct,
        remainingAddonStock: remainingAddonStock,
      ),
    );

    if (selection == null || !context.mounted) return;

    // Validasi final tetap di Cubit; sheet hanya membantu menampilkan batas.
    showCartResultMessage(
      context,
      cartCubit.addProduct(
        product: product,
        addons: selection.addons,
        quantity: selection.quantity,
      ),
    );
  }

  /// Menambahkan produk polos tanpa membuka sheet add-on (tombol "+").
  void _quickAddPlain(BuildContext context, PosProduct product) {
    showCartResultMessage(
      context,
      context.read<CartCubit>().addProduct(product: product),
    );
  }

  // ---------------------------------------------------------------------------
  // Keranjang mobile
  // ---------------------------------------------------------------------------

  /// Membuka panel keranjang sebagai bottom sheet pada layar ponsel.
  Future<void> _openCartSheet(BuildContext context) {
    final cartCubit = context.read<CartCubit>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        // Route bottom sheet berada di luar pohon widget PosPage, sehingga
        // Cubit dioper ulang memakai BlocProvider.value.
        child: BlocProvider<CartCubit>.value(
          value: cartCubit,
          child: const CartPanel(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tampilan status kosong / gagal
  // ---------------------------------------------------------------------------

  Widget _buildLoadFailure(BuildContext context, PosCatalogState state) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Gagal memuat katalog',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              state.failure?.message ?? 'Silakan coba lagi.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.read<PosCatalogCubit>().load(),
              style: FilledButton.styleFrom(minimumSize: const Size(180, 48)),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCatalog(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada produk',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tambahkan produk beserta stoknya di menu Master Data agar bisa '
              'dipilih pada layar kasir.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tampilan saat filter/pencarian tidak menghasilkan produk.
  Widget _buildNoResult(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Produk tidak ditemukan',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Coba kata kunci lain atau pilih kategori yang berbeda.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() => _selectedCategoryId = null);
              },
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Reset Filter'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bar ringkasan keranjang di bagian bawah layar ponsel.
///
/// Menampilkan total & jumlah unit secara langsung agar kasir tidak perlu
/// membuka keranjang hanya untuk melihat nominal belanja.
class _CartSummaryBar extends StatelessWidget {
  const _CartSummaryBar({required this.onOpenCart});

  final VoidCallback onOpenCart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        return Material(
          elevation: 8,
          color: colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${state.lineCount} baris • '
                          '${state.totalQuantity} unit',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatRupiah(state.subtotal),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: state.isEmpty ? null : onOpenCart,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(140, 48),
                    ),
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: const Text('Keranjang'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
