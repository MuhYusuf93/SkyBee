/// Drafts retain the chosen external amount, while completed sales carry the
/// immutable manual review and optional rounding separately from tender.
final checkoutSettlementSchema = [
  '''CREATE TABLE cash_rounding_settings(
    currency_code TEXT NOT NULL PRIMARY KEY CHECK(currency_code IN ('IDR','USD','MYR','EUR')),
    step_minor INTEGER NOT NULL CHECK(typeof(step_minor)='integer' AND
      (step_minor=0 OR (currency_code='IDR' AND step_minor IN(100,500,1000)) OR
      (currency_code<>'IDR' AND step_minor IN(5,10,25,50)))),
    revision INTEGER NOT NULL CHECK(typeof(revision)='integer' AND revision>0))''',
  "ALTER TABLE cart_drafts ADD COLUMN noncash_method TEXT CHECK(noncash_method IN ('qris','transfer'))",
  '''ALTER TABLE cart_drafts ADD COLUMN noncash_minor INTEGER CHECK(
    (noncash_method IS NULL AND noncash_minor IS NULL) OR
    (noncash_method IS NOT NULL AND typeof(noncash_minor)='integer' AND noncash_minor>0))''',
  '''ALTER TABLE sale_transaction_items ADD COLUMN rounding_minor INTEGER NOT NULL DEFAULT 0
    CHECK(typeof(rounding_minor)='integer' AND rounding_minor>=0)''',
  '''CREATE TABLE checkout_manual_payments(sale_transaction_id TEXT PRIMARY KEY NOT NULL
    REFERENCES sale_transactions(id) ON DELETE RESTRICT,
    method TEXT NOT NULL CHECK(method IN ('qris','transfer')),
    amount_minor INTEGER NOT NULL CHECK(typeof(amount_minor)='integer' AND amount_minor>0),
    confirmed_at INTEGER NOT NULL CHECK(typeof(confirmed_at)='integer' AND confirmed_at>=0))''',
  '''CREATE TABLE checkout_rounding(sale_transaction_id TEXT PRIMARY KEY NOT NULL
    REFERENCES sale_transactions(id) ON DELETE RESTRICT,
    subtotal_minor INTEGER NOT NULL CHECK(typeof(subtotal_minor)='integer' AND subtotal_minor>0),
    discount_minor INTEGER NOT NULL CHECK(typeof(discount_minor)='integer' AND discount_minor>0),
    step_minor INTEGER NOT NULL CHECK(typeof(step_minor)='integer' AND step_minor>discount_minor),
    CHECK(discount_minor<=subtotal_minor))''',
  '''ALTER TABLE checkout_tenders ADD COLUMN noncash_minor INTEGER NOT NULL DEFAULT 0
    CHECK(typeof(noncash_minor)='integer' AND noncash_minor>=0)''',
  'DROP TRIGGER checkout_tenders_insert_guard',
  '''CREATE TRIGGER checkout_tenders_insert_guard BEFORE INSERT ON checkout_tenders WHEN NOT EXISTS(
    SELECT 1 FROM sale_transactions s WHERE s.id=NEW.sale_transaction_id
    AND NEW.noncash_minor=COALESCE((SELECT amount_minor FROM checkout_manual_payments m
      WHERE m.sale_transaction_id=s.id),0)
    AND NEW.applied_minor=MIN(NEW.received_minor,s.total_rupiah-NEW.noncash_minor)
    AND NEW.debt_minor=s.total_rupiah-NEW.applied_minor-NEW.noncash_minor)
    BEGIN SELECT RAISE(ABORT,'invalid_tender'); END''',
  for (final table in ['checkout_manual_payments', 'checkout_rounding'])
    for (final action in ['update', 'delete'])
      "CREATE TRIGGER ${table}_no_$action BEFORE ${action.toUpperCase()} ON $table BEGIN SELECT RAISE(ABORT,'immutable_fact'); END",
];
