# Mini POS Offline

Mini POS Offline is a Flutter point-of-sale application for small retail and
food-service operations. It is designed to work without an internet connection
and stores authentication, catalog, inventory, sales, and reporting data in a
local SQLite database.

## Highlights

- Offline cashier login with a persisted local session.
- Category, product, and add-on management.
- Product photos copied to permanent application storage.
- Product search, category filtering, add-on selection, and cart management.
- Shared stock validation across cart rows and product variants.
- Cash checkout with discounts, change calculation, and digital receipts.
- Atomic checkout that saves the sale and reduces stock as one operation.
- Sales summaries, transaction history, and immutable historical receipts.
- Quick Cash shortcuts, low-stock indicators, and tablet-responsive layouts.

## Technology Stack

- **Flutter / Dart**: cross-platform UI and application runtime.
- **flutter_bloc**: Cubit-based presentation state management.
- **sqflite**: local SQLite persistence.
- **path_provider**: permanent application document storage for product photos.
- **image_picker**: camera and gallery photo selection.
- **intl**: currency and date formatting.
- **crypto**: SHA-256 hashing for cashier PINs/passwords.
- **sqflite_common_ffi**: SQLite implementation used by desktop tests.

## Architecture

The project follows a feature-first Clean Architecture structure. Each feature
is separated into presentation, domain, and data responsibilities:

```text
lib/
├── core/
│   ├── database/       SQLite connection, schema, constants, parsers
│   ├── theme/          Application theme
│   ├── utils/          Shared formatting and utility functions
│   └── widgets/        Shared UI components
├── features/
│   ├── auth/           Registration, login, session, and auth gate
│   ├── master_data/    Categories, products, add-ons, and product images
│   ├── pos/            Catalog, cart, discounts, checkout, and receipts
│   └── report/         Sales summary, transaction history, and receipt detail
└── main.dart           Dependency composition and application entry point
```

The usual dependency direction is:

```text
UI page/widget -> Cubit -> domain repository interface
							-> data repository implementation -> local data source -> SQLite
```

Repositories are composed manually in `main.dart` and exposed through
`RepositoryProvider`. This keeps database access out of widgets and makes
domain logic independently testable.

## State Management

The application uses **flutter_bloc**, primarily through `Cubit` classes:

- `LoginCubit`, `RegisterCubit`, and `SessionCubit` manage authentication and
	the persisted cashier session.
- `CategoryCubit`, `ProductCubit`, and `AddonCubit` manage master data loading,
	mutations, and user-facing failures.
- `PosCatalogCubit` loads the catalog, while `CartCubit` owns the in-memory
	cart, shared stock validation, totals, and discount protection.
- `CheckoutCubit` validates payment input and submits the checkout request.
- `ReportCubit` and `ReceiptDetailCubit` load sales summaries, history, and
	historical receipt details.

The cart deliberately remains in memory until checkout. The checkout
repository recalculates totals and validates the request again before writing,
so values displayed by the UI are not trusted as the only business safeguard.

## SQLite Database

The database file is `mini_pos.db` and the current schema version is `2`.
Foreign-key enforcement is enabled with `PRAGMA foreign_keys = ON`.
Currency values are stored as integer Rupiah amounts to avoid floating-point
rounding errors.

### Tables

| Table | Important columns | Purpose |
| --- | --- | --- |
| `users` | `id`, `name`, `username`, `password_hash`, `created_at` | Cashier/admin accounts. Usernames are unique. |
| `user_sessions` | `id`, `user_id`, `user_name`, `username`, `logged_in_at` | One persisted active session per device. `id = 1` is enforced by a `CHECK` constraint. |
| `categories` | `id`, `name`, `created_at` | Product categories. Names are unique case-insensitively. |
| `products` | `id`, `category_id`, `name`, `price`, `stock`, `image_path`, `is_deleted`, `created_at` | Product master data and inventory. Products use soft delete. |
| `addons` | `id`, `name`, `price`, `stock`, `is_deleted`, `created_at` | Add-on/topping master data and inventory. Add-ons use soft delete. |
| `transactions` | `id`, `invoice_number`, `cashier_name`, `subtotal`, `discount_type`, `discount_value`, `discount_amount`, `total_amount`, `cash_received`, `change_amount`, `created_at` | Sales header and payment snapshot. |
| `transaction_items` | `id`, `transaction_id`, `product_id`, `product_name_snapshot`, `product_price_snapshot`, `quantity`, `subtotal` | Product lines belonging to a transaction. |
| `transaction_item_addons` | `id`, `transaction_item_id`, `addon_id`, `addon_name_snapshot`, `addon_price_snapshot`, `quantity` | Add-ons belonging to a transaction item. |

### Relationships

```text
users 1 ───── 0..1 user_sessions
categories 1 ───── many products
transactions 1 ───── many transaction_items
products 0..1 ───── many transaction_items
transaction_items 1 ───── many transaction_item_addons
addons 0..1 ───── many transaction_item_addons
```

- `user_sessions.user_id` references `users.id` with `ON DELETE CASCADE`.
- `products.category_id` references `categories.id` with `ON DELETE RESTRICT`.
- `transaction_items.transaction_id` references `transactions.id` with
	`ON DELETE CASCADE`.
- `transaction_items.product_id` and `transaction_item_addons.addon_id` use
	`ON DELETE SET NULL`; the historical snapshot columns remain readable even
	if master data is later changed or removed.
- `transaction_item_addons.transaction_item_id` references
	`transaction_items.id` with `ON DELETE CASCADE`.

### Data Integrity

- Checkout runs in one `db.transaction`: header, snapshot details, and stock
	reductions either all commit or all roll back.
- Product and add-on stock cannot become negative at the database level.
- Percentage discounts cannot exceed `100%`; nominal discounts cannot exceed
	the subtotal; and the final total cannot be negative.
- Transaction rows store cashier, product, and add-on snapshots so historical
	receipts do not change when master data changes.
- Product photos are copied from temporary camera/gallery paths to the
	application documents directory before the permanent path is stored.

## Bonus Features

### Quick Cash

The checkout screen provides payment shortcuts so a cashier does not need to
type common cash amounts manually. It always includes the exact bill amount
(`Uang pas`) and calculates nearby amounts rounded up to the nearest `Rp 5,000`,
`Rp 10,000`, `Rp 50,000`, or `Rp 100,000`. Every suggested amount is guaranteed
to be at least the final bill, and the change is updated immediately.

### Low Stock Indicator

Product cards show the remaining sellable stock after subtracting the quantity
already placed in the cart. The UI uses a distinct low-stock style for values
from `0` to `3`, shows `HABIS` when the effective stock reaches zero, and
disables the product card and quick-add action when it is unavailable. Shared
stock validation also aggregates the same product or add-on across different
cart rows.

### Tablet Responsiveness

The POS layout adapts to the available width:

- At widths of `900 px` and above, the catalog and a persistent `360 px` cart
	panel are shown side by side.
- Below `900 px`, the catalog uses the full screen and the cart opens from the
	bottom summary bar.
- The catalog grid uses two, three, four, or five columns depending on the
	available width, including space consumed by the cart panel.

## Running the Project

Prerequisites:

- Flutter stable SDK compatible with Dart `3.13.4` or newer within the declared
	SDK range.
- A configured Android, Windows, or other Flutter-supported device/target.

Install dependencies and run the application:

```bash
flutter pub get
flutter run
```

Run the test suite:

```bash
flutter test
```

The tests use an in-memory SQLite database through `sqflite_common_ffi`, so
they do not modify the application's real local database.
