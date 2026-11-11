import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/addon.dart';
import '../../domain/failures/master_data_failure.dart';
import '../cubit/addon_cubit.dart';
import '../cubit/addon_state.dart';
import '../cubit/master_data_status.dart';
import '../widgets/addon_form_sheet.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/master_data_empty_state.dart';
import '../widgets/master_data_info_chip.dart';

/// Tab daftar add-on (topping/tambahan).
///
/// Add-on memiliki harga dan stok sendiri. Penghapusan memakai soft delete
/// agar transaksi lama yang memakai add-on ini tetap valid.
class AddonTabPage extends StatelessWidget {
  const AddonTabPage({super.key});

  /// Membuka bottom sheet form add-on.
  Future<void> _openForm(BuildContext context, {Addon? addon}) async {
    final cubit = context.read<AddonCubit>();
    cubit.clearFailure();
    cubit.clearNotice();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider<AddonCubit>.value(
        value: cubit,
        child: AddonFormSheet(addon: addon),
      ),
    );

    // Error selama form terbuka ditampilkan oleh form; bersihkan setelah
    // sheet ditutup agar tidak terbawa ke pembukaan berikutnya.
    if (context.mounted) cubit.clearFailure();
  }

  /// Konfirmasi lalu menghapus add-on.
  Future<void> _deleteAddon(BuildContext context, Addon addon) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Hapus add-on "${addon.name}"?',
      message:
          'Add-on akan disembunyikan dari pilihan saat transaksi baru. Riwayat '
          'transaksi yang memakainya tetap tersimpan karena struk memuat '
          'salinan nama dan harga add-on.',
    );

    if (!confirmed || !context.mounted) return;

    await context.read<AddonCubit>().deleteAddon(addon.id);
    if (!context.mounted) return;

    // Kegagalan hapus ditangani di sini karena berasal dari daftar, bukan form.
    final failure = context.read<AddonCubit>().state.failure;
    if (failure != null) {
      _handleFailure(context, failure);
    }
  }

  /// Menampilkan kegagalan operasi hapus add-on.
  void _handleFailure(BuildContext context, MasterDataFailure failure) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure.message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
    context.read<AddonCubit>().clearFailure();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AddonCubit, AddonState>(
      listenWhen: (previous, current) => previous.notice != current.notice,
      listener: (context, state) {
        final notice = state.notice;
        if (notice != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(notice)));
          context.read<AddonCubit>().clearNotice();
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: state.isSaving ? null : () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Add-on Baru'),
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AddonState state) {
    if (state.status == MasterDataStatus.loading && state.addons.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.addons.isEmpty) {
      final isFailure = state.status == MasterDataStatus.failure;
      return _buildScrollable(
        context,
        MasterDataEmptyState(
          icon: isFailure ? Icons.cloud_off_outlined : Icons.extension_outlined,
          title: isFailure ? 'Gagal memuat add-on' : 'Belum ada add-on',
          message:
              state.failure?.message ??
              'Tambahkan topping atau tambahan, misalnya "Extra Keju", '
                  'beserta harga dan stoknya.',
          actionLabel: isFailure ? 'Coba Lagi' : 'Tambah Add-on',
          onAction: isFailure
              ? () => context.read<AddonCubit>().load()
              : () => _openForm(context),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<AddonCubit>().load(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: state.addons.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final addon = state.addons[index];
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(
                  Icons.extension_outlined,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              title: Text(
                addon.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    MasterDataInfoChip(
                      icon: Icons.payments_outlined,
                      label: 'Tambahan ${formatRupiah(addon.price)}',
                    ),
                    MasterDataInfoChip(
                      icon: Icons.inventory_2_outlined,
                      label: 'Stok ${addon.stock}',
                    ),
                  ],
                ),
              ),
              onTap: state.isSaving
                  ? null
                  : () => _openForm(context, addon: addon),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Ubah add-on',
                    visualDensity: VisualDensity.compact,
                    onPressed: state.isSaving
                        ? null
                        : () => _openForm(context, addon: addon),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Hapus add-on',
                    visualDensity: VisualDensity.compact,
                    color: colorScheme.error,
                    onPressed: state.isSaving
                        ? null
                        : () => _deleteAddon(context, addon),
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

  /// Pembungkus empty state agar tetap bisa di-refresh dan berada di tengah.
  Widget _buildScrollable(BuildContext context, Widget child) {
    return RefreshIndicator(
      onRefresh: () => context.read<AddonCubit>().load(),
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
