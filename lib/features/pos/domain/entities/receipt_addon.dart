import 'package:equatable/equatable.dart';

/// Snapshot satu add-on pada struk digital.
///
/// Seluruh nilai di sini berasal dari salinan yang tersimpan di tabel
/// `transaction_item_addons`, bukan dari master data. Jadi struk lama tetap
/// menampilkan nama & harga yang benar walaupun master add-on berubah.
class ReceiptAddon extends Equatable {
  const ReceiptAddon({
    required this.addonId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  /// Id master add-on saat transaksi (boleh sudah tidak aktif sekarang).
  ///
  /// Bisa `null` karena `transaction_item_addons.addon_id` memakai
  /// `ON DELETE SET NULL`; nama & harga add-on tetap dibaca dari kolom snapshot
  /// sehingga struk lama tidak rusak saat master add-on dihapus.
  final int? addonId;

  /// Nama add-on yang tercetak di struk (snapshot).
  final String name;

  /// Harga satuan add-on saat transaksi (snapshot, Rupiah).
  final int price;

  /// Jumlah unit add-on, mengikuti quantity baris produknya.
  final int quantity;

  @override
  List<Object?> get props => [addonId, name, price, quantity];
}
