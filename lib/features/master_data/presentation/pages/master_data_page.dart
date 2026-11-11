import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/master_data_repository.dart';
import '../cubit/addon_cubit.dart';
import '../cubit/category_cubit.dart';
import '../cubit/product_cubit.dart';
import 'addon_tab_page.dart';
import 'category_tab_page.dart';
import 'product_tab_page.dart';

/// Halaman utama pengelolaan master data.
///
/// Tiga tab dipakai agar kasir bisa berpindah cepat antara kategori, produk,
/// dan add-on tanpa membuka halaman bertingkat. Seluruh Cubit dibuat di sini
/// sehingga state tidak hilang saat berpindah tab.
class MasterDataPage extends StatelessWidget {
  const MasterDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Repository disediakan di main.dart melalui RepositoryProvider.
    final repository = context.read<MasterDataRepository>();

    return MultiBlocProvider(
      providers: [
        // Masing-masing Cubit langsung memuat data dari SQLite saat dibuat.
        BlocProvider(create: (_) => CategoryCubit(repository)..load()),
        BlocProvider(create: (_) => ProductCubit(repository)..load()),
        BlocProvider(create: (_) => AddonCubit(repository)..load()),
      ],
      child: const _MasterDataView(),
    );
  }
}

class _MasterDataView extends StatelessWidget {
  const _MasterDataView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Master Data'),
          bottom: TabBar(
            // Muat ulang data tab yang dibuka. Tujuannya agar perubahan di tab
            // lain langsung tercermin, misalnya nama kategori pada daftar
            // produk (hasil JOIN) dan jumlah produk pada daftar kategori.
            onTap: (index) {
              switch (index) {
                case 0:
                  context.read<CategoryCubit>().load();
                case 1:
                  context.read<ProductCubit>().load();
                case 2:
                  context.read<AddonCubit>().load();
              }
            },
            tabs: const [
              Tab(icon: Icon(Icons.category_outlined), text: 'Kategori'),
              Tab(icon: Icon(Icons.shopping_bag_outlined), text: 'Produk'),
              Tab(icon: Icon(Icons.extension_outlined), text: 'Add-on'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const CategoryTabPage(),
            const ProductTabPage(),
            const AddonTabPage(),
          ],
        ),
      ),
    );
  }
}
