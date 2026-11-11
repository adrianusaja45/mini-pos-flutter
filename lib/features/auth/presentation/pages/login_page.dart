import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../domain/validators/auth_validators.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';
import '../cubit/session_cubit.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_form_field.dart';
import 'register_page.dart';

/// Halaman Login kasir (offline).
///
/// Halaman ini membuat [LoginCubit] sendiri dari [AuthRepository] yang
/// disediakan di `main.dart`, sehingga widget hanya fokus pada tampilan form.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.initialUsername});

  /// Username yang otomatis terisi setelah kasir selesai mendaftar akun.
  final String? initialUsername;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginCubit(context.read<AuthRepository>()),
      child: _LoginView(initialUsername: initialUsername),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView({this.initialUsername});

  final String? initialUsername;

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Prefill username bila kasir baru kembali dari halaman Register.
    final initialUsername = widget.initialUsername;
    if (initialUsername != null && initialUsername.isNotEmpty) {
      _usernameController.text = initialUsername;
    }
  }

  @override
  void dispose() {
    // Controller wajib dibuang agar tidak terjadi kebocoran memori.
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Menjalankan validasi form lalu meminta Cubit melakukan login.
  Future<void> _submit() async {
    // Tutup keyboard agar layar tidak tertutup saat pesan error muncul.
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await context.read<LoginCubit>().login(
      username: _usernameController.text,
      password: _passwordController.text,
    );
  }

  /// Membuka halaman Register dan mengisi username bila pendaftaran sukses.
  Future<void> _openRegister() async {
    final username = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const RegisterPage()));

    // `mounted` wajib dicek karena halaman ini bisa saja sudah ditutup saat
    // proses pendaftaran selesai.
    if (!mounted || username == null) return;

    _usernameController.text = username;
    _passwordController.clear();
    context.read<LoginCubit>().clearError();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Akun berhasil dibuat. Silakan login.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<LoginCubit, LoginState>(
      // Listener hanya menangani efek samping. Saat login sukses, sesi
      // diteruskan ke SessionCubit supaya AuthGate berpindah ke Home.
      listener: (context, state) {
        final session = state.session;
        if (state.isSuccess && session != null) {
          context.read<SessionCubit>().onLoginSuccess(session);
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(theme),
                            const SizedBox(height: 24),
                            AuthFormField(
                              controller: _usernameController,
                              label: 'Username',
                              icon: Icons.person_outline,
                              enabled: !state.isSubmitting,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              validator: AuthValidators.validateUsername,
                            ),
                            const SizedBox(height: 16),
                            AuthFormField(
                              controller: _passwordController,
                              label: 'PIN / Password',
                              icon: Icons.lock_outline,
                              enabled: !state.isSubmitting,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              validator: AuthValidators.validatePassword,
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
                                  : const Text('Masuk'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: state.isSubmitting
                                  ? null
                                  : _openRegister,
                              child: const Text('Belum punya akun? Daftar'),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Aplikasi berjalan 100% offline. Data kasir '
                              'disimpan di perangkat ini.',
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

  /// Bagian judul halaman beserta ikon identitas aplikasi.
  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.point_of_sale_rounded,
            size: 36,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Login Kasir',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Masuk untuk mulai melayani transaksi.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
