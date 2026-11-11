import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/database/database_helper.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/datasources/auth_local_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/cubit/session_cubit.dart';
import 'features/auth/presentation/pages/auth_gate.dart';

/// Titik masuk aplikasi.
///
/// Database dibuka lebih dulu sebelum UI ditampilkan. Dengan begitu, saat
/// Splash Screen memeriksa sesi login, tabel `users` dan `user_sessions` sudah
/// siap dipakai sehingga tidak ada layar kosong sambil menunggu SQLite.
Future<void> main() async {
  // Wajib dipanggil karena kita memakai plugin (sqflite) sebelum runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Membuka database sekali di awal; skema akan dibuat/dimigrasi otomatis.
  await DatabaseHelper.instance.database;

  // Komposisi dependency secara manual (tanpa package tambahan):
  // data source -> repository -> Cubit. Repository yang sama dibagikan ke
  // Login dan Register melalui RepositoryProvider di bawah.
  final authRepository = AuthRepositoryImpl(
    localDataSource: AuthLocalDataSource(),
  );

  runApp(PosApp(authRepository: authRepository));
}

/// Widget akar aplikasi.
class PosApp extends StatelessWidget {
  const PosApp({super.key, required this.authRepository});

  /// Repository autentikasi yang dipakai seluruh halaman auth.
  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    // RepositoryProvider membuat repository dapat diambil dari widget mana pun
    // dengan `context.read<AuthRepository>()`.
    return RepositoryProvider<AuthRepository>.value(
      value: authRepository,
      child: BlocProvider(
        // SessionCubit langsung memeriksa sesi tersimpan saat aplikasi start.
        // Selama proses ini berjalan, AuthGate menampilkan Splash Screen.
        create: (context) => SessionCubit(authRepository)..checkSession(),
        child: MaterialApp(
          title: 'Mini POS Offline',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const AuthGate(),
        ),
      ),
    );
  }
}
