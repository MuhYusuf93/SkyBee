/// Physical returns may have known provenance, quarantined units, or a
/// warehouse observation. An optional credit declaration is a pending
/// supplier claim, separate from the inventory movement and paid balances.
final supplierReturnPreparationSchema = [
  '''CREATE TABLE supplier_return_preparations(
    id TEXT NOT NULL PRIMARY KEY CHECK(length(id)=36),
    supplier_id TEXT NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    supplier_name TEXT NOT NULL,
    currency_code TEXT NOT NULL,currency_scale INTEGER NOT NULL,
    created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL,
    revision INTEGER NOT NULL DEFAULT 0 CHECK(revision>=0),
    status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','closed','cancelled')),
    reason TEXT NOT NULL DEFAULT '' CHECK(length(reason)<=300))''',
  '''CREATE INDEX supplier_return_preparation_list
    ON supplier_return_preparations(supplier_id,updated_at DESC,id COLLATE BINARY DESC)''',
  '''CREATE TABLE supplier_return_observations(
    id TEXT NOT NULL PRIMARY KEY CHECK(length(id)=36),
    product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK(typeof(quantity)='integer' AND quantity BETWEEN 1 AND 9000000000000),
    created_at INTEGER NOT NULL)''',
  '''CREATE INDEX supplier_return_observations_product
    ON supplier_return_observations(product_id,created_at DESC,id COLLATE BINARY DESC)''',
  '''CREATE TABLE supplier_return_preparation_lines(
    id TEXT NOT NULL PRIMARY KEY CHECK(length(id)=36),
    preparation_id TEXT NOT NULL REFERENCES supplier_return_preparations(id) ON DELETE RESTRICT,
    product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    product_name TEXT NOT NULL,base_unit TEXT NOT NULL,
    batch_id TEXT REFERENCES stock_batches(id) ON DELETE RESTRICT,
    sale_return_item_id TEXT REFERENCES sale_return_items(id) ON DELETE RESTRICT,
    observation_id TEXT REFERENCES supplier_return_observations(id) ON DELETE RESTRICT,
    source_receipt_item_id TEXT REFERENCES stock_receipt_items(id) ON DELETE RESTRICT,
    reference_basis TEXT NOT NULL CHECK(reference_basis IN ('receipt','return_hpp','average','reference','unknown')),
    reference_cost_micros INTEGER CHECK(reference_cost_micros IS NULL OR
      (typeof(reference_cost_micros)='integer' AND reference_cost_micros>=0)),
    remaining INTEGER NOT NULL CHECK(typeof(remaining)='integer' AND remaining BETWEEN 0 AND 9000000000000),
    note TEXT NOT NULL CHECK(length(note)<=300),created_at INTEGER NOT NULL,
    CHECK((batch_id IS NOT NULL)+(sale_return_item_id IS NOT NULL)+(observation_id IS NOT NULL)=1),
    UNIQUE(preparation_id,batch_id),UNIQUE(preparation_id,sale_return_item_id),
    UNIQUE(preparation_id,observation_id))''',
  'CREATE INDEX supplier_preparation_batch ON supplier_return_preparation_lines(batch_id,preparation_id)',
  'CREATE INDEX supplier_preparation_quarantine ON supplier_return_preparation_lines(sale_return_item_id,preparation_id)',
  'CREATE INDEX supplier_preparation_observation ON supplier_return_preparation_lines(observation_id,preparation_id)',
  '''CREATE TABLE supplier_return_dispatches(
    id TEXT NOT NULL PRIMARY KEY CHECK(length(id)=36),
    preparation_id TEXT NOT NULL REFERENCES supplier_return_preparations(id) ON DELETE RESTRICT,
    operation_key TEXT NOT NULL UNIQUE,payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
    expected_revision INTEGER NOT NULL CHECK(expected_revision>=0),
    reject_remaining INTEGER NOT NULL CHECK(reject_remaining IN (0,1)),
    credit_claim_minor INTEGER CHECK(credit_claim_minor IS NULL OR
      (typeof(credit_claim_minor)='integer' AND credit_claim_minor BETWEEN 1 AND 9000000000000)),
    reason TEXT NOT NULL CHECK(length(reason)<=300),
    actor_role TEXT NOT NULL CHECK(actor_role IN ('owner','warehouse')),created_at INTEGER NOT NULL,
    UNIQUE(preparation_id,expected_revision))''',
  'CREATE INDEX supplier_return_dispatches_list ON supplier_return_dispatches(preparation_id,created_at DESC,id COLLATE BINARY DESC)',
  '''CREATE TABLE supplier_return_dispatch_items(
    id TEXT NOT NULL PRIMARY KEY CHECK(length(id)=36),
    dispatch_id TEXT NOT NULL REFERENCES supplier_return_dispatches(id) ON DELETE RESTRICT,
    preparation_line_id TEXT NOT NULL REFERENCES supplier_return_preparation_lines(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK(typeof(quantity)='integer' AND quantity BETWEEN 1 AND 9000000000000),
    stock_operation_id TEXT UNIQUE REFERENCES inventory_operations(id) ON DELETE RESTRICT,
    stock_revision_after INTEGER,batch_quantity_after INTEGER,
    removed_value_micros INTEGER NOT NULL CHECK(typeof(removed_value_micros)='integer' AND removed_value_micros>=0),
    UNIQUE(dispatch_id,preparation_line_id),
    CHECK((stock_operation_id IS NULL AND stock_revision_after IS NULL
      AND batch_quantity_after IS NULL AND removed_value_micros=0)
      OR (stock_operation_id IS NOT NULL AND stock_revision_after>0 AND batch_quantity_after>=0)))''',
  'CREATE INDEX supplier_return_dispatch_items_source ON supplier_return_dispatch_items(preparation_line_id)',
  '''CREATE TABLE supplier_return_dispatch_reversals(
    dispatch_id TEXT PRIMARY KEY NOT NULL REFERENCES supplier_return_dispatches(id) ON DELETE RESTRICT,
    operation_key TEXT NOT NULL UNIQUE,payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
    reason TEXT NOT NULL CHECK(length(trim(reason)) BETWEEN 1 AND 300),
    actor_role TEXT NOT NULL CHECK(actor_role IN ('owner','warehouse')),created_at INTEGER NOT NULL)''',
  '''CREATE TABLE supplier_return_dispatch_reversal_items(
    dispatch_item_id TEXT PRIMARY KEY NOT NULL REFERENCES supplier_return_dispatch_items(id) ON DELETE RESTRICT,
    stock_operation_id TEXT UNIQUE REFERENCES inventory_operations(id) ON DELETE RESTRICT)''',
  '''CREATE VIEW supplier_return_preparation_holds AS
    SELECT l.* FROM supplier_return_preparation_lines l
    JOIN supplier_return_preparations d ON d.id=l.preparation_id
    WHERE d.status='draft' AND l.remaining>0''',
  'DROP VIEW supplier_stock_reserved_batches',
  '''CREATE VIEW supplier_stock_reserved_batches AS
    SELECT batch_id,SUM(quantity) AS quantity FROM (
      SELECT batch_id,quantity FROM supplier_return_reservations WHERE batch_id IS NOT NULL
      UNION ALL
      SELECT batch_id,remaining FROM supplier_return_preparation_holds WHERE batch_id IS NOT NULL)
    GROUP BY batch_id''',
  '''CREATE VIEW supplier_return_active_dispatch_items AS
    SELECT x.* FROM supplier_return_dispatch_items x
    WHERE NOT EXISTS(SELECT 1 FROM supplier_return_dispatch_reversals v
      WHERE v.dispatch_id=x.dispatch_id)''',
  for (final table in [
    'supplier_return_observations',
    'supplier_return_dispatches',
    'supplier_return_dispatch_items',
    'supplier_return_dispatch_reversals',
    'supplier_return_dispatch_reversal_items',
  ])
    for (final action in ['UPDATE', 'DELETE'])
      '''CREATE TRIGGER ${table}_${action.toLowerCase()} BEFORE $action ON $table
      BEGIN SELECT RAISE(ABORT,'immutable_supplier_return'); END''',
  '''CREATE TRIGGER supplier_return_preparation_update BEFORE UPDATE ON supplier_return_preparations
    WHEN OLD.status<>'draft' OR NEW.revision<>OLD.revision+1
      OR NEW.supplier_id<>OLD.supplier_id OR NEW.supplier_name<>OLD.supplier_name
      OR NEW.id<>OLD.id OR NEW.created_at<>OLD.created_at
      OR NEW.currency_code<>OLD.currency_code OR NEW.currency_scale<>OLD.currency_scale
    BEGIN SELECT RAISE(ABORT,'closed_supplier_return_draft'); END''',
  '''CREATE TRIGGER supplier_return_preparation_retain BEFORE DELETE ON supplier_return_preparations
    BEGIN SELECT RAISE(ABORT,'retain_supplier_return_draft'); END''',
  for (final action in ['INSERT', 'UPDATE'])
    '''CREATE TRIGGER supplier_preparation_line_${action.toLowerCase()}
      BEFORE $action ON supplier_return_preparation_lines
      WHEN (SELECT status FROM supplier_return_preparations WHERE id=NEW.preparation_id)<>'draft'
      ${action == 'UPDATE' ? "OR NEW.preparation_id<>OLD.preparation_id OR NEW.id<>OLD.id OR NEW.product_id<>OLD.product_id OR NEW.batch_id IS NOT OLD.batch_id OR NEW.sale_return_item_id IS NOT OLD.sale_return_item_id OR NEW.observation_id IS NOT OLD.observation_id" : ""}
      BEGIN SELECT RAISE(ABORT,'closed_supplier_return_draft'); END''',
  '''CREATE TRIGGER supplier_preparation_line_retain BEFORE DELETE ON supplier_return_preparation_lines
    BEGIN SELECT RAISE(ABORT,'retain_supplier_return_draft'); END''',
  for (final action in ['INSERT', 'UPDATE'])
    '''CREATE TRIGGER supplier_preparation_epoch_${action.toLowerCase()}
      AFTER $action ON supplier_return_preparation_lines WHEN NEW.batch_id IS NOT NULL
      BEGIN UPDATE cashier_search_versions SET catalogue_epoch=catalogue_epoch+1 WHERE id=1; END''',
  '''CREATE TRIGGER supplier_preparation_epoch_close AFTER UPDATE OF status ON supplier_return_preparations
    WHEN NEW.status<>OLD.status AND EXISTS(SELECT 1 FROM supplier_return_preparation_lines l
      WHERE l.preparation_id=OLD.id AND l.batch_id IS NOT NULL AND l.remaining>0)
    BEGIN UPDATE cashier_search_versions SET catalogue_epoch=catalogue_epoch+1 WHERE id=1; END''',
];
