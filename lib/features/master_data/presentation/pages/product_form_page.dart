import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/validators/master_data_validators.dart';
import '../cubit/product_cubit.dart';
import '../cubit/product_state.dart';
import '../widgets/master_data_error_banner.dart';
import '../widgets/product_photo_picker.dart';

/// Halaman form tambah/ubah produk.
///
/// Memakai halaman penuh (bukan bottom sheet) karena form produk memuat foto,
/// kategori, harga, dan stok sekaligus. Dengan begitu seluruh field nyaman
/// diisi di layar kecil maupun desktop.
class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, required this.categories, this.product});

  /// Daftar kategori yang sudah dimuat halaman induk. Dikirim lewat
  /// konstruktor agar form tidak perlu query ulang ke database.
  final List<Category> categories;

  /// Bila null -> mode tambah; bila diisi -> mode ubah.
  final Product? product;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;

  /// Kategori yang sedang dipilih pada dropdown.
  int? _selectedCategoryId;

  /// Path foto permanen yang sudah tersimpan (saat edit).
  String? _existingImagePath;

  /// Path sementara hasil image_picker yang belum disalin ke folder permanen.
  ///
  /// Path ini hanya dipakai untuk pratinjau. Penyalinan ke Application
  /// Documents Directory dilakukan repository saat tombol simpan ditekan,
  /// sehingga tidak ada file yatim bila kasir membatalkan form.
  String? _pickedImagePath;

  /// Penanda kasir ingin menghapus foto tanpa menggantinya.
  bool _removePhoto = false;

  bool get _isEdit => widget.product != null;

  /// Path yang ditampilkan di kartu foto.
  String? get _currentPhotoPath {
    if (_pickedImagePath != null) return _pickedImagePath;
    if (_removePhoto) return null;
    return _existingImagePath;
  }

  @override
  void initState() {
    super.initState();
    final product = widget.product;

    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(
      text: product == null ? '' : product.price.toString(),
    );
    _stockController = TextEditingController(
      text: product == null ? '' : product.stock.toString(),
    );
    _existingImagePath = product?.imagePath;

    // Pilih kategori awal: kategori produk saat edit, atau kategori pertama
    // saat menambah. Bila kategori lama sudah tidak ada, jatuh ke kategori
    // pertama agar dropdown tetap valid.
    if (product != null &&
        widget.categories.any(
          (category) => category.id == product.categoryId,
        )) {
      _selectedCategoryId = product.categoryId;
    } else if (widget.categories.isNotEmpty) {
      _selectedCategoryId = widget.categories.first.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  /// Menampilkan pilihan sumber foto: kamera, galeri, atau hapus foto.
  Future<void> _showPhotoSourceSheet() async {
    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Ambil dari Kamera'),
                subtitle: const Text('Foto langsung dari perangkat'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari Galeri'),
                subtitle: const Text('Gunakan foto yang sudah ada'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              if (_currentPhotoPath != null)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: colorScheme.error),
                  title: Text(
                    'Hapus Foto',
                    style: TextStyle(color: colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    setState(() {
                      _pickedImagePath = null;
                      _removePhoto = true;
                    });
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Mengambil gambar dari kamera/galeri.
  ///
  /// Hasil image_picker masih berupa file **sementara** di cache. File baru
  /// disalin ke folder permanen oleh repository saat form disimpan.
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        // Batasi ukuran agar penyimpanan tidak cepat penuh. Kualitas 85 masih
        // nyaman dilihat untuk thumbnail produk.
        maxWidth: 1600,
        imageQuality: 85,
      );

      if (pickedFile == null || !mounted) return;

      setState(() {
        _pickedImagePath = pickedFile.path;
        _removePhoto = false;
      });
    } catch (_) {
      if (!mounted) return;
      final isCamera = source == ImageSource.camera;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCamera
                ? 'Kamera tidak tersedia di perangkat ini. Silakan pilih dari '
                      'galeri.'
                : 'Gagal membuka galeri. Silakan coba lagi.',
          ),
        ),
      );
    }
  }

  /// Validasi form lalu meminta Cubit menyimpan produk.
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final categoryId = _selectedCategoryId;
    if (categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori produk terlebih dahulu.')),
      );
      return;
    }

    final price = MasterDataValidators.parsePrice(_priceController.text) ?? 0;
    final stock = MasterDataValidators.parseStock(_stockController.text) ?? 0;

    final cubit = context.read<ProductCubit>();
    final product = widget.product;

    final success = product == null
        ? await cubit.createProduct(
            categoryId: categoryId,
            name: _nameController.text,
            price: price,
            stock: stock,
            photoSourcePath: _pickedImagePath,
          )
        : await cubit.updateProduct(
            id: product.id,
            categoryId: categoryId,
            name: _nameController.text,
            price: price,
            stock: stock,
            photoSourcePath: _pickedImagePath,
            removePhoto: _removePhoto,
          );

    // Bila gagal, halaman tetap terbuka dan pesan error tampil di banner.
    if (!mounted || !success) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<ProductCubit, ProductState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text(_isEdit ? 'Ubah Produk' : 'Produk Baru')),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ProductPhotoPicker(
                    imagePath: _currentPhotoPath,
                    enabled: !state.isSaving,
                    onTap: _showPhotoSourceSheet,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Foto akan disalin ke penyimpanan aplikasi sehingga tetap '
                    'tampil setelah aplikasi ditutup.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    enabled: !state.isSaving,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nama produk',
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                      hintText: 'Contoh: Nasi Goreng Spesial',
                    ),
                    validator: (value) => MasterDataValidators.validateName(
                      value,
                      label: 'Nama produk',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: widget.categories
                        .map(
                          (category) => DropdownMenuItem<int>(
                            value: category.id,
                            child: Text(
                              category.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: state.isSaving
                        ? null
                        : (value) =>
                              setState(() => _selectedCategoryId = value),
                    validator: (value) =>
                        value == null ? 'Kategori wajib dipilih.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    enabled: !state.isSaving,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Harga jual (Rp)',
                      prefixIcon: Icon(Icons.payments_outlined),
                      helperText: 'Angka saja, tanpa titik. Contoh: 25000.',
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
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: state.isSaving ? null : _submit,
                    icon: state.isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      state.isSaving
                          ? 'Menyimpan...'
                          : (_isEdit ? 'Simpan Perubahan' : 'Simpan Produk'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Menghapus produk hanya menyembunyikannya dari katalog. '
                    'Riwayat transaksi tetap tersimpan.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
