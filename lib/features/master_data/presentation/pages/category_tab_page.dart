import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/category.dart';
import '../../domain/failures/master_data_failure.dart';
import '../cubit/category_cubit.dart';
import '../cubit/category_state.dart';
import '../cubit/master_data_status.dart';
import '../widgets/category_form_sheet.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/master_data_empty_state.dart';

/// Tab daftar kategori.
///
/// Aksi yang tersedia:
/// - ketuk kartu / ikon pensil -> ubah nama kategori,
/// - ikon tempat sampah -> hapus (dengan konfirmasi),
/// - tombol "Kategori Baru" -> tambah kategori.
class CategoryTabPage extends StatelessWidget {
  const CategoryTabPage({super.key});

  /// Membuka bottom sheet form kategori.
  ///
  /// Cubit dioper memakai `BlocProvider.value` karena bottom sheet berada di
  /// overlay Navigator, sehingga tidak otomatis mewarisi provider di bawahnya.
  Future<void> _openForm(BuildContext context, {Category? category}) async {
    final cubit = context.read<CategoryCubit>();
    cubit.clearFailure();
    cubit.clearNotice();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider<CategoryCubit>.value(
        value: cubit,
        child: CategoryFormSheet(category: category),
      ),
    );

    // Setelah sheet ditutup, bersihkan sisa error agar tidak terbawa saat
    // form dibuka kembali. Error yang muncul selama form terbuka ditampilkan
    // oleh form itu sendiri (bukan oleh listener tab).
    if (context.mounted) cubit.clearFailure();
  }

  /// Konfirmasi lalu menghapus kategori.
  Future<void> _deleteCategory(BuildContext context, Category category) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Hapus kategori "${category.name}"?',
      message:
          'Kategori hanya dapat dihapus bila tidak ada produk yang memakainya. '
          'Produk yang sudah dihapus dari katalog tetap terhubung ke kategori '
          'ini demi keutuhan riwayat transaksi.',
    );

    if (!confirmed || !context.mounted) return;

    await context.read<CategoryCubit>().deleteCategory(category.id);
    if (!context.mounted) return;

    // Kegagalan hapus ditangani di sini (bukan di listener) karena aksi ini
    // berasal dari daftar, bukan dari form.
    final failure = context.read<CategoryCubit>().state.failure;
    if (failure != null) {
      _handleFailure(context, failure);
    }
  }

  /// Menampilkan kegagalan operasi hapus kategori.
  void _handleFailure(BuildContext context, MasterDataFailure failure) {
    if (failure.type == MasterDataFailureType.categoryInUse) {
      // Kasus utama Tahap 3: ON DELETE RESTRICT. Dialog dipakai (bukan
      // snackbar) karena kasir perlu membaca penjelasan dan mengambil
      // tindakan lanjutan.
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            Icons.link_off_rounded,
            color: Theme.of(dialogContext).colorScheme.error,
          ),
          title: const Text('Kategori tidak bisa dihapus'),
          content: Text(failure.message),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }

    // Pesan ditandai sudah ditampilkan agar tidak muncul lagi saat rebuild.
    context.read<CategoryCubit>().clearFailure();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CategoryCubit, CategoryState>(
      listenWhen: (previous, current) => previous.notice != current.notice,
      listener: (context, state) {
        final notice = state.notice;
        if (notice != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(notice)));
          context.read<CategoryCubit>().clearNotice();
        }
      },
      builder: (context, state) {
        return Scaffold(
          // Latar transparan agar warna scaffold induk tetap terlihat.
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Kategori Baru'),
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, CategoryState state) {
    // Spinner hanya untuk pemuatan pertama. Saat refresh, daftar lama tetap
    // ditampilkan agar layar tidak "berkedip".
    if (state.status == MasterDataStatus.loading && state.categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.categories.isEmpty) {
      final isFailure = state.status == MasterDataStatus.failure;
      return _buildScrollable(
        context,
        MasterDataEmptyState(
          icon: isFailure ? Icons.cloud_off_outlined : Icons.category_outlined,
          title: isFailure ? 'Gagal memuat kategori' : 'Belum ada kategori',
          message:
              state.failure?.message ??
              'Tambahkan kategori pertama, misalnya "Makanan" atau '
                  '"Minuman", agar produk bisa dikelompokkan.',
          actionLabel: isFailure ? 'Coba Lagi' : 'Tambah Kategori',
          onAction: isFailure
              ? () => context.read<CategoryCubit>().load()
              : () => _openForm(context),
        ),
      );
    }

    return RefreshIndicator(
      // Tarik ke bawah untuk memuat ulang data dari SQLite.
      onRefresh: () => context.read<CategoryCubit>().load(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        // Padding bawah memberi ruang agar item terakhir tidak tertutup FAB.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: state.categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final category = state.categories[index];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.category_outlined,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                category.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                category.productCount == 0
                    ? 'Belum ada produk aktif'
                    : '${category.productCount} produk aktif',
              ),
              onTap: state.isSaving
                  ? null
                  : () => _openForm(context, category: category),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Ubah kategori',
                    visualDensity: VisualDensity.compact,
                    onPressed: state.isSaving
                        ? null
                        : () => _openForm(context, category: category),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Hapus kategori',
                    visualDensity: VisualDensity.compact,
                    color: Theme.of(context).colorScheme.error,
                    onPressed: state.isSaving
                        ? null
                        : () => _deleteCategory(context, category),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Membungkus empty/error state agar tetap bisa ditarik untuk refresh dan
  /// tetap berada di tengah layar.
  Widget _buildScrollable(BuildContext context, Widget child) {
    return RefreshIndicator(
      onRefresh: () => context.read<CategoryCubit>().load(),
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
