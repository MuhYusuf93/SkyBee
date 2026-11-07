/// An unsettled return has no row here. Confirmation records an actual outflow
/// once, with a reference to the active cash drawer event when applicable.
const saleRefundSchema = [
  '''CREATE TABLE sale_return_refunds(
    id TEXT NOT NULL PRIMARY KEY CHECK(length(id)=36),
    sale_return_id TEXT NOT NULL UNIQUE REFERENCES sale_returns(id) ON DELETE RESTRICT,
    operation_key TEXT NOT NULL UNIQUE CHECK(length(operation_key) BETWEEN 1 AND 200),
    payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
    method TEXT NOT NULL CHECK(method IN ('cash','qris','transfer','external')),
    created_at INTEGER NOT NULL CHECK(typeof(created_at)='integer' AND created_at>=0),
    amount_minor INTEGER NOT NULL CHECK(typeof(amount_minor)='integer' AND amount_minor>0),
    drawer_mode TEXT NOT NULL CHECK(drawer_mode IN ('off','notes','audit')),
    event_id TEXT UNIQUE REFERENCES cash_drawer_events(id) ON DELETE RESTRICT,
    CHECK((method='cash' AND drawer_mode<>'off' AND event_id IS NOT NULL) OR
          ((method<>'cash' OR drawer_mode='off') AND event_id IS NULL)))''',
  'CREATE INDEX sale_return_refunds_period ON sale_return_refunds(created_at DESC,id COLLATE BINARY DESC)',
  '''CREATE TRIGGER sale_return_refund_amount BEFORE INSERT ON sale_return_refunds
    WHEN NEW.amount_minor IS NOT (SELECT refund_due_minor FROM sale_returns WHERE id=NEW.sale_return_id)
    BEGIN SELECT RAISE(ABORT,'refund_amount_mismatch'); END''',
  "CREATE TRIGGER sale_return_refunds_no_update BEFORE UPDATE ON sale_return_refunds BEGIN SELECT RAISE(ABORT,'immutable_fact'); END",
  "CREATE TRIGGER sale_return_refunds_no_delete BEFORE DELETE ON sale_return_refunds BEGIN SELECT RAISE(ABORT,'immutable_fact'); END",
];
