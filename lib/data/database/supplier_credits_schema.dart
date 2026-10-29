import 'supplier_finance_schema.dart';

/// Supplier approval, invoice allocation and actual refund are separate facts.
/// The bounded credit-event ledger serializes their available balance without
/// updating old approvals, payments, stock or sale HPP snapshots.
final supplierCreditsSchema = <String>[
  '''CREATE TABLE supplier_credits(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    return_id TEXT NOT NULL REFERENCES supplier_returns(id) ON DELETE RESTRICT,
    supplier_id TEXT NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    approved_invoice_id TEXT REFERENCES supplier_invoices(id) ON DELETE RESTRICT,
    approved_invoice_revision INTEGER CHECK(approved_invoice_revision IS NULL OR approved_invoice_revision>=0),
    approved_invoice_remaining INTEGER CHECK(approved_invoice_remaining IS NULL OR approved_invoice_remaining BETWEEN 0 AND 9000000000000),
    amount_minor INTEGER NOT NULL CHECK(typeof(amount_minor)='integer' AND amount_minor BETWEEN 1 AND 9000000000000),
    currency_code TEXT NOT NULL,currency_scale INTEGER NOT NULL,approved_date TEXT NOT NULL,
    reason TEXT NOT NULL CHECK(length(trim(reason)) BETWEEN 1 AND 300),
    operation_key TEXT NOT NULL UNIQUE,payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
    actor_role TEXT NOT NULL CHECK(actor_role='owner'),created_at INTEGER NOT NULL,
    CHECK((approved_invoice_id IS NULL AND approved_invoice_revision IS NULL AND approved_invoice_remaining IS NULL) OR
      (approved_invoice_id IS NOT NULL AND approved_invoice_revision IS NOT NULL AND approved_invoice_remaining IS NOT NULL)))''',
  'CREATE INDEX supplier_credits_return ON supplier_credits(return_id,id)',
  'CREATE INDEX supplier_credits_list ON supplier_credits(supplier_id,approved_date DESC,id COLLATE BINARY DESC)',
  '''CREATE TABLE supplier_credit_reversals(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    credit_id TEXT NOT NULL UNIQUE REFERENCES supplier_credits(id) ON DELETE RESTRICT,
    reason TEXT NOT NULL CHECK(length(trim(reason)) BETWEEN 1 AND 300),event_date TEXT NOT NULL,
    operation_key TEXT NOT NULL UNIQUE,payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
    actor_role TEXT NOT NULL CHECK(actor_role='owner'),created_at INTEGER NOT NULL)''',
  '''CREATE TABLE supplier_credit_allocations(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    credit_id TEXT NOT NULL REFERENCES supplier_credits(id) ON DELETE RESTRICT,
    invoice_id TEXT NOT NULL REFERENCES supplier_invoices(id) ON DELETE RESTRICT,
    invoice_revision INTEGER NOT NULL CHECK(invoice_revision>0),
    origin TEXT NOT NULL CHECK(origin IN ('initial','manual')),
    amount_minor INTEGER NOT NULL CHECK(typeof(amount_minor)='integer' AND amount_minor BETWEEN 1 AND 9000000000000),
    currency_code TEXT NOT NULL,currency_scale INTEGER NOT NULL,event_date TEXT NOT NULL,
    operation_key TEXT NOT NULL UNIQUE,payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
    actor_role TEXT NOT NULL CHECK(actor_role='owner'),created_at INTEGER NOT NULL,UNIQUE(invoice_id,invoice_revision))''',
  'CREATE INDEX supplier_credit_allocations_credit ON supplier_credit_allocations(credit_id,created_at DESC,id COLLATE BINARY DESC)',
  "CREATE UNIQUE INDEX supplier_credit_initial_once ON supplier_credit_allocations(credit_id) WHERE origin='initial'",
  'CREATE INDEX supplier_credit_invoice_snapshot ON supplier_credits(approved_invoice_id,approved_invoice_revision,id)',
  '''CREATE TABLE supplier_credit_allocation_reversals(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    allocation_id TEXT NOT NULL UNIQUE REFERENCES supplier_credit_allocations(id) ON DELETE RESTRICT,
    credit_id TEXT NOT NULL REFERENCES supplier_credits(id) ON DELETE RESTRICT,
    invoice_id TEXT NOT NULL REFERENCES supplier_invoices(id) ON DELETE RESTRICT,
    invoice_revision INTEGER NOT NULL CHECK(invoice_revision>0),
    amount_minor INTEGER NOT NULL CHECK(amount_minor>0),currency_code TEXT NOT NULL,currency_scale INTEGER NOT NULL,
    reason TEXT NOT NULL CHECK(length(trim(reason)) BETWEEN 1 AND 300),event_date TEXT NOT NULL,
    operation_key TEXT NOT NULL UNIQUE,payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
    actor_role TEXT NOT NULL CHECK(actor_role='owner'),created_at INTEGER NOT NULL,UNIQUE(invoice_id,invoice_revision))''',
  for (final reversal in [false, true])
    '''CREATE TABLE supplier_credit_refund${reversal ? '_reversals' : 's'}(
      id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
      ${reversal ? 'refund_id TEXT NOT NULL UNIQUE REFERENCES supplier_credit_refunds(id) ON DELETE RESTRICT,' : ''}
      credit_id TEXT NOT NULL REFERENCES supplier_credits(id) ON DELETE RESTRICT,
      amount_minor INTEGER NOT NULL CHECK(typeof(amount_minor)='integer' AND amount_minor BETWEEN 1 AND 9000000000000),
      currency_code TEXT NOT NULL,currency_scale INTEGER NOT NULL,event_date TEXT NOT NULL,
      ${reversal ? "reason TEXT NOT NULL CHECK(length(trim(reason)) BETWEEN 1 AND 300)," : "destination TEXT NOT NULL CHECK(destination IN ('drawer','bank','owner_funds')),reference TEXT CHECK(reference IS NULL OR length(reference) BETWEEN 1 AND 80),note TEXT CHECK(note IS NULL OR length(note) BETWEEN 1 AND 300),"}
      tracked_cash INTEGER NOT NULL CHECK(tracked_cash IN (0,1)),
      drawer_session_id TEXT REFERENCES cash_drawer_sessions(id) ON DELETE RESTRICT,${reversal ? 'out' : 'in'}_counts_json TEXT,
      operation_key TEXT NOT NULL UNIQUE,payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
      actor_role TEXT NOT NULL CHECK(actor_role='owner'),created_at INTEGER NOT NULL,
      CHECK((tracked_cash=1 AND drawer_session_id IS NOT NULL AND ${reversal ? 'out' : 'in'}_counts_json IS NOT NULL
        ${reversal ? '' : "AND destination='drawer'"}) OR
        (tracked_cash=0 AND drawer_session_id IS NULL AND ${reversal ? 'out' : 'in'}_counts_json IS NULL)))''',
  'CREATE INDEX supplier_credit_refunds_credit ON supplier_credit_refunds(credit_id,created_at DESC,id COLLATE BINARY DESC)',
  '''CREATE TABLE supplier_credit_events(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    credit_id TEXT NOT NULL REFERENCES supplier_credits(id) ON DELETE RESTRICT,
    sequence INTEGER NOT NULL CHECK(sequence>0),
    available_before INTEGER NOT NULL CHECK(available_before BETWEEN 0 AND 9000000000000),
    available_after INTEGER NOT NULL CHECK(available_after BETWEEN 0 AND 9000000000000),
    amount_delta INTEGER NOT NULL CHECK(amount_delta<>0),
    allocation_id TEXT UNIQUE REFERENCES supplier_credit_allocations(id) ON DELETE RESTRICT,
    allocation_reversal_id TEXT UNIQUE REFERENCES supplier_credit_allocation_reversals(id) ON DELETE RESTRICT,
    refund_id TEXT UNIQUE REFERENCES supplier_credit_refunds(id) ON DELETE RESTRICT,
    refund_reversal_id TEXT UNIQUE REFERENCES supplier_credit_refund_reversals(id) ON DELETE RESTRICT,
    credit_reversal_id TEXT UNIQUE REFERENCES supplier_credit_reversals(id) ON DELETE RESTRICT,
    event_date TEXT NOT NULL,created_at INTEGER NOT NULL,UNIQUE(credit_id,sequence),
    CHECK(available_after=available_before+amount_delta),
    CHECK((allocation_id IS NOT NULL)+(allocation_reversal_id IS NOT NULL)+(refund_id IS NOT NULL)+
      (refund_reversal_id IS NOT NULL)+(credit_reversal_id IS NOT NULL)=1),
    CHECK((amount_delta<0 AND (allocation_id IS NOT NULL OR refund_id IS NOT NULL OR credit_reversal_id IS NOT NULL)) OR
      (amount_delta>0 AND (allocation_reversal_id IS NOT NULL OR refund_reversal_id IS NOT NULL))))''',
  '''CREATE TRIGGER supplier_credit_single_active BEFORE INSERT ON supplier_credits WHEN
    EXISTS(SELECT 1 FROM supplier_return_reversals v WHERE v.return_id=NEW.return_id) OR
    EXISTS(SELECT 1 FROM supplier_credits c WHERE c.return_id=NEW.return_id AND
      NOT EXISTS(SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=c.id))
    BEGIN SELECT RAISE(ABORT,'supplier_credit_already_approved'); END''',
  for (final table in [
    'supplier_credits',
    'supplier_credit_reversals',
    'supplier_credit_allocations',
    'supplier_credit_allocation_reversals',
    'supplier_credit_refunds',
    'supplier_credit_refund_reversals',
    'supplier_credit_events',
  ])
    for (final action in ['UPDATE', 'DELETE'])
      '''CREATE TRIGGER ${table}_${action.toLowerCase()} BEFORE $action ON $table
      BEGIN SELECT RAISE(ABORT,'immutable_supplier_credit'); END''',
  'DROP TRIGGER supplier_invoice_update',
  '''CREATE TRIGGER supplier_invoice_update BEFORE UPDATE ON supplier_invoices WHEN
    OLD.status<>'posted' OR NEW.revision<>OLD.revision+1 OR
    ${supplierInvoiceImmutableColumns.map((c) => 'NEW.$c IS NOT OLD.$c').join(' OR ')} OR
    (SELECT COUNT(*) FROM (
      SELECT 1 FROM supplier_payments p WHERE p.invoice_id=OLD.id AND p.invoice_revision=NEW.revision
      UNION ALL SELECT 1 FROM supplier_payment_reversals r WHERE r.invoice_id=OLD.id AND r.invoice_revision=NEW.revision
      UNION ALL SELECT 1 FROM supplier_due_amendments a WHERE a.invoice_id=OLD.id AND a.invoice_revision=NEW.revision
      UNION ALL SELECT 1 FROM supplier_invoice_voids v WHERE v.invoice_id=OLD.id AND v.invoice_revision=NEW.revision
      UNION ALL SELECT 1 FROM supplier_credit_allocations a WHERE a.invoice_id=OLD.id AND a.invoice_revision=NEW.revision
      UNION ALL SELECT 1 FROM supplier_credit_allocation_reversals v WHERE v.invoice_id=OLD.id AND v.invoice_revision=NEW.revision))<>1 OR
    (NEW.status='voided' AND NOT EXISTS(SELECT 1 FROM supplier_invoice_voids v WHERE v.invoice_id=OLD.id AND v.invoice_revision=NEW.revision))
    BEGIN SELECT RAISE(ABORT,'immutable_supplier_invoice'); END''',
];
