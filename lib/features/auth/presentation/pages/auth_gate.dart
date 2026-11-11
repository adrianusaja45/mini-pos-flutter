import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/session_cubit.dart';
import '../cubit/session_state.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'splash_page.dart';

/// Penentu halaman utama berdasarkan status sesi kasir.
///
/// Mengapa memakai "gate" di akar aplikasi, bukan `Navigator.push` manual?
/// - Dengan satu sumber kebenaran ([SessionCubit]), perpindahan Login <-> Home
///   otomatis konsisten. Tidak ada risiko halaman Login masih menumpuk di
///   belakang Home setelah login, atau sebaliknya setelah logout.
/// - Splash hanya tampil selama state masih `checking`.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, state) {
        // Pilih halaman sesuai status sesi.
        final child = switch (state.status) {
          SessionStatus.checking => const SplashPage(key: ValueKey('splash')),
          SessionStatus.authenticated => HomePage(
            key: const ValueKey('home'),
            session: state.session!,
          ),
          SessionStatus.unauthenticated => const LoginPage(
            key: ValueKey('login'),
          ),
        };

        // Animasi halus agar perpindahan login -> home tidak terasa "kaku".
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: child,
        );
      },
    );
  }
}
