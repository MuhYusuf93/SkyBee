/// Additive supplier facts. Migration never converts old receipts to invoices
/// or guesses whether money has been paid. Corrections retain original facts.
final supplierFinanceSchema = <String>[
  '''CREATE TABLE supplier_invoices(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    receipt_id TEXT NOT NULL REFERENCES stock_receipts(id) ON DELETE RESTRICT,
    supplier_id TEXT NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    supplier_name_snapshot TEXT NOT NULL,
    supplier_terms_revision INTEGER NOT NULL CHECK(supplier_terms_revision>=0),
    credit_allowed_snapshot INTEGER NOT NULL CHECK(credit_allowed_snapshot IN (0,1)),
    operation_key TEXT NOT NULL UNIQUE,payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
    status TEXT NOT NULL CHECK(status IN ('posted','voided')),
    revision INTEGER NOT NULL DEFAULT 0 CHECK(typeof(revision)='integer' AND revision>=0),
    invoice_date TEXT NOT NULL,invoice_number TEXT CHECK(invoice_number IS NULL OR length(invoice_number) BETWEEN 1 AND 80),
    terms TEXT NOT NULL CHECK(terms IN ('cash','credit')),due_date TEXT,
    total_minor INTEGER NOT NULL CHECK(typeof(total_minor)='integer' AND total_minor BETWEEN 0 AND 9000000000000),
    currency_code TEXT NOT NULL,currency_scale INTEGER NOT NULL,
    source_mode TEXT NOT NULL CHECK(source_mode IN ('receipt_exact','historical_unallocated')),
    source_item_count INTEGER NOT NULL CHECK(source_item_count>0),
    source_cost_complete INTEGER NOT NULL CHECK(source_cost_complete IN (0,1)),
    source_total_micros INTEGER CHECK(source_total_micros IS NULL OR (typeof(source_total_micros)='integer' AND source_total_micros>=0)),
    source_hash TEXT NOT NULL CHECK(length(source_hash)=64),
    reconciliation_reason TEXT,
    reported_initial_minor INTEGER NOT NULL DEFAULT 0 CHECK(typeof(reported_initial_minor)='integer' AND reported_initial_minor BETWEEN 0 AND total_minor),
    actor_role TEXT NOT NULL CHECK(actor_role IN ('owner','warehouse')),created_at INTEGER NOT NULL,
    CHECK((terms='credit' AND due_date IS NOT NULL AND due_date>=invoice_date) OR (terms='cash' AND due_date IS NULL)),
    CHECK(terms<>'credit' OR credit_allowed_snapshot=1),
    CHECK(source_mode<>'historical_unallocated' OR (actor_role='owner' AND reconciliation_reason IS NOT NULL AND length(trim(reconciliation_reason)) BETWEEN 1 AND 300)))''',
  "CREATE UNIQUE INDEX supplier_invoice_active_receipt ON supplier_invoices(receipt_id) WHERE status='posted'",
  'CREATE INDEX supplier_invoice_cursor ON supplier_invoices(supplier_id,invoice_date DESC,id COLLATE BINARY DESC)',
  'CREATE INDEX stock_receipts_supplier_cursor ON stock_receipts(supplier_id,created_at DESC,id COLLATE BINARY DESC)',
  '''CREATE TABLE supplier_payments(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    invoice_id TEXT NOT NULL REFERENCES supplier_invoices(id) ON DELETE RESTRICT,
    invoice_revision INTEGER NOT NULL CHECK(invoice_revision>0),
    operation_key TEXT NOT NULL UNIQUE,payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
    amount_minor INTEGER NOT NULL CHECK(typeof(amount_minor)='integer' AND amount_minor BETWEEN 1 AND 9000000000000),
    currency_code TEXT NOT NULL,currency_scale INTEGER NOT NULL,paid_date TEXT NOT NULL,
    source TEXT NOT NULL CHECK(source IN ('drawer','bank','owner_funds')),
    tracked_cash INTEGER NOT NULL CHECK(tracked_cash IN (0,1)),
    drawer_session_id TEXT REFERENCES cash_drawer_sessions(id) ON DELETE RESTRICT,out_counts_json TEXT,
    reference TEXT CHECK(reference IS NULL OR length(reference) BETWEEN 1 AND 80),
    note TEXT CHECK(note IS NULL OR length(note) BETWEEN 1 AND 300),
    actor_role TEXT NOT NULL CHECK(actor_role='owner'),created_at INTEGER NOT NULL,
    UNIQUE(invoice_id,invoice_revision),
    CHECK((tracked_cash=1 AND source='drawer' AND drawer_session_id IS NOT NULL AND out_counts_json IS NOT NULL) OR
      (tracked_cash=0 AND drawer_session_id IS NULL AND out_counts_json IS NULL)))''',
  'CREATE INDEX supplier_payments_invoice ON supplier_payments(invoice_id,created_at DESC,id COLLATE BINARY DESC)',
  '''CREATE TABLE supplier_payment_reversals(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    payment_id TEXT NOT NULL UNIQUE REFERENCES supplier_payments(id) ON DELETE RESTRICT,
    invoice_id TEXT NOT NULL REFERENCES supplier_invoices(id) ON DELETE RESTRICT,invoice_revision INTEGER NOT NULL CHECK(invoice_revision>0),
    operation_key TEXT NOT NULL UNIQUE,payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
    amount_minor INTEGER NOT NULL CHECK(amount_minor>0),currency_code TEXT NOT NULL,currency_scale INTEGER NOT NULL,
    tracked_cash INTEGER NOT NULL CHECK(tracked_cash IN (0,1)),
    drawer_session_id TEXT REFERENCES cash_drawer_sessions(id) ON DELETE RESTRICT,in_counts_json TEXT,
    reason TEXT NOT NULL CHECK(length(trim(reason)) BETWEEN 1 AND 300),
    actor_role TEXT NOT NULL CHECK(actor_role='owner'),created_at INTEGER NOT NULL,
    UNIQUE(invoice_id,invoice_revision),
    CHECK((tracked_cash=1 AND drawer_session_id IS NOT NULL AND in_counts_json IS NOT NULL) OR
      (tracked_cash=0 AND drawer_session_id IS NULL AND in_counts_json IS NULL)))''',
  '''CREATE TABLE supplier_due_amendments(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),invoice_id TEXT NOT NULL REFERENCES supplier_invoices(id) ON DELETE RESTRICT,
    invoice_revision INTEGER NOT NULL CHECK(invoice_revision>0),operation_key TEXT NOT NULL UNIQUE,payload_hash TEXT NOT NULL,
    due_date TEXT NOT NULL,reason TEXT NOT NULL CHECK(length(trim(reason)) BETWEEN 1 AND 300),
    actor_role TEXT NOT NULL CHECK(actor_role='owner'),created_at INTEGER NOT NULL,UNIQUE(invoice_id,invoice_revision))''',
  '''CREATE TABLE supplier_invoice_voids(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),invoice_id TEXT NOT NULL UNIQUE REFERENCES supplier_invoices(id) ON DELETE RESTRICT,
    invoice_revision INTEGER NOT NULL CHECK(invoice_revision>0),operation_key TEXT NOT NULL UNIQUE,payload_hash TEXT NOT NULL,
    reason TEXT NOT NULL CHECK(length(trim(reason)) BETWEEN 1 AND 300),
    actor_role TEXT NOT NULL CHECK(actor_role='owner'),created_at INTEGER NOT NULL,UNIQUE(invoice_id,invoice_revision))''',
  '''CREATE TABLE receipt_invoice_confirmations(
    draft_id TEXT PRIMARY KEY NOT NULL REFERENCES receipt_drafts(id) ON DELETE RESTRICT,
    receipt_id TEXT NOT NULL UNIQUE REFERENCES stock_receipts(id) ON DELETE RESTRICT,
    invoice_id TEXT NOT NULL UNIQUE REFERENCES supplier_invoices(id) ON DELETE RESTRICT,
    payment_id TEXT UNIQUE REFERENCES supplier_payments(id) ON DELETE RESTRICT,
    request_hash TEXT NOT NULL CHECK(length(request_hash)=64),
    billing_json TEXT NOT NULL CHECK(length(billing_json)<=4000),
    payment_json TEXT CHECK(payment_json IS NULL OR length(payment_json)<=4000))''',
  '''CREATE TRIGGER supplier_invoice_update BEFORE UPDATE ON supplier_invoices WHEN
    OLD.status<>'posted' OR NEW.revision<>OLD.revision+1 OR
    ${supplierInvoiceImmutableColumns.map((c) => 'NEW.$c IS NOT OLD.$c').join(' OR ')} OR
    (SELECT COUNT(*) FROM (
      SELECT 1 FROM supplier_payments p WHERE p.invoice_id=OLD.id AND p.invoice_revision=NEW.revision
      UNION ALL SELECT 1 FROM supplier_payment_reversals r WHERE r.invoice_id=OLD.id AND r.invoice_revision=NEW.revision
      UNION ALL SELECT 1 FROM supplier_due_amendments a WHERE a.invoice_id=OLD.id AND a.invoice_revision=NEW.revision
      UNION ALL SELECT 1 FROM supplier_invoice_voids v WHERE v.invoice_id=OLD.id AND v.invoice_revision=NEW.revision))<>1 OR
    (NEW.status='voided' AND NOT EXISTS(SELECT 1 FROM supplier_invoice_voids v WHERE v.invoice_id=OLD.id AND v.invoice_revision=NEW.revision))
    BEGIN SELECT RAISE(ABORT,'immutable_supplier_invoice'); END''',
  '''CREATE TRIGGER supplier_invoice_delete BEFORE DELETE ON supplier_invoices
    BEGIN SELECT RAISE(ABORT,'retain_supplier_invoice'); END''',
  for (final table in [
    'supplier_payments',
    'supplier_payment_reversals',
    'supplier_due_amendments',
    'supplier_invoice_voids',
    'receipt_invoice_confirmations',
  ])
    for (final action in ['UPDATE', 'DELETE'])
      '''CREATE TRIGGER ${table}_${action.toLowerCase()} BEFORE $action ON $table
        BEGIN SELECT RAISE(ABORT,'immutable_supplier_fact'); END''',
];
const supplierInvoiceImmutableColumns = [
  'id',
  'receipt_id',
  'supplier_id',
  'supplier_name_snapshot',
  'supplier_terms_revision',
  'credit_allowed_snapshot',
  'operation_key',
  'payload_hash',
  'invoice_date',
  'invoice_number',
  'terms',
  'due_date',
  'total_minor',
  'currency_code',
  'currency_scale',
  'source_mode',
  'source_item_count',
  'source_cost_complete',
  'source_total_micros',
  'source_hash',
  'reconciliation_reason',
  'reported_initial_minor',
  'actor_role',
  'created_at',
];
