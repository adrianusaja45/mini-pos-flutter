# Project Context: Mini POS Offline Flutter App

## 1. Tech Stack & Architecture (Mandatory)
- **Framework**: Flutter (Latest Stable Dart).
- **Architecture**: Clean Architecture (`data`, `domain`, `presentation` per feature + `core` untuk shared utilities/database).
- **State Management**: `flutter_bloc` (Cubit/BLoC) dengan pemisahan ketat antara UI dan business logic.
- **Local Database**: `sqflite` (SQLite) dengan skema tabel relasional dan **Atomic Transactions (`db.transaction`)** saat pengurangan stok[cite: 2].
- **Local File Storage**: `path_provider` untuk menyalin foto produk ke Application Documents Directory agar permanen meski cache dihapus[cite: 2].

## 2. Coding & Documentation Rules (CRITICAL)
- **Bahasa Komentar**: Semua komentar di dalam kode (`//` atau `///`) WAJIB menggunakan **Bahasa Indonesia yang jelas, ringkas, dan edukatif**, menjelaskan **apa fungsi blok kode/method tersebut dan mengapa dibuat seperti itu**.
- **Modularity**: Kerjakan HANYA bagian/fitur yang diminta pada prompt saat ini. Jangan membuat file untuk fitur berikutnya sebelum diminta.
- **Post-Generation Explanation**: Setelah selesai membuat atau mengubah kode pada suatu tahap, SELALU berikan ringkasan penjelasan dalam Bahasa Indonesia meliputi:
  1. Daftar file yang dibuat/diubah beserta perannya.
  2. Alur data (*Data Flow*) dari UI -> Cubit/BLoC -> Repository -> SQLite.
  3. Penjelasan logika penting (terutama validasi bisnis) agar mudah dipahami untuk persiapan *code walkthrough*.

## 3. Core Business Rules & Hardship Challenges (Must Enforce)
1. **Shared Stock Validation**: Total konsumsi stok di keranjang (cart) dihitung berdasarkan akumulasi `product_id` yang sama meskipun memiliki variasi `add_on` berbeda. Hal yang sama berlaku untuk akumulasi stok `add_on_id`.
2. **Transaction History Immutability (Snapshot)**: Tabel detail transaksi (`transaction_items` & `transaction_item_addons`) WAJIB menyimpan salinan nama dan harga saat transaksi terjadi (snapshot), bukan hanya foreign key ke master data, agar perubahan/penghapusan master data tidak mengubah riwayat struk & laporan[cite: 2].
3. **Offline Photo Persistence**: Foto dari kamera/galeri wajib disalin (`File.copy`) ke direktori permanen aplikasi (`getApplicationDocumentsDirectory`), dan yang disimpan di SQLite adalah path permanen tersebut[cite: 2].
4. **Discount Protection**: Total tagihan tidak boleh minus (`< 0`), diskon nominal tidak boleh melebihi subtotal, dan diskon persentase tidak boleh melebihi `100%`[cite: 2].