import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/product.dart';
import '../../domain/failures/master_data_failure.dart';
import '../cubit/category_cubit.dart';
import '../cubit/master_data_status.dart';
import '../cubit/product_cubit.dart';
import '../cubit/product_state.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/master_data_empty_state.dart';
import '../widgets/master_data_info_chip.dart';
import 'product_form_page.dart';

/// Tab daftar produk.
///
/// Fitur utama:
/// - pencarian cepat berdasarkan nama/kategori,
/// - kartu produk dengan thumbnail foto permanen, harga, dan stok,
/// - tambah/ubah lewat halaman form (termasuk foto),
/// - hapus memakai soft delete agar riwayat transaksi aman.
class ProductTabPage extends StatefulWidget {
  const ProductTabPage({super.key});

  @override
  State<ProductTabPage> createState() => _ProductTabPageState();
}

class _ProductTabPageState extends State<ProductTabPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Membuka halaman form produk.
  ///
  /// Produk wajib memiliki kategori. Bila belum ada kategori sama sekali,
  /// kasir diarahkan ke tab Kategori terlebih dahulu.
  Future<void> _openForm(BuildContext context, {Product? product}) async {
    final categories = context.read<CategoryCubit>().state.categories;

    if (categories.isEmpty) {
      await _showNoCategoryDialog(context);
      return;
    }

    final cubit = context.read<ProductCubit>();
    cubit.clearFailure();
    cubit.clearNotice();

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        // Route baru berada di luar pohon widget tab, sehingga Cubit dioper
        // ulang memakai BlocProvider.value.
        builder: (_) => BlocProvider<ProductCubit>.value(
          value: cubit,
          child: ProductFormPage(categories: categories, product: product),
        ),
      ),
    );

    // Error dari form ditampilkan di halaman form. Setelah kembali ke daftar,
    // sisa error dibersihkan agar form berikutnya dimulai dari kondisi bersih.
    if (context.mounted) cubit.clearFailure();
  }

  /// Dialog pengarah saat kategori belum tersedia.
  Future<void> _showNoCategoryDialog(BuildContext context) async {
    final goToCategory = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.category_outlined),
        title: const Text('Kategori belum tersedia'),
        content: const Text(
          'Setiap produk harus memiliki kategori. Tambahkan minimal satu '
          'kategori terlebih dahulu, lalu kembali ke tab Produk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Buat Kategori'),
          ),
        ],
      ),
    );

    if (goToCategory == true && context.mounted) {
      // Pindah ke tab Kategori pada halaman Master Data.
      DefaultTabController.of(context).animateTo(0);
    }
  }

  /// Konfirmasi lalu menghapus produk (soft delete).
  Future<void> _deleteProduct(BuildContext context, Product product) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Hapus produk "${product.name}"?',
      message:
          'Produk akan disembunyikan dari katalog dan tidak bisa dipilih saat '
          'transaksi baru. Riwayat transaksi tetap utuh karena struk menyimpan '
          'salinan nama dan harga produk.',
    );

    if (!confirmed || !context.mounted) return;

    await context.read<ProductCubit>().deleteProduct(product.id);
    if (!context.mounted) return;

    // Kegagalan hapus ditangani di sini karena berasal dari daftar, bukan form.
    final failure = context.read<ProductCubit>().state.failure;
    if (failure != null) {
      _handleFailure(context, failure);
    }
  }

  /// Menampilkan kegagalan operasi hapus produk.
  void _handleFailure(BuildContext context, MasterDataFailure failure) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure.message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
    context.read<ProductCubit>().clearFailure();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProductCubit, ProductState>(
      listenWhen: (previous, current) => previous.notice != current.notice,
      listener: (context, state) {
        final notice = state.notice;
        if (notice != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(notice)));
          context.read<ProductCubit>().clearNotice();
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: state.isSaving ? null : () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Produk Baru'),
          ),
          body: Column(
            children: [
              // Kolom pencarian hanya muncul bila sudah ada produk, sehingga
              // layar kosong tetap bersih dan fokus pada tombol tambah.
              if (state.products.isNotEmpty) _buildSearchField(),
              Expanded(child: _buildContent(context, state)),
            ],
          ),
        );
      },
    );
  }

  /// Kolom pencarian lokal (filter dilakukan di memori, tanpa query ulang).
  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cari nama produk atau kategori...',
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

  Widget _buildContent(BuildContext context, ProductState state) {
    if (state.status == MasterDataStatus.loading && state.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.products.isEmpty) {
      final isFailure = state.status == MasterDataStatus.failure;
      return _buildScrollable(
        MasterDataEmptyState(
          icon: isFailure
              ? Icons.cloud_off_outlined
              : Icons.shopping_bag_outlined,
          title: isFailure ? 'Gagal memuat produk' : 'Belum ada produk',
          message:
              state.failure?.message ??
              'Tambahkan produk yang dijual beserta harga, stok, dan fotonya '
                  'agar kasir bisa memilihnya saat transaksi.',
          actionLabel: isFailure ? 'Coba Lagi' : 'Tambah Produk',
          onAction: isFailure
              ? () => context.read<ProductCubit>().load()
              : () => _openForm(context),
        ),
      );
    }

    final query = _searchController.text.trim().toLowerCase();
    final products = query.isEmpty
        ? state.products
        : state.products
              .where(
                (product) =>
                    product.name.toLowerCase().contains(query) ||
                    product.categoryName.toLowerCase().contains(query),
              )
              .toList();

    if (products.isEmpty) {
      return _buildScrollable(
        MasterDataEmptyState(
          icon: Icons.search_off_outlined,
          title: 'Produk tidak ditemukan',
          message:
              'Tidak ada produk yang cocok dengan "$query". Coba kata kunci '
              'lain atau hapus pencarian.',
          actionLabel: 'Hapus Pencarian',
          onAction: () {
            _searchController.clear();
            setState(() {});
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<ProductCubit>().load(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildProductCard(context, state, product);
        },
      ),
    );
  }

  /// Kartu ringkas satu produk.
  Widget _buildProductCard(
    BuildContext context,
    ProductState state,
    Product product,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: state.isSaving
            ? null
            : () => _openForm(context, product: product),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildThumbnail(context, product),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        MasterDataInfoChip(
                          icon: Icons.category_outlined,
                          label: product.categoryName,
                        ),
                        MasterDataInfoChip(
                          icon: Icons.inventory_2_outlined,
                          label: 'Stok ${product.stock}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatRupiah(product.price),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Tombol ditumpuk vertikal agar tidak memakan lebar nama produk
              // pada layar ponsel.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Ubah produk',
                    visualDensity: VisualDensity.compact,
                    onPressed: state.isSaving
                        ? null
                        : () => _openForm(context, product: product),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Hapus produk',
                    visualDensity: VisualDensity.compact,
                    color: colorScheme.error,
                    onPressed: state.isSaving
                        ? null
                        : () => _deleteProduct(context, product),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Thumbnail foto produk dari path permanen.
  ///
  /// Bila produk belum punya foto atau file hilang, ditampilkan ikon makanan
  /// sebagai pengganti agar layout tetap rapi.
  Widget _buildThumbnail(BuildContext context, Product product) {
    final colorScheme = Theme.of(context).colorScheme;
    final imagePath = product.imagePath;

    Widget placeholder() {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.fastfood_outlined,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 64,
        height: 64,
        child: imagePath == null
            ? placeholder()
            : Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder(),
              ),
      ),
    );
  }

  /// Pembungkus empty state agar tetap bisa di-refresh dan berada di tengah.
  Widget _buildScrollable(Widget child) {
    return RefreshIndicator(
      onRefresh: () => context.read<ProductCubit>().load(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
