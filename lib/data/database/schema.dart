import 'package:sqflite/sqflite.dart';

/// Ordered, non-destructive migrations. V1 establishes relational storage;
/// V2 adds query/FK indexes. Both fresh install and upgrade use this same path.
final class Schema {
  static const version = 10;

  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (newVersion > version || oldVersion > newVersion) {
      throw StateError('Versi skema tidak didukung.');
    }
    for (var target = oldVersion + 1; target <= newVersion; target++) {
      for (final statement in switch (target) {
        1 => _tables,
        2 => _indexes,
        3 => _management,
        4 => _currency,
        5 => _cashier,
        6 => _wholesalePackaging,
        7 => _reportingCorrections,
        8 => _peripheralsAndBackup,
        9 => _productAttributes,
        10 => _managementPolicy,
        _ => throw StateError('Migration tidak tersedia.'),
      }) {
        await db.execute(statement);
      }
    }
    if (oldVersion == 0 && newVersion >= 10) {
      await db.execute("UPDATE management_policy SET session_policy='immediate' WHERE id=1");
    }
    if (newVersion == version) {
      if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty ||
          (await db.rawQuery('PRAGMA quick_check')).single.values.single !=
              'ok') {
        throw StateError('Migration integrity check failed');
      }
    }
    // sqflite wraps onCreate/onUpgrade in its own transaction. Never open
    // another connection/transaction inside these callbacks.
  }

  static String _id(String name) =>
      '$name TEXT PRIMARY KEY NOT NULL CHECK(length($name) = 36)';

  static const _managementPolicy = [
    '''CREATE TABLE management_policy(id INTEGER PRIMARY KEY CHECK(id=1),
      session_policy TEXT NOT NULL CHECK(session_policy IN ('legacy','1m','5m','15m','immediate')))''',
    "INSERT INTO management_policy(id,session_policy) VALUES(1,'legacy')",
  ];

  /// Additive nullable metadata: old sale facts must never inherit master edits.
  static List<String> get _productAttributes => [
    for (final table in ['products', 'sale_transaction_items']) ...[
      'ALTER TABLE $table ADD COLUMN size_milli${table == 'products' ? '' : '_snapshot'} INTEGER CHECK(size_milli${table == 'products' ? '' : '_snapshot'} IS NULL OR (typeof(size_milli${table == 'products' ? '' : '_snapshot'})=\'integer\' AND size_milli${table == 'products' ? '' : '_snapshot'} BETWEEN 1 AND 999999999999))',
      'ALTER TABLE $table ADD COLUMN size_unit${table == 'products' ? '' : '_snapshot'} TEXT CHECK((size_milli${table == 'products' ? '' : '_snapshot'} IS NULL AND size_unit${table == 'products' ? '' : '_snapshot'} IS NULL) OR (size_milli${table == 'products' ? '' : '_snapshot'} IS NOT NULL AND size_unit${table == 'products' ? '' : '_snapshot'} IS NOT NULL AND size_unit${table == 'products' ? '' : '_snapshot'} IN (\'g\',\'kg\',\'ml\',\'l\')))',
      'ALTER TABLE $table ADD COLUMN shelf_location${table == 'products' ? '' : '_snapshot'} TEXT CHECK(length(shelf_location${table == 'products' ? '' : '_snapshot'})<=80)',
      'ALTER TABLE $table ADD COLUMN product_note${table == 'products' ? '' : '_snapshot'} TEXT CHECK(length(product_note${table == 'products' ? '' : '_snapshot'})<=1000)',
    ],
  ];

  /// Side effects have their own durable identities and never create financial
  /// facts. Restore clears installation-local consent, jobs and device bindings.
  static List<String> get _peripheralsAndBackup => [
    '''CREATE TABLE active_installation(id INTEGER PRIMARY KEY CHECK(id=1),
      installation_id TEXT NOT NULL REFERENCES installation_metadata(id) ON DELETE RESTRICT)''',
    '''CREATE TABLE receipt_assets(hash TEXT PRIMARY KEY NOT NULL, bytes BLOB NOT NULL
      CHECK(length(bytes)>0 AND length(bytes)<=4194304))''',
    '''CREATE TABLE m5_store(id INTEGER PRIMARY KEY CHECK(id=1), store_id TEXT NOT NULL,
      logo_asset TEXT REFERENCES receipt_assets(hash) ON DELETE RESTRICT,
      alert_generation INTEGER NOT NULL DEFAULT 0,
      alert_summary_delivered TEXT,
      expiry_warning_days INTEGER NOT NULL DEFAULT 5 CHECK(expiry_warning_days BETWEEN 0 AND 365),
      notifications_enabled INTEGER NOT NULL DEFAULT 0 CHECK(notifications_enabled IN (0,1)))''',
    '''CREATE TABLE printer_profiles(device_id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL,
      settings_json TEXT NOT NULL, selected INTEGER NOT NULL DEFAULT 0 CHECK(selected IN (0,1)))''',
    'CREATE UNIQUE INDEX one_selected_printer ON printer_profiles(selected) WHERE selected=1',
    '''CREATE TABLE print_receipts(sale_transaction_id TEXT PRIMARY KEY NOT NULL
      REFERENCES sale_transactions(id) ON DELETE RESTRICT, snapshot_json TEXT NOT NULL)''',
    '''CREATE TRIGGER print_receipts_no_update BEFORE UPDATE ON print_receipts
      BEGIN SELECT RAISE(ABORT,'immutable_receipt'); END''',
    '''CREATE TRIGGER print_receipts_no_delete BEFORE DELETE ON print_receipts
      BEGIN SELECT RAISE(ABORT,'immutable_receipt'); END''',
    '''CREATE TABLE print_jobs(id TEXT PRIMARY KEY NOT NULL, operation_key TEXT NOT NULL UNIQUE,
      sale_transaction_id TEXT REFERENCES sale_transactions(id) ON DELETE RESTRICT,
      device_id TEXT NOT NULL, profile_json TEXT NOT NULL, snapshot_json TEXT NOT NULL,
      status TEXT NOT NULL CHECK(status IN ('prepared','sending','submitted','failed','unknown','cancelled')),
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, error_code TEXT)''',
    'CREATE INDEX print_jobs_cursor ON print_jobs(created_at DESC,id COLLATE BINARY DESC)',
    '''CREATE TABLE alert_state(notification_id INTEGER PRIMARY KEY AUTOINCREMENT,
      alert_key TEXT NOT NULL UNIQUE, product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      kind TEXT NOT NULL CHECK(kind IN ('low_stock','expiry')), body_json TEXT NOT NULL,
      active INTEGER NOT NULL CHECK(active IN (0,1)), fingerprint TEXT NOT NULL,
      delivered_fingerprint TEXT, evaluation INTEGER NOT NULL DEFAULT 0)''',
    'CREATE INDEX alert_active_cursor ON alert_state(active,notification_id)',
    '''CREATE TABLE backup_runs(id TEXT PRIMARY KEY NOT NULL, operation_key TEXT NOT NULL UNIQUE,
      origin_id TEXT NOT NULL, account_id TEXT, status TEXT NOT NULL,
      started_at INTEGER NOT NULL, completed_at INTEGER, next_target INTEGER,
      error_code TEXT, remote_id TEXT, manifest_json TEXT)''',
    'ALTER TABLE backup_runs ADD COLUMN snapshot_path TEXT',
    'CREATE INDEX backup_runs_cursor ON backup_runs(started_at DESC,id COLLATE BINARY DESC)',
    '''CREATE TABLE local_backups(id TEXT PRIMARY KEY NOT NULL,created_at INTEGER NOT NULL,
      manifest_json TEXT NOT NULL,archive_path TEXT NOT NULL,sha256 TEXT NOT NULL)''',
    'CREATE INDEX local_backups_cursor ON local_backups(created_at DESC,id COLLATE BINARY DESC)',
    '''CREATE TABLE backup_schedule(id INTEGER PRIMARY KEY CHECK(id=1), next_target INTEGER,
      last_attempt INTEGER,last_success INTEGER,error_code TEXT,zone TEXT)''',
    'INSERT INTO backup_schedule(id) VALUES(1)',
  ];

  /// Provenance links do not rewrite immutable payment facts. Legacy origins
  /// are inferred only from exact checkout keys/allocations or recorded audits;
  /// unidentifiable receipts remain explicitly unknown in reporting.
  static List<String> get _reportingCorrections => [
    "ALTER TABLE sale_transaction_reversals ADD COLUMN payload_hash TEXT NOT NULL DEFAULT ''",
    'ALTER TABLE sale_transaction_reversals ADD COLUMN goods_returned INTEGER CHECK(goods_returned IS NULL OR goods_returned=1)',
    '''CREATE TABLE checkout_payment_links(
      payment_id TEXT PRIMARY KEY REFERENCES payments(id) ON DELETE RESTRICT,
      sale_transaction_id TEXT NOT NULL UNIQUE REFERENCES sale_transactions(id) ON DELETE RESTRICT)''',
    '''CREATE TABLE receivable_payment_links(
      payment_id TEXT PRIMARY KEY REFERENCES payments(id) ON DELETE RESTRICT)''',
    '''INSERT INTO checkout_payment_links(payment_id,sale_transaction_id)
      SELECT p.id,s.id FROM payments p JOIN payment_allocations a ON a.payment_id=p.id
      JOIN sale_transactions s ON s.id=a.sale_transaction_id
      WHERE p.kind='receipt' AND p.operation_key='checkout:'||s.checkout_key
      AND p.created_at=s.created_at AND p.customer_id IS s.customer_id
      AND p.currency_code=s.currency_code AND p.currency_scale=s.currency_scale
      AND p.amount_rupiah=a.amount_rupiah
      AND p.amount_rupiah<=s.total_rupiah
      AND (SELECT COUNT(*) FROM payment_allocations x WHERE x.payment_id=p.id)=1''',
    '''INSERT INTO receivable_payment_links(payment_id)
      SELECT p.id FROM payments p WHERE p.kind='receipt'
      AND NOT EXISTS(SELECT 1 FROM checkout_payment_links l WHERE l.payment_id=p.id)
      AND EXISTS(SELECT 1 FROM audit_log a WHERE a.action='receivable_payment' AND a.entity_id=p.id)''',
    for (final table in [
      'checkout_payment_links',
      'receivable_payment_links',
    ]) ...[
      "CREATE TRIGGER ${table}_no_update BEFORE UPDATE ON $table BEGIN SELECT RAISE(ABORT,'immutable_fact'); END",
      "CREATE TRIGGER ${table}_no_delete BEFORE DELETE ON $table BEGIN SELECT RAISE(ABORT,'immutable_fact'); END",
    ],
    '''CREATE TRIGGER checkout_payment_link_valid BEFORE INSERT ON checkout_payment_links
      WHEN EXISTS(SELECT 1 FROM receivable_payment_links l WHERE l.payment_id=NEW.payment_id)
      OR NOT EXISTS(SELECT 1 FROM payments p JOIN payment_allocations a ON a.payment_id=p.id
        JOIN sale_transactions s ON s.id=a.sale_transaction_id WHERE p.id=NEW.payment_id
        AND s.id=NEW.sale_transaction_id AND p.kind='receipt'
        AND p.operation_key='checkout:'||s.checkout_key AND p.customer_id IS s.customer_id
        AND p.currency_code=s.currency_code AND p.currency_scale=s.currency_scale
        AND p.amount_rupiah=a.amount_rupiah AND p.amount_rupiah<=s.total_rupiah
        AND (SELECT COUNT(*) FROM payment_allocations x WHERE x.payment_id=p.id)=1)
      BEGIN SELECT RAISE(ABORT,'invalid_payment_origin'); END''',
    '''CREATE TRIGGER receivable_payment_link_valid BEFORE INSERT ON receivable_payment_links
      WHEN EXISTS(SELECT 1 FROM checkout_payment_links l WHERE l.payment_id=NEW.payment_id)
      OR NOT EXISTS(SELECT 1 FROM payments p WHERE p.id=NEW.payment_id AND p.kind='receipt'
        AND p.customer_id IS NOT NULL AND p.amount_rupiah=(SELECT SUM(a.amount_rupiah)
          FROM payment_allocations a WHERE a.payment_id=p.id)
        AND NOT EXISTS(SELECT 1 FROM payment_allocations a JOIN sale_transactions s
          ON s.id=a.sale_transaction_id WHERE a.payment_id=p.id AND
          (s.customer_id IS NOT p.customer_id OR s.currency_code<>p.currency_code
            OR s.currency_scale<>p.currency_scale)))
      BEGIN SELECT RAISE(ABORT,'invalid_payment_origin'); END''',
    '''CREATE TRIGGER payment_reversal_matches BEFORE INSERT ON payments
      WHEN NEW.kind='reversal' AND NOT EXISTS(SELECT 1 FROM payments p
        WHERE p.id=NEW.reverses_payment_id AND p.kind='receipt'
        AND p.customer_id IS NEW.customer_id AND p.amount_rupiah=NEW.amount_rupiah
        AND p.currency_code=NEW.currency_code AND p.currency_scale=NEW.currency_scale)
      BEGIN SELECT RAISE(ABORT,'invalid_payment_reversal'); END''',
    '''CREATE TRIGGER reversal_allocation_matches BEFORE INSERT ON payment_allocations
      WHEN (SELECT kind FROM payments WHERE id=NEW.payment_id)='reversal'
      AND NOT EXISTS(SELECT 1 FROM payments p JOIN payment_allocations a
        ON a.payment_id=p.reverses_payment_id WHERE p.id=NEW.payment_id
        AND a.sale_transaction_id=NEW.sale_transaction_id AND a.amount_rupiah=NEW.amount_rupiah)
      BEGIN SELECT RAISE(ABORT,'invalid_reversal_allocation'); END''',
    'CREATE INDEX payments_period ON payments(kind,created_at DESC,id COLLATE BINARY DESC)',
    'CREATE INDEX sale_reversals_period ON sale_transaction_reversals(created_at DESC,id COLLATE BINARY DESC)',
  ];

  /// V6 is additive: legacy receipt conversion stays unknown (NULL), while
  /// old draft/sale modes default retail. No stock/financial value is rewritten.
  static List<String> get _wholesalePackaging => [
    "ALTER TABLE products ADD COLUMN wholesale_price_minor INTEGER CHECK(wholesale_price_minor IS NULL OR (typeof(wholesale_price_minor)='integer' AND wholesale_price_minor>0))",
    'ALTER TABLE products ADD COLUMN pack_label TEXT',
    "ALTER TABLE products ADD COLUMN pack_size INTEGER CHECK(pack_size IS NULL OR (typeof(pack_size)='integer' AND pack_size>0))",
    "ALTER TABLE products ADD COLUMN base_unit_label TEXT NOT NULL DEFAULT 'pcs'",
    for (final table in ['cart_draft_items', 'sale_transaction_items'])
      "ALTER TABLE $table ADD COLUMN pricing_mode TEXT NOT NULL DEFAULT 'retail' CHECK(pricing_mode IN ('retail','wholesale'))",
    "ALTER TABLE price_history ADD COLUMN price_kind TEXT NOT NULL DEFAULT 'retail' CHECK(price_kind IN ('retail','wholesale'))",
    'ALTER TABLE price_history ADD COLUMN before_price_minor INTEGER CHECK(before_price_minor IS NULL OR before_price_minor>=0)',
    'ALTER TABLE price_history ADD COLUMN after_price_minor INTEGER CHECK(after_price_minor IS NULL OR after_price_minor>=0)',
    // Existing NOT NULL retail columns remain for compatibility. Typed nullable
    // snapshots distinguish removal from zero; wholesale readers use ONLY these.
    "ALTER TABLE stock_receipt_items ADD COLUMN input_unit TEXT CHECK(input_unit IN ('base','pack'))",
    'ALTER TABLE stock_receipt_items ADD COLUMN input_quantity INTEGER CHECK(input_quantity IS NULL OR input_quantity>0)',
    'ALTER TABLE stock_receipt_items ADD COLUMN pack_size_snapshot INTEGER CHECK(pack_size_snapshot IS NULL OR pack_size_snapshot>0)',
    'ALTER TABLE stock_receipt_items ADD COLUMN pack_label_snapshot TEXT',
    'ALTER TABLE stock_receipt_items ADD COLUMN base_unit_snapshot TEXT',
    'ALTER TABLE stock_receipt_items ADD COLUMN input_unit_cost_micros INTEGER CHECK(input_unit_cost_micros IS NULL OR input_unit_cost_micros>=0)',
    'ALTER TABLE stock_receipt_items ADD COLUMN currency_code TEXT',
    'ALTER TABLE stock_receipt_items ADD COLUMN currency_scale INTEGER',
    for (final event in ['INSERT', 'UPDATE'])
      "CREATE TRIGGER product_pack_${event.toLowerCase()} BEFORE $event ON products WHEN NOT ((NEW.pack_label IS NULL AND NEW.pack_size IS NULL) OR (NEW.pack_label IS NOT NULL AND length(trim(NEW.pack_label))>0 AND NEW.pack_size IS NOT NULL AND NEW.pack_size>0)) BEGIN SELECT RAISE(ABORT,'invalid_pack'); END",
    "CREATE TRIGGER receipt_input_guard BEFORE INSERT ON stock_receipt_items WHEN NEW.input_unit IS NOT NULL AND (NEW.base_unit_snapshot IS NULL OR typeof(NEW.input_quantity)<>'integer' OR typeof(NEW.input_unit_cost_micros)<>'integer' OR (NEW.input_unit='pack' AND typeof(NEW.pack_size_snapshot)<>'integer') OR NEW.input_quantity IS NULL OR NEW.input_unit_cost_micros IS NULL OR NEW.currency_code IS NULL OR NEW.currency_scale IS NULL OR NEW.currency_code<>(SELECT currency_code FROM stock_receipts WHERE id=NEW.stock_receipt_id) OR NEW.currency_scale<>(SELECT currency_scale FROM stock_receipts WHERE id=NEW.stock_receipt_id) OR NEW.total_cost_micros / NEW.input_quantity <> NEW.input_unit_cost_micros OR NEW.total_cost_micros % NEW.input_quantity <> 0 OR (NEW.input_unit='base' AND (NEW.quantity<>NEW.input_quantity OR NEW.pack_size_snapshot IS NOT NULL OR NEW.pack_label_snapshot IS NOT NULL)) OR (NEW.input_unit='pack' AND (NEW.pack_size_snapshot IS NULL OR NEW.pack_label_snapshot IS NULL OR NEW.quantity / NEW.input_quantity <> NEW.pack_size_snapshot OR NEW.quantity % NEW.input_quantity <> 0))) BEGIN SELECT RAISE(ABORT,'invalid_receipt_input'); END",
  ];

  /// M3 adds durable payment input/recovery pointers and a portable prefix
  /// index. Financial facts and IDR0 legacy amounts are never rewritten.
  static const _cashier = [
    "ALTER TABLE cart_drafts ADD COLUMN payment_mode TEXT NOT NULL DEFAULT 'paid' CHECK(payment_mode IN ('paid','partial','debt'))",
    'ALTER TABLE cart_drafts ADD COLUMN paid_minor INTEGER CHECK(paid_minor IS NULL OR (typeof(paid_minor)=\'integer\' AND paid_minor>=0))',
    'ALTER TABLE cart_drafts ADD COLUMN customer_id TEXT REFERENCES customers(id) ON DELETE RESTRICT',
    'ALTER TABLE cart_drafts ADD COLUMN customer_name TEXT',
    'ALTER TABLE cart_drafts ADD COLUMN customer_phone TEXT',
    'ALTER TABLE sale_transactions ADD COLUMN payload_hash TEXT',
    'ALTER TABLE payments ADD COLUMN payload_hash TEXT',
    'CREATE TABLE cashier_state(id INTEGER PRIMARY KEY CHECK(id=1), draft_id TEXT REFERENCES cart_drafts(id) ON DELETE RESTRICT)',
    'INSERT INTO cashier_state(id) VALUES(1)',
    'CREATE INDEX customers_list ON customers(is_deleted,normalized_name COLLATE BINARY,id COLLATE BINARY)',
    "CREATE INDEX stock_batches_sale_fefo ON stock_batches(product_id,COALESCE(expiry_date,'9999-99-99') COLLATE BINARY,received_at,id COLLATE BINARY)",
    'CREATE INDEX cart_drafts_recent ON cart_drafts(updated_at DESC,id COLLATE BINARY DESC)',
    '''CREATE TABLE cashier_search_terms(
      product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
      term TEXT COLLATE BINARY NOT NULL, priority INTEGER NOT NULL,
      PRIMARY KEY(product_id,term,priority))''',
    'CREATE INDEX cashier_terms_prefix ON cashier_search_terms(term COLLATE BINARY,priority,product_id COLLATE BINARY)',
    'CREATE TABLE cashier_search_dirty(product_id TEXT PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE)',
    'INSERT INTO cashier_search_dirty SELECT id FROM products',
    'CREATE TRIGGER cashier_product_insert AFTER INSERT ON products BEGIN INSERT OR IGNORE INTO cashier_search_dirty VALUES(NEW.id); END',
    'CREATE TRIGGER cashier_product_edit AFTER UPDATE OF name,normalized_name,compact_name,category_id,is_deleted ON products BEGIN INSERT OR IGNORE INTO cashier_search_dirty VALUES(NEW.id); END',
    'CREATE TRIGGER cashier_alias_insert AFTER INSERT ON product_aliases BEGIN INSERT OR IGNORE INTO cashier_search_dirty VALUES(NEW.product_id); END',
    'CREATE TRIGGER cashier_alias_delete AFTER DELETE ON product_aliases BEGIN INSERT OR IGNORE INTO cashier_search_dirty VALUES(OLD.product_id); END',
    'CREATE TRIGGER cashier_category_edit AFTER UPDATE ON categories BEGIN INSERT OR IGNORE INTO cashier_search_dirty SELECT id FROM products WHERE category_id=NEW.id; END',
    "CREATE TRIGGER completed_draft_guard BEFORE UPDATE ON cart_drafts WHEN OLD.state='completed' BEGIN SELECT RAISE(ABORT,'completed_draft'); END",
    "CREATE TRIGGER completed_draft_item_insert BEFORE INSERT ON cart_draft_items WHEN (SELECT state FROM cart_drafts WHERE id=NEW.draft_id)<>'active' BEGIN SELECT RAISE(ABORT,'inactive_draft'); END",
    "CREATE TRIGGER completed_draft_item_update BEFORE UPDATE ON cart_draft_items WHEN (SELECT state FROM cart_drafts WHERE id=OLD.draft_id)<>'active' BEGIN SELECT RAISE(ABORT,'inactive_draft'); END",
    "CREATE TRIGGER completed_draft_item_delete BEFORE DELETE ON cart_draft_items WHEN (SELECT state FROM cart_drafts WHERE id=OLD.draft_id)<>'active' BEGIN SELECT RAISE(ABORT,'inactive_draft'); END",
  ];

  /// Additive metadata only: old amounts are IDR whole rupiah, never x100.
  /// Legacy *_rupiah SQL names remain compatibility storage names, now minor
  /// units tied to immutable metadata; public domain values use Money.
  static List<String> get _currency => [
    "ALTER TABLE store_settings ADD COLUMN ui_language TEXT CHECK(ui_language IN ('id','en'))",
    for (final table in [
      'store_settings',
      'products',
      'stock_receipts',
      'cart_drafts',
      'sale_transactions',
      'payments',
      'stock_history',
      'price_history',
      'inventory_operations',
    ]) ...[
      "ALTER TABLE $table ADD COLUMN currency_code TEXT NOT NULL DEFAULT 'IDR' CHECK(currency_code IN ('IDR','USD','MYR','EUR'))",
      "ALTER TABLE $table ADD COLUMN currency_scale INTEGER NOT NULL DEFAULT 0 CHECK((currency_code='IDR' AND currency_scale=0) OR (currency_code IN ('USD','MYR','EUR') AND currency_scale=2))",
    ],
    "CREATE TRIGGER store_currency_guard BEFORE UPDATE OF currency_code,currency_scale ON store_settings WHEN (NEW.currency_code<>OLD.currency_code OR NEW.currency_scale<>OLD.currency_scale) AND (EXISTS(SELECT 1 FROM products) OR EXISTS(SELECT 1 FROM stock_receipts) OR EXISTS(SELECT 1 FROM sale_transactions) OR EXISTS(SELECT 1 FROM payments) OR EXISTS(SELECT 1 FROM cart_draft_items) OR EXISTS(SELECT 1 FROM stock_history) OR EXISTS(SELECT 1 FROM price_history) OR EXISTS(SELECT 1 FROM inventory_operations)) BEGIN SELECT RAISE(ABORT,'currency_requires_conversion'); END",
    for (final table in [
      'products',
      'stock_receipts',
      'cart_drafts',
      'sale_transactions',
      'payments',
      'stock_history',
      'price_history',
      'inventory_operations',
    ])
      "CREATE TRIGGER ${table}_currency_insert BEFORE INSERT ON $table WHEN NEW.currency_code<>(SELECT currency_code FROM store_settings) OR NEW.currency_scale<>(SELECT currency_scale FROM store_settings) BEGIN SELECT RAISE(ABORT,'currency_mismatch'); END",
    'ALTER TABLE stock_history ADD COLUMN reason_key TEXT',
    'ALTER TABLE price_history ADD COLUMN reason_key TEXT',
    for (final table in ['stock_history', 'price_history'])
      'DROP TRIGGER ${table}_no_update',
    "UPDATE stock_history SET reason_key='initialStock' WHERE kind='initial' AND reason='Stok awal'",
    "UPDATE stock_history SET reason_key='receiveStock' WHERE kind='receipt' AND reason='Barang masuk'",
    "UPDATE price_history SET reason_key='priceChange' WHERE reason='Perubahan harga'",
    "UPDATE price_history SET reason_key='undoPrice' WHERE reason='Urungkan harga'",
    for (final table in ['stock_history', 'price_history'])
      "CREATE TRIGGER ${table}_no_update BEFORE UPDATE ON $table BEGIN SELECT RAISE(ABORT,'immutable_fact'); END",
  ];
  static String _amount(String name, {int? initial}) =>
      '$name INTEGER NOT NULL ${initial == null ? '' : 'DEFAULT $initial'} '
      'CHECK(typeof($name) = \'integer\' AND $name >= 0)';
  static String _positive(String name) =>
      '$name INTEGER NOT NULL CHECK(typeof($name) = \'integer\' AND $name > 0)';
  static String _flag(String name, int initial) =>
      '$name INTEGER NOT NULL DEFAULT $initial CHECK($name IN (0,1))';
  static const _name = 'name TEXT NOT NULL CHECK(length(trim(name)) > 0)';
  static const _normalized =
      'normalized_name TEXT COLLATE BINARY NOT NULL '
      'CHECK(length(normalized_name) > 0)';

  static List<String> get _tables => [
    '''CREATE TABLE categories (${_id('id')}, $_name, $_normalized,
      ${_flag('is_deleted', 0)}, ${_amount('created_at')})''',
    '''CREATE TABLE suppliers (${_id('id')}, $_name, $_normalized,
      contact_number TEXT, ${_flag('is_deleted', 0)}, ${_amount('created_at')})''',
    '''CREATE TABLE customers (${_id('id')}, $_name, $_normalized,
      phone_number TEXT, ${_flag('is_deleted', 0)}, ${_amount('created_at')})''',
    '''CREATE TABLE products (${_id('id')}, $_name, $_normalized,
      compact_name TEXT NOT NULL,
      sku TEXT COLLATE BINARY NOT NULL UNIQUE CHECK(length(trim(sku)) > 0),
      barcode TEXT COLLATE BINARY UNIQUE CHECK(barcode IS NULL OR length(trim(barcode)) > 0),
      category_id TEXT REFERENCES categories(id) ON DELETE RESTRICT,
      ${_amount('selling_price_rupiah')}, ${_amount('stock_quantity', initial: 0)},
      ${_amount('inventory_value_micros', initial: 0)},
      ${_amount('min_stock', initial: 5)}, ${_flag('low_stock_enabled', 1)},
      ${_flag('expiry_enabled', 0)}, ${_flag('is_deleted', 0)},
      ${_amount('revision', initial: 0)}, ${_amount('created_at')}, ${_amount('updated_at')},
      CHECK(stock_quantity > 0 OR inventory_value_micros = 0))''',
    '''CREATE TABLE product_aliases (
      product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      normalized_alias TEXT COLLATE BINARY NOT NULL CHECK(length(normalized_alias) > 0),
      PRIMARY KEY(product_id, normalized_alias))''',
    '''CREATE TABLE stock_receipts (${_id('id')},
      supplier_id TEXT REFERENCES suppliers(id) ON DELETE RESTRICT,
      operation_key TEXT NOT NULL UNIQUE CHECK(length(operation_key) > 0),
      ${_amount('created_at')}, note TEXT)''',
    '''CREATE TABLE stock_receipt_items (${_id('id')},
      stock_receipt_id TEXT NOT NULL REFERENCES stock_receipts(id) ON DELETE RESTRICT,
      product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      product_name_snapshot TEXT NOT NULL, ${_positive('quantity')},
      ${_amount('unit_cost_micros')}, ${_amount('total_cost_micros')})''',
    '''CREATE TABLE stock_batches (${_id('id')},
      product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      stock_receipt_item_id TEXT UNIQUE REFERENCES stock_receipt_items(id) ON DELETE RESTRICT,
      ${_positive('received_quantity')}, ${_amount('remaining_quantity')},
      expiry_date TEXT CHECK(expiry_date IS NULL OR
        (length(expiry_date) = 10 AND expiry_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')),
      ${_amount('received_at')}, CHECK(remaining_quantity <= received_quantity))''',
    // Circular references are intentional: checkout creates sale and completes
    // existing draft in one dbTxn. FK checks forbid dangling recovery references.
    '''CREATE TABLE cart_drafts (${_id('id')},
      state TEXT NOT NULL DEFAULT 'active' CHECK(state IN ('active','completed','abandoned')),
      completed_sale_transaction_id TEXT UNIQUE REFERENCES sale_transactions(id) ON DELETE RESTRICT,
      ${_amount('revision', initial: 0)}, ${_amount('created_at')}, ${_amount('updated_at')},
      CHECK((state = 'completed' AND completed_sale_transaction_id IS NOT NULL) OR
        (state != 'completed' AND completed_sale_transaction_id IS NULL)))''',
    '''CREATE TABLE cart_draft_items (
      draft_id TEXT NOT NULL REFERENCES cart_drafts(id) ON DELETE CASCADE,
      product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      ${_positive('quantity')}, ${_amount('accepted_price_rupiah')},
      ${_amount('product_revision')}, PRIMARY KEY(draft_id, product_id))''',
    '''CREATE TABLE sale_transactions (${_id('id')},
      checkout_key TEXT NOT NULL UNIQUE CHECK(length(checkout_key) > 0),
      draft_id TEXT NOT NULL UNIQUE REFERENCES cart_drafts(id) ON DELETE RESTRICT,
      customer_id TEXT REFERENCES customers(id) ON DELETE RESTRICT,
      customer_name_snapshot TEXT, customer_phone_snapshot TEXT,
      ${_amount('created_at')}, ${_amount('total_rupiah')}, ${_amount('cost_micros')})''',
    '''CREATE TABLE sale_transaction_items (${_id('id')},
      sale_transaction_id TEXT NOT NULL REFERENCES sale_transactions(id) ON DELETE RESTRICT,
      product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      product_name_snapshot TEXT NOT NULL, sku_snapshot TEXT NOT NULL, barcode_snapshot TEXT,
      ${_positive('quantity')}, ${_amount('unit_price_rupiah')},
      ${_amount('total_rupiah')}, ${_amount('cost_micros')},
      UNIQUE(sale_transaction_id, product_id))''',
    '''CREATE TABLE sale_batch_allocations (${_id('id')},
      sale_transaction_item_id TEXT NOT NULL REFERENCES sale_transaction_items(id) ON DELETE RESTRICT,
      stock_batch_id TEXT NOT NULL REFERENCES stock_batches(id) ON DELETE RESTRICT,
      ${_positive('quantity')}, UNIQUE(sale_transaction_item_id, stock_batch_id))''',
    '''CREATE TABLE payments (${_id('id')},
      operation_key TEXT NOT NULL UNIQUE CHECK(length(operation_key) > 0),
      customer_id TEXT REFERENCES customers(id) ON DELETE RESTRICT,
      kind TEXT NOT NULL CHECK(kind IN ('receipt','reversal')),
      reverses_payment_id TEXT UNIQUE REFERENCES payments(id) ON DELETE RESTRICT,
      ${_positive('amount_rupiah')}, ${_amount('created_at')}, reason TEXT,
      CHECK((kind = 'receipt' AND reverses_payment_id IS NULL) OR
        (kind = 'reversal' AND reverses_payment_id IS NOT NULL AND reason IS NOT NULL AND length(trim(reason)) > 0)))''',
    '''CREATE TABLE payment_allocations (${_id('id')},
      payment_id TEXT NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
      sale_transaction_id TEXT NOT NULL REFERENCES sale_transactions(id) ON DELETE RESTRICT,
      ${_positive('amount_rupiah')}, UNIQUE(payment_id, sale_transaction_id))''',
    '''CREATE TABLE sale_transaction_reversals (${_id('id')},
      sale_transaction_id TEXT NOT NULL UNIQUE REFERENCES sale_transactions(id) ON DELETE RESTRICT,
      operation_key TEXT NOT NULL UNIQUE, ${_amount('created_at')},
      reason TEXT NOT NULL CHECK(length(trim(reason)) > 0))''',
    '''CREATE TABLE stock_history (${_id('id')},
      product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      stock_batch_id TEXT REFERENCES stock_batches(id) ON DELETE RESTRICT,
      sale_transaction_id TEXT REFERENCES sale_transactions(id) ON DELETE RESTRICT,
      stock_receipt_id TEXT REFERENCES stock_receipts(id) ON DELETE RESTRICT,
      sale_transaction_reversal_id TEXT REFERENCES sale_transaction_reversals(id) ON DELETE RESTRICT,
      reverses_history_id TEXT UNIQUE REFERENCES stock_history(id) ON DELETE RESTRICT,
      kind TEXT NOT NULL CHECK(kind IN ('initial','receipt','sale','adjustment','waste','reversal')),
      quantity_delta INTEGER NOT NULL CHECK(typeof(quantity_delta) = 'integer'),
      value_delta_micros INTEGER NOT NULL CHECK(typeof(value_delta_micros) = 'integer'),
      ${_amount('created_at')}, reason TEXT NOT NULL,
      CHECK(quantity_delta != 0 OR value_delta_micros != 0))''',
    '''CREATE TABLE price_history (${_id('id')},
      product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      ${_amount('before_rupiah')}, ${_amount('after_rupiah')},
      ${_amount('created_at')}, reason TEXT NOT NULL)''',
    '''CREATE TABLE store_settings (
      id INTEGER PRIMARY KEY CHECK(id = 1), name TEXT,
      time_zone TEXT NOT NULL DEFAULT 'Asia/Jakarta', address TEXT, contact_number TEXT,
      logo_path TEXT, receipt_footer TEXT,
      ${_flag('backup_enabled', 0)}, ${_flag('notifications_enabled', 0)})''',
    'INSERT INTO store_settings(id) VALUES(1)',
    '''CREATE TABLE management_credentials (
      id INTEGER PRIMARY KEY CHECK(id = 1), pin_verifier BLOB NOT NULL,
      salt BLOB NOT NULL, kdf_name TEXT NOT NULL, kdf_parameters TEXT NOT NULL,
      recovery_verifier BLOB NOT NULL, ${_amount('failed_attempts', initial: 0)},
      ${_amount('blocked_until', initial: 0)})''',
    '''CREATE TABLE installation_metadata (
      ${_id('id')}, ${_amount('created_at')})''',
    '''CREATE TABLE legal_acceptances (${_id('id')},
      installation_id TEXT NOT NULL REFERENCES installation_metadata(id) ON DELETE RESTRICT,
      document_version TEXT NOT NULL, ${_amount('accepted_at')})''',
    '''CREATE TABLE audit_log (${_id('id')},
      installation_id TEXT NOT NULL REFERENCES installation_metadata(id) ON DELETE RESTRICT,
      mode TEXT NOT NULL CHECK(mode IN ('cashier','management','system')),
      action TEXT NOT NULL, entity_id TEXT, ${_amount('created_at')})''',
    // Immutable facts are corrected by new reversal records. Migration can
    // explicitly replace these triggers if a future schema needs redaction.
    for (final table in const [
      'sale_transactions',
      'sale_transaction_items',
      'sale_batch_allocations',
      'stock_receipts',
      'stock_receipt_items',
      'payments',
      'payment_allocations',
      'sale_transaction_reversals',
      'stock_history',
      'price_history',
      'audit_log',
      'legal_acceptances',
    ]) ...[
      "CREATE TRIGGER ${table}_no_update BEFORE UPDATE ON $table BEGIN SELECT RAISE(ABORT, 'immutable_fact'); END",
      "CREATE TRIGGER ${table}_no_delete BEFORE DELETE ON $table BEGIN SELECT RAISE(ABORT, 'immutable_fact'); END",
    ],
  ];

  static const _indexes = [
    'CREATE INDEX products_catalog ON products(is_deleted, normalized_name COLLATE BINARY, id COLLATE BINARY)',
    'CREATE INDEX products_category ON products(category_id)',
    'CREATE INDEX product_aliases_lookup ON product_aliases(normalized_alias, product_id)',
    'CREATE INDEX sale_transactions_history ON sale_transactions(created_at DESC, id COLLATE BINARY DESC)',
    'CREATE INDEX sale_transactions_customer_history ON sale_transactions(customer_id, created_at DESC, id COLLATE BINARY DESC)',
    'CREATE INDEX sale_transaction_items_parent ON sale_transaction_items(sale_transaction_id, id)',
    'CREATE INDEX sale_transaction_items_product ON sale_transaction_items(product_id)',
    'CREATE INDEX stock_receipts_supplier ON stock_receipts(supplier_id)',
    'CREATE INDEX stock_receipt_items_receipt ON stock_receipt_items(stock_receipt_id)',
    'CREATE INDEX stock_receipt_items_product ON stock_receipt_items(product_id)',
    'CREATE INDEX stock_batches_fefo ON stock_batches(product_id, expiry_date, received_at, id)',
    'CREATE INDEX sale_batch_allocations_batch ON sale_batch_allocations(stock_batch_id)',
    'CREATE INDEX payments_customer ON payments(customer_id, created_at DESC, id DESC)',
    'CREATE INDEX payment_allocations_sale_transaction ON payment_allocations(sale_transaction_id)',
    'CREATE INDEX stock_history_product ON stock_history(product_id, created_at DESC, id DESC)',
    'CREATE INDEX stock_history_batch ON stock_history(stock_batch_id)',
    'CREATE INDEX stock_history_sale_transaction ON stock_history(sale_transaction_id)',
    'CREATE INDEX stock_history_receipt ON stock_history(stock_receipt_id)',
    'CREATE INDEX stock_history_reversal ON stock_history(sale_transaction_reversal_id)',
    'CREATE INDEX price_history_product ON price_history(product_id, created_at DESC, id DESC)',
    'CREATE INDEX draft_items_product ON cart_draft_items(product_id)',
    'CREATE INDEX legal_acceptances_installation ON legal_acceptances(installation_id)',
    'CREATE INDEX audit_log_installation ON audit_log(installation_id, created_at DESC, id DESC)',
  ];

  /// M2 only adds columns/tables. Existing IDs, snapshots and facts survive.
  static const _management = [
    "ALTER TABLE products ADD COLUMN stock_revision INTEGER NOT NULL DEFAULT 0 CHECK(typeof(stock_revision)='integer' AND stock_revision>=0)",
    "ALTER TABLE management_credentials ADD COLUMN last_attempt_at INTEGER NOT NULL DEFAULT 0 CHECK(last_attempt_at>=0)",
    '''CREATE TABLE inventory_operations (
      id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
      operation_key TEXT NOT NULL UNIQUE,
      payload_hash TEXT NOT NULL,
      kind TEXT NOT NULL CHECK(kind IN ('initial','receipt','adjustment','waste','reversal')),
      product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      stock_receipt_id TEXT REFERENCES stock_receipts(id) ON DELETE RESTRICT,
      reverses_operation_id TEXT UNIQUE REFERENCES inventory_operations(id) ON DELETE RESTRICT,
      before_quantity INTEGER NOT NULL CHECK(typeof(before_quantity)='integer' AND before_quantity>=0),
      before_value_micros INTEGER NOT NULL CHECK(typeof(before_value_micros)='integer' AND before_value_micros>=0),
      stock_revision_after INTEGER NOT NULL CHECK(stock_revision_after>0),
      created_at INTEGER NOT NULL CHECK(created_at>=0))''',
    'ALTER TABLE stock_history ADD COLUMN inventory_operation_id TEXT REFERENCES inventory_operations(id) ON DELETE RESTRICT',
    'ALTER TABLE price_history ADD COLUMN product_revision_after INTEGER',
    'CREATE INDEX inventory_operations_product ON inventory_operations(product_id, stock_revision_after DESC)',
    'CREATE INDEX inventory_operations_receipt ON inventory_operations(stock_receipt_id)',
    'CREATE INDEX stock_history_operation ON stock_history(inventory_operation_id)',
    'CREATE INDEX stock_batches_list ON stock_batches(product_id,received_at DESC,id DESC)',
    'CREATE INDEX categories_list ON categories(is_deleted,normalized_name,id)',
    'CREATE INDEX suppliers_list ON suppliers(is_deleted,normalized_name,id)',
    "CREATE TRIGGER inventory_operations_no_update BEFORE UPDATE ON inventory_operations BEGIN SELECT RAISE(ABORT, 'immutable_fact'); END",
    "CREATE TRIGGER inventory_operations_no_delete BEFORE DELETE ON inventory_operations BEGIN SELECT RAISE(ABORT, 'immutable_fact'); END",
  ];
}
