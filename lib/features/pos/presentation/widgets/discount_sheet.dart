import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/discount_type.dart';
import '../../domain/services/discount_calculator.dart';
import '../cubit/cart_cubit.dart';

/// Bottom sheet untuk mengatur diskon keranjang.
///
/// Sheet ini hanya menangani tampilan & validasi awal:
/// - kasir memilih jenis diskon (nominal Rupiah atau persentase),
/// - pratinjau potongan & total dihitung langsung saat mengetik,
/// - tombol "Terapkan" dinonaktifkan bila input melanggar aturan.
///
/// Perubahan state tetap dilakukan oleh `CartCubit` melalui [onApply] /
/// [onRemove]. Dengan begitu aturan bisnis tidak terduplikasi di UI. Bila
/// Cubit menolak (mis. karena keranjang berubah saat sheet terbuka), pesan
/// dari Cubit ditampilkan di dalam sheet dan sheet tidak ditutup.
class DiscountSheet extends StatefulWidget {
  const DiscountSheet({
    super.key,
    required this.subtotal,
    required this.initialType,
    required this.initialValue,
    required this.onApply,
    required this.onRemove,
  });

  /// Subtotal keranjang saat sheet dibuka.
  final int subtotal;

  /// Jenis diskon yang sedang aktif (default persentase bila belum ada).
  final DiscountType initialType;

  /// Nilai diskon yang sedang aktif; 0 berarti belum ada diskon.
  final int initialValue;

  /// Callback penerapan diskon; hasilnya menentukan sheet ditutup atau tidak.
  final CartMutationResult Function(DiscountType type, int value) onApply;

  /// Callback penghapusan diskon.
  final VoidCallback onRemove;

  @override
  State<DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends State<DiscountSheet> {
  late final TextEditingController _valueController;
  late DiscountType _type;

  /// Pesan kesalahan dari Cubit (bila UI lolos validasi tetapi Cubit menolak).
  String? _submitError;

  @override
  void initState() {
    super.initState();
    // Jenis "none" tidak ditampilkan di segmented button; default ke
    // persentase agar kasir bisa langsung mengetik angka.
    _type = widget.initialType == DiscountType.nominal
        ? DiscountType.nominal
        : DiscountType.percentage;
    _valueController = TextEditingController(
      text: widget.initialValue > 0 ? '${widget.initialValue}' : '',
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  /// Nilai yang sedang diketik (0 bila kosong / bukan angka).
  int get _value => int.tryParse(_valueController.text.trim()) ?? 0;

  /// Pesan validasi langsung dari kalkulator diskon.
  String? get _validationError => DiscountCalculator.validate(
    subtotal: widget.subtotal,
    type: _type,
    value: _value,
  );

  /// Nominal diskon untuk pratinjau (sudah dijepit, jadi aman ditampilkan).
  int get _previewAmount => DiscountCalculator.amount(
    subtotal: widget.subtotal,
    type: _type,
    value: _value,
  );

  /// Total setelah diskon untuk pratinjau.
  int get _previewTotal => DiscountCalculator.total(
    subtotal: widget.subtotal,
    type: _type,
    value: _value,
  );

  /// Menutup sheet setelah Cubit menerima nilai diskon.
  void _apply() {
    final error = _validationError;
    if (error != null || _value <= 0) return;

    final result = widget.onApply(_type, _value);
    if (result.isSuccess) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _submitError = result.message);
  }

  /// Menghapus diskon lalu menutup sheet.
  void _remove() {
    widget.onRemove();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final error = _submitError ?? _validationError;
    final canApply = _value > 0 && _validationError == null;

    return SafeArea(
      top: false,
      child: Padding(
        // Padding bawah mengikuti keyboard agar tombol tidak tertutup saat
        // kasir mengetik nominal.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handel kecil penanda sheet.
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Atur Diskon',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Subtotal ${formatRupiah(widget.subtotal)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  // Pilihan jenis diskon. Hanya dua jenis karena "none"
                  // setara dengan menekan tombol "Hapus Diskon".
                  SegmentedButton<DiscountType>(
                    segments: const [
                      ButtonSegment<DiscountType>(
                        value: DiscountType.nominal,
                        label: Text('Nominal (Rp)'),
                        icon: Icon(Icons.payments_outlined),
                      ),
                      ButtonSegment<DiscountType>(
                        value: DiscountType.percentage,
                        label: Text('Persentase (%)'),
                        icon: Icon(Icons.percent),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _type = selection.first;
                        _submitError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _valueController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: _type == DiscountType.nominal
                          ? 'Nominal diskon'
                          : 'Persentase diskon',
                      prefixIcon: Icon(
                        _type == DiscountType.nominal
                            ? Icons.payments_outlined
                            : Icons.percent,
                      ),
                      suffixText: _type == DiscountType.nominal ? 'Rp' : '%',
                      helperText: _type == DiscountType.percentage
                          ? 'Maksimal 100%'
                          : 'Maksimal sebesar subtotal',
                    ),
                    onChanged: (_) {
                      setState(() => _submitError = null);
                    },
                    onSubmitted: (_) => _apply(),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Pratinjau langsung: kasir melihat dampak diskon sebelum
                  // menekan "Terapkan".
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _PreviewRow(
                          label: 'Potongan diskon',
                          value: '- ${formatRupiah(_previewAmount)}',
                          valueColor: colorScheme.error,
                        ),
                        const SizedBox(height: 6),
                        _PreviewRow(
                          label: 'Total setelah diskon',
                          value: formatRupiah(_previewTotal),
                          valueColor: colorScheme.primary,
                          emphasize: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  if (widget.initialValue > 0 ||
                      widget.initialType != DiscountType.none)
                    TextButton.icon(
                      onPressed: _remove,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Hapus'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: canApply ? _apply : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(150, 48),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Terapkan'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu baris pratinjau pada sheet diskon.
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: emphasize ? FontWeight.bold : null,
            ),
          ),
        ),
        Text(
          value,
          style: (emphasize
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyMedium)
              ?.copyWith(color: valueColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
