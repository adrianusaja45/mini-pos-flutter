import 'package:flutter/material.dart';

/// Menampilkan dialog konfirmasi sebelum data master dihapus.
///
/// Mengapa perlu konfirmasi?
/// - Penghapusan produk/add-on bersifat soft delete tetapi tetap menyembunyikan
///   data dari katalog, sedangkan kategori tidak bisa dikembalikan lewat UI.
/// - Satu ketukan tidak sengaja saat kasir sibuk tidak boleh langsung
///   mengubah master data.
///
/// Mengembalikan `true` bila kasir memilih tombol hapus.
Future<bool> showDeleteConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
}) async {
  final colorScheme = Theme.of(context).colorScheme;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            // Warna error menegaskan bahwa aksi ini menghapus data.
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              minimumSize: const Size(88, 44),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
