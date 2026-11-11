import 'dart:io';

import 'package:flutter/material.dart';

/// Kartu pemilih foto produk.
///
/// Widget ini hanya menampilkan pratinjau dan meneruskan aksi ketuk ke
/// halaman form. Proses memilih gambar (kamera/galeri) serta penyalinan file
/// dilakukan di layer lain agar widget tetap ringkas.
///
/// [imagePath] bisa berupa path sementara hasil image_picker (untuk pratinjau
/// sebelum disimpan) atau path permanen dari SQLite setelah produk tersimpan.
class ProductPhotoPicker extends StatelessWidget {
  const ProductPhotoPicker({
    super.key,
    required this.imagePath,
    required this.onTap,
    this.enabled = true,
  });

  final String? imagePath;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 180,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: imagePath == null
            ? _buildPlaceholder(context, colorScheme)
            : Stack(
                fit: StackFit.expand,
                children: [
                  // Image.file membaca path dari penyimpanan lokal. Bila file
                  // hilang (mis. dipindah manual), tampil placeholder agar
                  // halaman tidak error.
                  Image.file(
                    File(imagePath!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholder(
                          context,
                          colorScheme,
                          message: 'Foto tidak dapat dibuka',
                        ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Ganti foto',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Tampilan saat belum ada foto atau file tidak bisa dibuka.
  Widget _buildPlaceholder(
    BuildContext context,
    ColorScheme colorScheme, {
    String? message,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 44,
          color: colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          message ?? 'Ketuk untuk menambah foto',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          'Kamera atau galeri',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
