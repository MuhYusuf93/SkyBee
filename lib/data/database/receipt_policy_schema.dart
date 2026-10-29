/// A receipt requirement is captured in the sale commit. Queue rows are device
/// state and are removed on restore; immutable confirmation witnesses must not
/// reference them with a foreign key that prevents safe queue sanitization.
const receiptPolicySchema = <String>[
  '''CREATE TABLE receipt_print_policy(id INTEGER PRIMARY KEY CHECK(id=1),
    required INTEGER NOT NULL DEFAULT 0 CHECK(required IN(0,1)),
    revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision)='integer' AND revision>=1),
    updated_at INTEGER NOT NULL DEFAULT 0 CHECK(typeof(updated_at)='integer' AND updated_at>=0))''',
  'INSERT INTO receipt_print_policy(id) VALUES(1)',
  '''CREATE TABLE sale_receipt_requirements(sale_transaction_id TEXT PRIMARY KEY NOT NULL
    REFERENCES sale_transactions(id) ON DELETE RESTRICT,
    policy_revision INTEGER NOT NULL CHECK(typeof(policy_revision)='integer' AND policy_revision>=1),
    created_at INTEGER NOT NULL CHECK(typeof(created_at)='integer' AND created_at>=0))''',
  '''CREATE TABLE receipt_print_gate(id INTEGER PRIMARY KEY CHECK(id=1),
    pending_sale TEXT REFERENCES sale_receipt_requirements(sale_transaction_id) ON DELETE RESTRICT)''',
  'INSERT INTO receipt_print_gate(id) VALUES(1)',
  '''CREATE TABLE receipt_print_resolutions(sale_transaction_id TEXT PRIMARY KEY NOT NULL
    REFERENCES sale_receipt_requirements(sale_transaction_id) ON DELETE RESTRICT,
    operation_key TEXT NOT NULL UNIQUE CHECK(length(operation_key) BETWEEN 1 AND 200),
    payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
    kind TEXT NOT NULL CHECK(kind IN('operator_confirmation','owner_exception')),
    actor TEXT NOT NULL CHECK(actor IN('operator','owner')),
    job_id TEXT,job_status TEXT,reason TEXT,
    created_at INTEGER NOT NULL CHECK(typeof(created_at)='integer' AND created_at>=0),
    CHECK((kind='operator_confirmation' AND actor='operator' AND job_id IS NOT NULL AND length(job_id)=36
      AND job_status IS NOT NULL AND job_status IN('submitted','unknown') AND reason IS NULL) OR
      (kind='owner_exception' AND actor='owner' AND job_id IS NULL AND job_status IS NULL
      AND reason IS NOT NULL AND length(trim(reason)) BETWEEN 1 AND 1000)))''',
  '''CREATE INDEX print_jobs_sale_created ON print_jobs(
    sale_transaction_id,created_at DESC,id COLLATE BINARY DESC)''',
  '''CREATE TRIGGER receipt_requirement_insert BEFORE INSERT ON sale_receipt_requirements BEGIN
    SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM receipt_print_policy
      WHERE id=1 AND required=1 AND revision=NEW.policy_revision)
      OR NOT EXISTS(SELECT 1 FROM sale_transactions WHERE id=NEW.sale_transaction_id AND created_at=NEW.created_at)
      OR (SELECT pending_sale FROM receipt_print_gate WHERE id=1) IS NOT NULL
      THEN RAISE(ABORT,'invalid_receipt_requirement') END;
    END''',
  '''CREATE TRIGGER receipt_requirement_gate AFTER INSERT ON sale_receipt_requirements BEGIN
    UPDATE receipt_print_gate SET pending_sale=NEW.sale_transaction_id WHERE id=1;
    END''',
  '''CREATE TRIGGER receipt_resolution_insert BEFORE INSERT ON receipt_print_resolutions BEGIN
    SELECT CASE WHEN (SELECT pending_sale FROM receipt_print_gate WHERE id=1) IS NOT NEW.sale_transaction_id
      OR (NEW.kind='operator_confirmation' AND NOT EXISTS(SELECT 1 FROM print_jobs
        WHERE id=NEW.job_id AND sale_transaction_id=NEW.sale_transaction_id AND status=NEW.job_status
        AND (operation_key='first:'||NEW.sale_transaction_id OR operation_key='copy:'||NEW.job_id)))
      THEN RAISE(ABORT,'invalid_receipt_resolution') END;
    END''',
  '''CREATE TRIGGER receipt_resolution_gate AFTER INSERT ON receipt_print_resolutions BEGIN
    UPDATE receipt_print_gate SET pending_sale=NULL WHERE id=1 AND pending_sale=NEW.sale_transaction_id;
    END''',
  '''CREATE TRIGGER receipt_requirements_no_update BEFORE UPDATE ON sale_receipt_requirements
    BEGIN SELECT RAISE(ABORT,'immutable_receipt_requirement'); END''',
  '''CREATE TRIGGER receipt_requirements_no_delete BEFORE DELETE ON sale_receipt_requirements
    BEGIN SELECT RAISE(ABORT,'immutable_receipt_requirement'); END''',
  '''CREATE TRIGGER receipt_resolutions_no_update BEFORE UPDATE ON receipt_print_resolutions
    BEGIN SELECT RAISE(ABORT,'immutable_receipt_resolution'); END''',
  '''CREATE TRIGGER receipt_resolutions_no_delete BEFORE DELETE ON receipt_print_resolutions
    BEGIN SELECT RAISE(ABORT,'immutable_receipt_resolution'); END''',
];
