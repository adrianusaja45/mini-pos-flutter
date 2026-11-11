import 'package:flutter/material.dart';

/// Kotak pesan error pada form master data.
///
/// Dipakai di dalam bottom sheet maupun halaman form produk agar pesan
/// kegagalan (nama duplikat, validasi, dsb.) selalu tampil dengan gaya yang
/// sama dan mudah dibaca kasir.
class MasterDataErrorBanner extends StatelessWidget {
  const MasterDataErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
