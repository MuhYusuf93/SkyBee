/// Partial return documents are separate append-only facts. The old sale and
/// payment rows remain immutable and retain their original reported amounts.
final saleReturnsSchema = [
  '''CREATE TABLE sale_returns(
    id TEXT NOT NULL PRIMARY KEY CHECK(length(id)=36),
    sale_transaction_id TEXT NOT NULL REFERENCES sale_transactions(id) ON DELETE RESTRICT,
    operation_key TEXT NOT NULL UNIQUE CHECK(length(operation_key) BETWEEN 1 AND 200),
    payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
    created_at INTEGER NOT NULL CHECK(typeof(created_at)='integer' AND created_at>=0),
    reason TEXT NOT NULL CHECK(length(trim(reason)) BETWEEN 1 AND 500),
    net_minor INTEGER NOT NULL CHECK(typeof(net_minor)='integer' AND net_minor>=0),
    debt_reduction_minor INTEGER NOT NULL CHECK(typeof(debt_reduction_minor)='integer' AND debt_reduction_minor>=0),
    refund_due_minor INTEGER NOT NULL CHECK(typeof(refund_due_minor)='integer' AND refund_due_minor>=0),
    cost_micros INTEGER NOT NULL CHECK(typeof(cost_micros)='integer' AND cost_micros>=0),
    write_down_micros INTEGER NOT NULL CHECK(typeof(write_down_micros)='integer' AND write_down_micros BETWEEN 0 AND cost_micros),
    cost_complete INTEGER NOT NULL CHECK(cost_complete IN (0,1)),
    owner_override INTEGER NOT NULL CHECK(owner_override IN (0,1)),
    CHECK(net_minor-debt_reduction_minor=refund_due_minor))''',
  'CREATE INDEX sale_returns_sale ON sale_returns(sale_transaction_id,id)',
  'CREATE INDEX sale_returns_pending ON sale_returns(sale_transaction_id,created_at DESC,id COLLATE BINARY DESC) WHERE refund_due_minor>0',
  'CREATE INDEX sale_returns_period ON sale_returns(created_at DESC,id COLLATE BINARY DESC)',
  '''CREATE TABLE sale_return_items(
    id TEXT NOT NULL PRIMARY KEY CHECK(length(id)=36),
    sale_return_id TEXT NOT NULL REFERENCES sale_returns(id) ON DELETE RESTRICT,
    sale_transaction_item_id TEXT NOT NULL REFERENCES sale_transaction_items(id) ON DELETE RESTRICT,
    returned_before INTEGER NOT NULL CHECK(typeof(returned_before)='integer' AND returned_before>=0),
    quantity INTEGER NOT NULL CHECK(typeof(quantity)='integer' AND quantity>0),
    condition TEXT NOT NULL CHECK(condition IN ('good','quarantine')),
    net_minor INTEGER NOT NULL CHECK(typeof(net_minor)='integer' AND net_minor>=0),
    cost_micros INTEGER NOT NULL CHECK(typeof(cost_micros)='integer' AND cost_micros>=0),
    cost_complete INTEGER NOT NULL CHECK(cost_complete IN (0,1)),
    UNIQUE(sale_return_id,sale_transaction_item_id),
    UNIQUE(sale_transaction_item_id,returned_before))''',
  '''CREATE TABLE sale_return_batch_allocations(
    sale_return_item_id TEXT NOT NULL REFERENCES sale_return_items(id) ON DELETE RESTRICT,
    sale_batch_allocation_id TEXT NOT NULL REFERENCES sale_batch_allocations(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK(typeof(quantity)='integer' AND quantity>0),
    PRIMARY KEY(sale_return_item_id,sale_batch_allocation_id))''',
  'CREATE INDEX sale_return_allocations_source ON sale_return_batch_allocations(sale_batch_allocation_id)',
  '''ALTER TABLE stock_history ADD COLUMN sale_return_item_id TEXT
    REFERENCES sale_return_items(id) ON DELETE RESTRICT''',
  'CREATE UNIQUE INDEX stock_history_return_item ON stock_history(sale_return_item_id) WHERE sale_return_item_id IS NOT NULL',
  '''CREATE TRIGGER sale_return_active_sale BEFORE INSERT ON sale_returns
    WHEN EXISTS (SELECT 1 FROM sale_transaction_reversals r WHERE r.sale_transaction_id=NEW.sale_transaction_id)
    BEGIN SELECT RAISE(ABORT,'sale_already_reversed'); END''',
  '''CREATE TRIGGER sale_reversal_no_partial_returns BEFORE INSERT ON sale_transaction_reversals
    WHEN EXISTS (SELECT 1 FROM sale_returns r WHERE r.sale_transaction_id=NEW.sale_transaction_id)
    BEGIN SELECT RAISE(ABORT,'sale_has_partial_returns'); END''',
  '''CREATE TRIGGER payment_reversal_no_partial_returns BEFORE INSERT ON payment_allocations
    WHEN EXISTS (SELECT 1 FROM payments p JOIN sale_returns r ON r.sale_transaction_id=NEW.sale_transaction_id
      WHERE p.id=NEW.payment_id AND p.kind='reversal')
    BEGIN SELECT RAISE(ABORT,'sale_has_partial_returns'); END''',
  '''CREATE TRIGGER sale_return_item_validate BEFORE INSERT ON sale_return_items
    WHEN NOT EXISTS (SELECT 1 FROM sale_transaction_items i JOIN sale_returns r ON r.id=NEW.sale_return_id
      WHERE i.id=NEW.sale_transaction_item_id AND i.sale_transaction_id=r.sale_transaction_id
      AND NEW.quantity<=i.quantity-NEW.returned_before
      AND NEW.returned_before=COALESCE((SELECT SUM(x.quantity) FROM sale_return_items x
        WHERE x.sale_transaction_item_id=i.id),0))
    BEGIN SELECT RAISE(ABORT,'invalid_sale_return_quantity'); END''',
  '''CREATE TRIGGER sale_return_batch_validate BEFORE INSERT ON sale_return_batch_allocations
    WHEN NOT EXISTS (SELECT 1 FROM sale_batch_allocations a JOIN sale_return_items i ON i.id=NEW.sale_return_item_id
      WHERE a.id=NEW.sale_batch_allocation_id AND a.sale_transaction_item_id=i.sale_transaction_item_id
      AND NEW.quantity<=a.quantity-COALESCE((SELECT SUM(x.quantity) FROM sale_return_batch_allocations x
        WHERE x.sale_batch_allocation_id=a.id),0))
    BEGIN SELECT RAISE(ABORT,'invalid_sale_return_batch'); END''',
  for (final table in [
    'sale_returns',
    'sale_return_items',
    'sale_return_batch_allocations',
  ])
    for (final action in ['update', 'delete'])
      "CREATE TRIGGER ${table}_no_$action BEFORE ${action.toUpperCase()} ON $table BEGIN SELECT RAISE(ABORT,'immutable_fact'); END",
];
