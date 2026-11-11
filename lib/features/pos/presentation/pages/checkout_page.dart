import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/repositories/pos_repository.dart';
import '../cubit/cart_state.dart';
import '../cubit/checkout_cubit.dart';
import '../cubit/checkout_state.dart';
import 'receipt_page.dart';

/// Halaman pembayaran tunai.
///
/// Alur:
/// 1. Menampilkan ringkasan belanja (subtotal, diskon, total akhir).
/// 2. Kasir mengetik uang tunai yang diterima.
/// 3. Kembalian dihitung real-time di layar; tombol konfirmasi tetap mati
///    selama uang tunai kurang dari total tagihan.
/// 4. Setelah transaksi atomik berhasil, halaman ini diganti halaman struk
///    digital sehingga kasir tidak bisa kembali ke form pembayaran.
///
/// Halaman menerima snapshot [CartState] (bukan membaca Cubit keranjang) agar
/// angka yang dibayar sama persis dengan yang dilihat kasir saat menekan
/// "Bayar". Repository tetap menghitung ulang nominal sebagai pengaman.
class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key, required this.cart, required this.onFinish});

  /// Snapshot keranjang saat tombol "Bayar" ditekan.
  final CartState cart;

  /// Callback setelah transaksi selesai: mengosongkan keranjang dan memuat
  /// ulang stok katalog. Disediakan halaman POS agar halaman ini tidak perlu
  /// mengetahui Cubit lain.
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    // Repository tersedia dari RepositoryProvider di akar aplikasi (di atas
    // MaterialApp), sehingga tetap bisa dibaca dari route baru ini.
    return BlocProvider(
      create: (context) => CheckoutCubit(context.read<PosRepository>()),
      child: _CheckoutView(cart: cart, onFinish: onFinish),
    );
  }
}

class _CheckoutView extends StatefulWidget {
  const _CheckoutView({required this.cart, required this.onFinish});

  final CartState cart;
  final VoidCallback onFinish;

  @override
  State<_CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<_CheckoutView> {
  final _cashController = TextEditingController();

  /// Uang tunai yang sedang diinput (0 bila kolom kosong / belum valid).
  int get _cashReceived => int.tryParse(_cashController.text.trim()) ?? 0;

  /// Sisa yang masih harus dibayar; negatif berarti uang sudah cukup.
  int get _difference => _cashReceived - widget.cart.totalAmount;

  bool get _isCashEnough => _cashReceived >= widget.cart.totalAmount;

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  /// Mengisi kolom uang tunai dengan nominal cepat (mis. "Uang pas").
  void _setCash(int value) {
    final text = value <= 0 ? '' : '$value';
    _cashController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
  }

  /// Nominal cepat yang ditawarkan ke kasir.
  ///
  /// Selalu menyertakan "uang pas" (total tagihan), lalu pembulatan ke atas
  /// kelipatan 5.000 / 10.000 / 50.000 / 100.000 yang paling dekat. Semua
  /// nilai dijamin `>= total` sehingga tidak ada tombol yang menghasilkan
  /// uang kurang.
  List<int> get _cashSuggestions {
    final total = widget.cart.totalAmount;
    final values = <int>{total};

    for (final step in [5000, 10000, 50000, 100000]) {
      final rounded = ((total + step - 1) ~/ step) * step;
      if (rounded > total) values.add(rounded);
    }

    final sorted = values.toList()..sort();
    return sorted.take(4).toList(growable: false);
  }

  /// Mengirim pembayaran ke Cubit.
  ///
  /// Validasi uang dilakukan dua kali: di sini (agar tombol tidak bisa ditekan)
  /// dan di `CheckoutCubit` (agar aturan tetap berlaku dari jalur mana pun).
  void _submit() {
    if (!_isCashEnough) return;
    FocusScope.of(context).unfocus();
    context.read<CheckoutCubit>().confirmPayment(
      cart: widget.cart,
      cashReceived: _cashReceived,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CheckoutCubit, CheckoutState>(
      // Hanya bereaksi saat status berubah, bukan setiap kali state lain
      // berubah, supaya navigasi tidak terpicu dua kali.
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.isSuccess && state.receipt != null) {
          // Keranjang langsung dikosongkan & stok katalog dimuat ulang agar
          // transaksi yang sama tidak mungkin dibayar dua kali.
          widget.onFinish();

          // Ganti halaman pembayaran dengan struk; tombol back tidak kembali
          // ke form pembayaran.
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ReceiptPage(
                receipt: state.receipt!,
                onFinish: widget.onFinish,
              ),
            ),
          );
          return;
        }

        if (state.isFailure && state.errorMessage != null) {
          final colorScheme = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: colorScheme.error,
                duration: const Duration(seconds: 5),
              ),
            );
        }
      },
      builder: (context, state) {
        return PopScope(
          // Saat penyimpanan berjalan, halaman tidak boleh ditutup agar kasir
          // tidak mengira transaksi batal padahal database sedang menulis.
          canPop: !state.isProcessing,
          child: Scaffold(
            appBar: AppBar(title: const Text('Pembayaran')),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSummaryCard(context),
                        const SizedBox(height: 16),
                        _buildCashCard(context),
                      ],
                    ),
                  ),
                  _buildBottomBar(context, state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Ringkasan belanja
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cart = widget.cart;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Ringkasan Belanja',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${cart.lineCount} baris • ${cart.totalQuantity} unit produk',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 20),
            _SummaryRow(label: 'Subtotal', value: formatRupiah(cart.subtotal)),
            if (cart.hasDiscount) ...[
              const SizedBox(height: 6),
              _SummaryRow(
                label: 'Diskon (${cart.discountLabel})',
                value: '- ${formatRupiah(cart.discountAmount)}',
                valueColor: colorScheme.error,
              ),
            ],
            const Divider(height: 20),
            _SummaryRow(
              label: 'Total Tagihan',
              value: formatRupiah(cart.totalAmount),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Input uang tunai
  // ---------------------------------------------------------------------------

  Widget _buildCashCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.payments_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Uang Tunai Diterima',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('cash-input'),
              controller: _cashController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                hintText: '0',
                helperText: 'Masukkan nominal uang yang diterima dari pembeli.',
              ),
              // setState memicu perhitungan kembalian secara real-time.
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in _cashSuggestions)
                  ActionChip(
                    label: Text(
                      value == widget.cart.totalAmount
                          ? 'Uang pas'
                          : formatRupiah(value),
                    ),
                    onPressed: () => _setCash(value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildChangeBox(context),
          ],
        ),
      ),
    );
  }

  /// Kotak kembalian real-time.
  ///
  /// Tiga kondisi yang mungkin:
  /// - uang belum diisi -> petunjuk,
  /// - uang kurang -> berapa kekurangannya,
  /// - uang cukup -> nominal kembalian.
  Widget _buildChangeBox(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_cashReceived <= 0) {
      return _InfoBox(
        icon: Icons.info_outline,
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurfaceVariant,
        title: 'Kembalian',
        message: 'Isi nominal uang tunai untuk melihat kembalian.',
      );
    }

    if (_difference < 0) {
      return _InfoBox(
        icon: Icons.error_outline,
        backgroundColor: colorScheme.errorContainer,
        foregroundColor: colorScheme.onErrorContainer,
        title: 'Uang kurang ${formatRupiah(-_difference)}',
        message: 'Uang tunai belum mencukupi total tagihan.',
      );
    }

    return _InfoBox(
      icon: Icons.check_circle_outline,
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      title: 'Kembalian ${formatRupiah(_difference)}',
      message: 'Uang tunai sudah mencukupi. Periksa kembali sebelum '
          'mengonfirmasi pembayaran.',
    );
  }

  // ---------------------------------------------------------------------------
  // Tombol konfirmasi
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar(BuildContext context, CheckoutState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      elevation: 8,
      color: colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total tagihan',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatRupiah(widget.cart.totalAmount),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                // Tombol mati bila uang kurang atau transaksi sedang disimpan.
                onPressed: state.isProcessing || !_isCashEnough
                    ? null
                    : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(190, 52),
                ),
                icon: state.isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  state.isProcessing ? 'Menyimpan...' : 'Konfirmasi Bayar',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris label-nilai pada kartu ringkasan.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: (emphasize
                    ? theme.textTheme.titleSmall
                    : theme.textTheme.bodyMedium)
                ?.copyWith(fontWeight: emphasize ? FontWeight.bold : null),
          ),
        ),
        Text(
          value,
          style: (emphasize
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.bodyMedium)
              ?.copyWith(
                color: valueColor ?? theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

/// Kotak informasi (kembalian / kekurangan uang).
class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foregroundColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foregroundColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
