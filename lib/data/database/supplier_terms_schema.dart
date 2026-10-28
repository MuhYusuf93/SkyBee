/// No backfill of receipts or supplier balances. Absence of a profile means
/// credit is not allowed, for both new and historical suppliers.
const supplierTermsSchema = <String>[
  '''CREATE TABLE supplier_terms(
    supplier_id TEXT PRIMARY KEY NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    allows_credit INTEGER NOT NULL CHECK(allows_credit IN (0,1)),
    revision INTEGER NOT NULL CHECK(typeof(revision)='integer' AND revision>0),
    updated_at INTEGER NOT NULL CHECK(typeof(updated_at)='integer'))''',
  '''CREATE TABLE supplier_terms_events(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    supplier_id TEXT NOT NULL REFERENCES supplier_terms(supplier_id) ON DELETE RESTRICT,
    revision INTEGER NOT NULL CHECK(typeof(revision)='integer' AND revision>0),
    before_allowed INTEGER NOT NULL CHECK(before_allowed IN (0,1)),
    after_allowed INTEGER NOT NULL CHECK(after_allowed IN (0,1)),
    actor_role TEXT NOT NULL CHECK(actor_role='owner'),
    created_at INTEGER NOT NULL CHECK(typeof(created_at)='integer'),
    UNIQUE(supplier_id,revision))''',
  '''CREATE TRIGGER supplier_terms_history_update BEFORE UPDATE ON supplier_terms_events
    BEGIN SELECT RAISE(ABORT,'immutable_supplier_terms_history'); END''',
  '''CREATE TRIGGER supplier_terms_history_delete BEFORE DELETE ON supplier_terms_events
    BEGIN SELECT RAISE(ABORT,'immutable_supplier_terms_history'); END''',
  '''CREATE TRIGGER supplier_terms_retain BEFORE DELETE ON supplier_terms
    BEGIN SELECT RAISE(ABORT,'retain_supplier_terms'); END''',
];
