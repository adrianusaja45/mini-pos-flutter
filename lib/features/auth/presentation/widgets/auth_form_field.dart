import 'package:flutter/material.dart';

/// Kolom input standar untuk form Login dan Register.
///
/// Dibuat sebagai widget terpisah agar kedua halaman tampil konsisten dan
/// pengelolaan tampilan PIN (ikon mata untuk menyembunyikan/menampilkan teks)
/// tidak ditulis dua kali.
class AuthFormField extends StatefulWidget {
  const AuthFormField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autofillHints,
    this.onFieldSubmitted,
    this.enabled = true,
    this.helperText,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  /// Validator dari [AuthValidators]; mengembalikan pesan error atau null.
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Bila true, teks disamarkan dan muncul tombol mata.
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final VoidCallback? onFieldSubmitted;
  final bool enabled;
  final String? helperText;
  final TextCapitalization textCapitalization;

  @override
  State<AuthFormField> createState() => _AuthFormFieldState();
}

class _AuthFormFieldState extends State<AuthFormField> {
  // Status sembunyi/terlihat untuk kolom PIN. Nilai awal mengikuti properti
  // obscureText sehingga kolom non-PIN tetap tampil normal.
  late bool _isObscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _isObscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onFieldSubmitted: (_) => widget.onFieldSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        prefixIcon: Icon(widget.icon),
        suffixIcon: widget.obscureText
            ? IconButton(
                // Tombol ini membantu kasir memastikan PIN yang diketik benar
                // sebelum menekan tombol masuk.
                tooltip: _isObscured ? 'Tampilkan PIN' : 'Sembunyikan PIN',
                icon: Icon(
                  _isObscured ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _isObscured = !_isObscured),
              )
            : null,
      ),
    );
  }
}
