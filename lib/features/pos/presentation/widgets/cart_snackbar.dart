import 'package:flutter/material.dart';

import '../cubit/cart_cubit.dart';

/// Menampilkan pesan kegagalan operasi keranjang (mis. stok tidak cukup).
///
/// Dipusatkan dalam satu helper agar semua tombol yang memicu perubahan
/// keranjang (kartu produk, tombol "+", bottom sheet) memberi umpan balik
/// dengan gaya yang sama. Snackbar lama disembunyikan lebih dulu supaya pesan
/// baru tidak mengantre di belakang pesan yang sudah tidak relevan.
void showCartResultMessage(BuildContext context, CartMutationResult result) {
  final message = result.message;
  if (message == null) return;

  final colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colorScheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
}
