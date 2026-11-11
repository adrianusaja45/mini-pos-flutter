import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/database/database_helper.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/datasources/auth_local_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/cubit/session_cubit.dart';
import 'features/auth/presentation/pages/auth_gate.dart';
import 'features/master_data/data/datasources/addon_local_data_source.dart';
import 'features/master_data/data/datasources/category_local_data_source.dart';
import 'features/master_data/data/datasources/product_image_storage.dart';
import 'features/master_data/data/datasources/product_local_data_source.dart';
import 'features/master_data/data/repositories/master_data_repository_impl.dart';
import 'features/master_data/domain/repositories/master_data_repository.dart';
import 'features/pos/data/repositories/pos_repository_impl.dart';
import 'features/pos/domain/repositories/pos_repository.dart';

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

  // Repository master data memakai koneksi SQLite yang sama. ProductImageStorage
  // bertugas menyalin foto ke Application Documents Directory.
  final masterDataRepository = MasterDataRepositoryImpl(
    categoryDataSource: CategoryLocalDataSource(),
    productDataSource: ProductLocalDataSource(),
    addonDataSource: AddonLocalDataSource(),
    imageStorage: ProductImageStorage(),
  );

  // Repository POS membungkus repository master data. Dengan begitu katalog
  // kasir membaca produk & add-on aktif yang sama tanpa query SQL duplikat.
  final posRepository = PosRepositoryImpl(masterDataRepository);

  runApp(
    PosApp(
      authRepository: authRepository,
      masterDataRepository: masterDataRepository,
      posRepository: posRepository,
    ),
  );
}

/// Widget akar aplikasi.
class PosApp extends StatelessWidget {
  const PosApp({
    super.key,
    required this.authRepository,
    required this.masterDataRepository,
    required this.posRepository,
  });

  /// Repository autentikasi yang dipakai seluruh halaman auth.
  final AuthRepository authRepository;

  /// Repository master data (kategori, produk, add-on) untuk fitur master data.
  final MasterDataRepository masterDataRepository;

  /// Repository katalog untuk layar kasir (POS).
  final PosRepository posRepository;

  @override
  Widget build(BuildContext context) {
    // RepositoryProvider membuat repository dapat diambil dari widget mana pun
    // dengan `context.read<...>()`.
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<MasterDataRepository>.value(
          value: masterDataRepository,
        ),
        RepositoryProvider<PosRepository>.value(value: posRepository),
      ],
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
