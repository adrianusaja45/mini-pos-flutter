import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../domain/validators/auth_validators.dart';
import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_form_field.dart';

/// Halaman pendaftaran akun kasir baru.
///
/// Setelah akun tersimpan di tabel `users`, halaman ini ditutup dan
/// mengembalikan username ke halaman Login lewat `Navigator.pop(username)`.
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    // RegisterCubit dibuat khusus untuk halaman ini agar state form tidak
    // bercampur dengan form Login.
    return BlocProvider(
      create: (context) => RegisterCubit(context.read<AuthRepository>()),
      child: const _RegisterView(),
    );
  }
}

class _RegisterView extends StatefulWidget {
  const _RegisterView();

  @override
  State<_RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<_RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Validasi form lalu meminta Cubit menyimpan akun ke SQLite.
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await context.read<RegisterCubit>().register(
      name: _nameController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegisterCubit, RegisterState>(
      // Begitu akun tersimpan, kembalikan username ke Login agar kolom
      // username otomatis terisi dan kasir tinggal memasukkan PIN.
      listener: (context, state) {
        if (state.isSuccess) {
          Navigator.of(context).pop(state.registeredUser?.username);
        }
      },
      builder: (context, state) {
        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(title: const Text('Daftar Akun Kasir')),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Buat akun kasir baru',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Akun disimpan di perangkat ini dan dipakai '
                              'untuk login saat aplikasi dibuka.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 20),
                            AuthFormField(
                              controller: _nameController,
                              label: 'Nama Lengkap',
                              icon: Icons.badge_outlined,
                              enabled: !state.isSubmitting,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              validator: AuthValidators.validateName,
                            ),
                            const SizedBox(height: 16),
                            AuthFormField(
                              controller: _usernameController,
                              label: 'Username',
                              icon: Icons.person_outline,
                              enabled: !state.isSubmitting,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newUsername],
                              helperText:
                                  'Minimal 3 karakter: huruf, angka, titik, '
                                  'atau garis bawah.',
                              validator: AuthValidators.validateUsername,
                            ),
                            const SizedBox(height: 16),
                            AuthFormField(
                              controller: _passwordController,
                              label: 'PIN / Password',
                              icon: Icons.lock_outline,
                              enabled: !state.isSubmitting,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              helperText: 'Minimal 4 karakter.',
                              validator: AuthValidators.validatePassword,
                            ),
                            const SizedBox(height: 16),
                            AuthFormField(
                              controller: _confirmPasswordController,
                              label: 'Ulangi PIN / Password',
                              icon: Icons.lock_reset_outlined,
                              enabled: !state.isSubmitting,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              validator: (value) =>
                                  AuthValidators.validatePasswordConfirmation(
                                    value,
                                    password: _passwordController.text,
                                  ),
                              onFieldSubmitted: _submit,
                            ),
                            if (state.isFailure &&
                                state.errorMessage != null) ...[
                              const SizedBox(height: 16),
                              AuthErrorBanner(message: state.errorMessage!),
                            ],
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: state.isSubmitting ? null : _submit,
                              child: state.isSubmitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text('Daftar'),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Setelah mendaftar, kasir akan diarahkan kembali '
                              'ke halaman login.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
