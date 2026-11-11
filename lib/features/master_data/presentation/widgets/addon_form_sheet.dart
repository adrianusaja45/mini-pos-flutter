import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/addon.dart';
import '../../domain/validators/master_data_validators.dart';
import '../cubit/addon_cubit.dart';
import '../cubit/addon_state.dart';
import 'master_data_error_banner.dart';

/// Bottom sheet untuk menambah atau mengubah add-on (topping/tambahan).
///
/// Add-on memiliki stok sendiri yang terpisah dari stok produk, karena satu
/// add-on bisa dipakai oleh banyak produk sekaligus.
class AddonFormSheet extends StatefulWidget {
  const AddonFormSheet({super.key, this.addon});

  /// Bila null -> mode tambah; bila diisi -> mode ubah.
  final Addon? addon;

  @override
  State<AddonFormSheet> createState() => _AddonFormSheetState();
}

class _AddonFormSheetState extends State<AddonFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;

  bool get _isEdit => widget.addon != null;

  @override
  void initState() {
    super.initState();
    final addon = widget.addon;
    _nameController = TextEditingController(text: addon?.name ?? '');
    _priceController = TextEditingController(
      text: addon == null ? '' : addon.price.toString(),
    );
    _stockController = TextEditingController(
      text: addon == null ? '' : addon.stock.toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  /// Validasi form lalu meminta Cubit menyimpan add-on ke SQLite.
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Nilai sudah dipastikan angka oleh validator, sehingga `?? 0` hanya
    // jaring pengaman agar kode tetap bebas null.
    final price = MasterDataValidators.parsePrice(_priceController.text) ?? 0;
    final stock = MasterDataValidators.parseStock(_stockController.text) ?? 0;

    final cubit = context.read<AddonCubit>();
    final addon = widget.addon;

    final success = addon == null
        ? await cubit.createAddon(
            name: _nameController.text,
            price: price,
            stock: stock,
          )
        : await cubit.updateAddon(
            id: addon.id,
            name: _nameController.text,
            price: price,
            stock: stock,
          );

    if (!mounted || !success) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<AddonCubit, AddonState>(
      builder: (context, state) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isEdit ? 'Ubah Add-on' : 'Add-on Baru',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add-on dapat dipilih kasir sebagai tambahan pada produk. '
                    'Stoknya dihitung terpisah.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    enabled: !state.isSaving,
                    autofocus: !_isEdit,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nama add-on',
                      prefixIcon: Icon(Icons.extension_outlined),
                      hintText: 'Contoh: Extra Keju',
                    ),
                    validator: (value) => MasterDataValidators.validateName(
                      value,
                      label: 'Nama add-on',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    enabled: !state.isSaving,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Harga tambahan (Rp)',
                      prefixIcon: Icon(Icons.payments_outlined),
                      helperText: 'Angka saja, tanpa titik. Isi 0 bila gratis.',
                    ),
                    validator: MasterDataValidators.validatePrice,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _stockController,
                    enabled: !state.isSaving,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Jumlah stok',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    validator: MasterDataValidators.validateStock,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (state.failure != null) ...[
                    const SizedBox(height: 16),
                    MasterDataErrorBanner(message: state.failure!.message),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: state.isSaving ? null : _submit,
                    child: state.isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(_isEdit ? 'Simpan Perubahan' : 'Tambah Add-on'),
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
