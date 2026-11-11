import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/category.dart';
import '../../domain/validators/master_data_validators.dart';
import '../cubit/category_cubit.dart';
import '../cubit/category_state.dart';
import 'master_data_error_banner.dart';

/// Bottom sheet untuk menambah atau mengubah kategori.
///
/// Memakai bottom sheet agar kasir tetap melihat konteks daftar di belakangnya
/// dan form tetap ringan (hanya satu field).
class CategoryFormSheet extends StatefulWidget {
  const CategoryFormSheet({super.key, this.category});

  /// Bila null -> mode tambah; bila diisi -> mode ubah.
  final Category? category;

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
  }

  @override
  void dispose() {
    // Controller wajib dibuang agar tidak terjadi kebocoran memori.
    _nameController.dispose();
    super.dispose();
  }

  /// Validasi form lalu meminta Cubit menyimpan ke SQLite.
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cubit = context.read<CategoryCubit>();
    final category = widget.category;

    final success = category == null
        ? await cubit.createCategory(_nameController.text)
        : await cubit.updateCategory(
            id: category.id,
            name: _nameController.text,
          );

    // Tutup sheet hanya bila penyimpanan berhasil; bila gagal, pesan error
    // tetap tampil di dalam form agar kasir bisa memperbaiki input.
    if (!mounted || !success) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<CategoryCubit, CategoryState>(
      builder: (context, state) {
        return Padding(
          // Padding bawah mengikuti tinggi keyboard supaya tombol simpan
          // tidak tertutup saat kasir mengetik.
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
                    _isEdit ? 'Ubah Kategori' : 'Kategori Baru',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nama kategori dipakai untuk mengelompokkan produk di '
                    'katalog.',
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
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Nama kategori',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    validator: (value) => MasterDataValidators.validateName(
                      value,
                      label: 'Nama kategori',
                    ),
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
                        : Text(
                            _isEdit ? 'Simpan Perubahan' : 'Tambah Kategori',
                          ),
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
