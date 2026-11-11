import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pos_offline/core/database/database_helper.dart';
import 'package:mini_pos_offline/core/database/db_constants.dart';
import 'package:mini_pos_offline/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:mini_pos_offline/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mini_pos_offline/features/auth/domain/failures/auth_failure.dart';
import 'package:mini_pos_offline/features/auth/domain/repositories/auth_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pengujian alur autentikasi pada Tahap 2.
///
/// Memakai SQLite in-memory (bukan file asli) agar setiap test mulai dari
/// database kosong dan tidak mengganggu data aplikasi di perangkat.
void main() {
  late AuthRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.debugDatabasePath = inMemoryDatabasePath;
    repository = AuthRepositoryImpl(localDataSource: AuthLocalDataSource());
    // Pastikan tabel sudah dibuat sebelum setiap skenario berjalan.
    await DatabaseHelper.instance.database;
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.debugDatabasePath = null;
  });

  test('register menyimpan PIN sebagai hash, bukan teks asli', () async {
    final user = await repository.register(
      name: 'Budi Santoso',
      username: 'Budi',
      password: '1234',
    );

    // Username dinormalisasi ke huruf kecil.
    expect(user.username, 'budi');
    expect(user.name, 'Budi Santoso');

    final db = await DatabaseHelper.instance.database;
    final row = (await db.query(DbTables.users)).single;
    final storedHash = row[DbColumns.passwordHash] as String;

    expect(storedHash, isNot('1234'));
    expect(storedHash, contains(':'));
  });

  test(
    'username duplikat ditolak tanpa membedakan huruf besar/kecil',
    () async {
      await repository.register(
        name: 'Budi Santoso',
        username: 'budi',
        password: '1234',
      );

      await expectLater(
        repository.register(
          name: 'Budi Lain',
          username: 'BUDI',
          password: '5678',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.message,
            'message',
            contains('sudah dipakai'),
          ),
        ),
      );
    },
  );

  test('login berhasil menyimpan sesi dengan id dan nama kasir', () async {
    final registered = await repository.register(
      name: 'Siti Aminah',
      username: 'siti',
      password: '1234',
    );

    final session = await repository.login(username: 'siti', password: '1234');

    expect(session.user.id, registered.id);
    expect(session.cashierName, 'Siti Aminah');

    // Sesi harus tetap ada saat dibaca ulang (simulasi aplikasi dibuka lagi).
    final persisted = await repository.getActiveSession();
    expect(persisted, isNotNull);
    expect(persisted!.user.id, registered.id);
    expect(persisted.user.name, 'Siti Aminah');
  });

  test('login dengan PIN salah ditolak dan tidak membuat sesi', () async {
    await repository.register(
      name: 'Siti Aminah',
      username: 'siti',
      password: '1234',
    );

    await expectLater(
      repository.login(username: 'siti', password: '9999'),
      throwsA(isA<AuthFailure>()),
    );

    expect(await repository.getActiveSession(), isNull);
  });

  test('logout menghapus sesi sehingga kasir harus login lagi', () async {
    await repository.register(
      name: 'Siti Aminah',
      username: 'siti',
      password: '1234',
    );
    await repository.login(username: 'siti', password: '1234');

    await repository.logout();

    expect(await repository.getActiveSession(), isNull);
  });

  test('validasi menolak nama kosong dan PIN terlalu pendek', () async {
    await expectLater(
      repository.register(name: '', username: 'kasir', password: '1234'),
      throwsA(isA<AuthFailure>()),
    );

    await expectLater(
      repository.register(
        name: 'Kasir Satu',
        username: 'kasir',
        password: '12',
      ),
      throwsA(isA<AuthFailure>()),
    );
  });

  test('isUsernameAvailable menghormati normalisasi username', () async {
    await repository.register(
      name: 'Siti Aminah',
      username: 'siti',
      password: '1234',
    );

    expect(await repository.isUsernameAvailable('SITI'), isFalse);
    expect(await repository.isUsernameAvailable('kasir2'), isTrue);
    expect(await repository.isUsernameAvailable('ab'), isFalse);
  });
}
