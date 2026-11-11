import 'package:flutter/material.dart';

/// Tampilan saat daftar master data masih kosong.
///
/// Dibuat terpisah agar kategori, produk, dan add-on memiliki pengalaman
/// kosong yang konsisten: ikon, penjelasan singkat, dan tombol aksi supaya
/// kasir langsung tahu langkah berikutnya.
class MasterDataEmptyState extends StatelessWidget {
  const MasterDataEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;

  /// Label tombol aksi (mis. "Tambah Kategori"). Bila null, tombol disembunyikan.
  final String? actionLabel;

  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(icon, size: 36, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(minimumSize: const Size(220, 48)),
            ),
          ],
        ],
      ),
    );
  }
}
