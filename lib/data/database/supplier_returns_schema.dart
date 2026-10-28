/// Physical supplier returns are separate from approved financial credits.
/// Existing receipt, stock and cash tables are not rebuilt or reinterpreted.
final supplierReturnsSchema = <String>[
  '''CREATE TABLE supplier_return_drafts(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    receipt_id TEXT NOT NULL REFERENCES stock_receipts(id) ON DELETE RESTRICT,
    supplier_id TEXT NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    supplier_source TEXT NOT NULL CHECK(supplier_source IN ('receipt','invoice')),
    source_invoice_id TEXT REFERENCES supplier_invoices(id) ON DELETE RESTRICT,
    supplier_name TEXT NOT NULL,currency_code TEXT NOT NULL,currency_scale INTEGER NOT NULL,
    revision INTEGER NOT NULL DEFAULT 0 CHECK(revision>=0),
    status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','posted','cancelled')),
    reason TEXT NOT NULL DEFAULT '' CHECK(length(reason)<=300),
    return_id TEXT UNIQUE REFERENCES supplier_returns(id) ON DELETE RESTRICT,
    created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL,
    CHECK((status='posted' AND return_id IS NOT NULL) OR (status<>'posted' AND return_id IS NULL)),
    CHECK((supplier_source='receipt' AND source_invoice_id IS NULL) OR (supplier_source='invoice' AND source_invoice_id IS NOT NULL)))''',
  'CREATE INDEX supplier_return_drafts_list ON supplier_return_drafts(supplier_id,status,updated_at DESC,id COLLATE BINARY DESC)',
  '''CREATE TABLE supplier_return_draft_lines(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    draft_id TEXT NOT NULL REFERENCES supplier_return_drafts(id) ON DELETE RESTRICT,
    receipt_item_id TEXT NOT NULL REFERENCES stock_receipt_items(id) ON DELETE RESTRICT,
    product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    batch_id TEXT REFERENCES stock_batches(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK(typeof(quantity)='integer' AND quantity BETWEEN 1 AND 9000000000000),
    product_revision INTEGER NOT NULL,stock_revision INTEGER NOT NULL,
    tracked INTEGER NOT NULL CHECK(tracked IN (0,1)),
    position INTEGER NOT NULL CHECK(position>=0),
    UNIQUE(draft_id,receipt_item_id),UNIQUE(draft_id,position),
    CHECK((tracked=1 AND batch_id IS NOT NULL) OR (tracked=0 AND batch_id IS NULL)))''',
  '''CREATE TABLE supplier_returns(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    draft_id TEXT NOT NULL UNIQUE REFERENCES supplier_return_drafts(id) ON DELETE RESTRICT,
    confirmed_revision INTEGER NOT NULL CHECK(confirmed_revision>=0),
    receipt_id TEXT NOT NULL REFERENCES stock_receipts(id) ON DELETE RESTRICT,
    supplier_id TEXT NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    supplier_source TEXT NOT NULL CHECK(supplier_source IN ('receipt','invoice')),
    source_invoice_id TEXT REFERENCES supplier_invoices(id) ON DELETE RESTRICT,
    supplier_name_snapshot TEXT NOT NULL,currency_code TEXT NOT NULL,currency_scale INTEGER NOT NULL,
    reason TEXT NOT NULL CHECK(length(trim(reason)) BETWEEN 1 AND 300),
    operation_key TEXT NOT NULL UNIQUE,payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
    actor_role TEXT NOT NULL CHECK(actor_role IN ('owner','warehouse')),created_at INTEGER NOT NULL,
    CHECK((supplier_source='receipt' AND source_invoice_id IS NULL) OR (supplier_source='invoice' AND source_invoice_id IS NOT NULL)))''',
  'CREATE INDEX supplier_returns_receipt ON supplier_returns(receipt_id,id)',
  'CREATE INDEX supplier_returns_list ON supplier_returns(supplier_id,created_at DESC,id COLLATE BINARY DESC)',
  '''CREATE TABLE supplier_return_items(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    return_id TEXT NOT NULL REFERENCES supplier_returns(id) ON DELETE RESTRICT,
    receipt_item_id TEXT NOT NULL REFERENCES stock_receipt_items(id) ON DELETE RESTRICT,
    product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    product_name_snapshot TEXT NOT NULL,base_unit_snapshot TEXT NOT NULL,
    source_quantity INTEGER NOT NULL,source_total_micros INTEGER,source_cost_complete INTEGER NOT NULL CHECK(source_cost_complete IN (0,1)),
    batch_id TEXT REFERENCES stock_batches(id) ON DELETE RESTRICT,
    batch_before INTEGER,batch_after INTEGER,batch_expiry TEXT,batch_received_at INTEGER,
    quantity INTEGER NOT NULL CHECK(typeof(quantity)='integer' AND quantity>0 AND quantity<=source_quantity),
    tracked INTEGER NOT NULL CHECK(tracked IN (0,1)),
    before_quantity INTEGER NOT NULL,after_quantity INTEGER NOT NULL,
    before_value_micros INTEGER NOT NULL,after_value_micros INTEGER NOT NULL,
    before_complete INTEGER NOT NULL CHECK(before_complete IN (0,1)),after_complete INTEGER NOT NULL CHECK(after_complete IN (0,1)),
    removed_value_micros INTEGER NOT NULL CHECK(removed_value_micros>=0),
    stock_revision_after INTEGER NOT NULL CHECK(stock_revision_after>0),
    inventory_operation_id TEXT NOT NULL UNIQUE REFERENCES inventory_operations(id) ON DELETE RESTRICT,
    position INTEGER NOT NULL CHECK(position>=0),
    UNIQUE(return_id,receipt_item_id),UNIQUE(return_id,position),
    CHECK((tracked=1 AND batch_id IS NOT NULL AND batch_before>=quantity AND batch_after=batch_before-quantity
      AND after_quantity=before_quantity-quantity AND after_value_micros=before_value_micros-removed_value_micros) OR
      (tracked=0 AND batch_id IS NULL AND batch_before IS NULL AND batch_after IS NULL
      AND before_quantity=999 AND after_quantity=999 AND before_value_micros=0 AND after_value_micros=0 AND removed_value_micros=0)))''',
  'CREATE INDEX supplier_return_items_source ON supplier_return_items(receipt_item_id,return_id)',
  '''CREATE TABLE supplier_return_reversals(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    return_id TEXT NOT NULL UNIQUE REFERENCES supplier_returns(id) ON DELETE RESTRICT,
    operation_key TEXT NOT NULL UNIQUE,payload_hash TEXT NOT NULL CHECK(length(payload_hash)=64),
    reason TEXT NOT NULL CHECK(length(trim(reason)) BETWEEN 1 AND 300),
    actor_role TEXT NOT NULL CHECK(actor_role IN ('owner','warehouse')),created_at INTEGER NOT NULL)''',
  '''CREATE TABLE supplier_return_reversal_items(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    reversal_id TEXT NOT NULL REFERENCES supplier_return_reversals(id) ON DELETE RESTRICT,
    return_item_id TEXT NOT NULL UNIQUE REFERENCES supplier_return_items(id) ON DELETE RESTRICT,
    inventory_operation_id TEXT NOT NULL UNIQUE REFERENCES inventory_operations(id) ON DELETE RESTRICT)''',
  '''CREATE TABLE supplier_return_source_events(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    receipt_item_id TEXT NOT NULL REFERENCES stock_receipt_items(id) ON DELETE RESTRICT,
    sequence INTEGER NOT NULL CHECK(sequence>0),
    returned_before INTEGER NOT NULL CHECK(returned_before>=0),returned_after INTEGER NOT NULL CHECK(returned_after>=0),
    quantity_delta INTEGER NOT NULL CHECK(quantity_delta<>0),
    return_item_id TEXT UNIQUE REFERENCES supplier_return_items(id) ON DELETE RESTRICT,
    reversal_item_id TEXT UNIQUE REFERENCES supplier_return_reversal_items(id) ON DELETE RESTRICT,
    created_at INTEGER NOT NULL,UNIQUE(receipt_item_id,sequence),
    CHECK(returned_after=returned_before+quantity_delta),
    CHECK((return_item_id IS NOT NULL AND reversal_item_id IS NULL AND quantity_delta>0) OR
      (return_item_id IS NULL AND reversal_item_id IS NOT NULL AND quantity_delta<0)))''',
  for (final table in [
    'supplier_returns',
    'supplier_return_items',
    'supplier_return_reversals',
    'supplier_return_reversal_items',
    'supplier_return_source_events',
  ])
    for (final action in ['UPDATE', 'DELETE'])
      '''CREATE TRIGGER ${table}_${action.toLowerCase()} BEFORE $action ON $table
      BEGIN SELECT RAISE(ABORT,'immutable_supplier_return'); END''',
  for (final action in ['INSERT', 'UPDATE', 'DELETE'])
    '''CREATE TRIGGER supplier_return_lines_${action.toLowerCase()} BEFORE $action ON supplier_return_draft_lines
      WHEN (SELECT status FROM supplier_return_drafts WHERE id=${action == 'INSERT' ? 'NEW' : 'OLD'}.draft_id)<>'draft'
      ${action == 'UPDATE' ? "OR NEW.draft_id<>OLD.draft_id" : ''}
      BEGIN SELECT RAISE(ABORT,'closed_supplier_return_draft'); END''',
  '''CREATE TRIGGER supplier_return_draft_update BEFORE UPDATE ON supplier_return_drafts WHEN
    OLD.status<>'draft' OR NEW.revision<>OLD.revision+1 OR
    ${['id', 'receipt_id', 'supplier_id', 'supplier_source', 'source_invoice_id', 'supplier_name', 'currency_code', 'currency_scale', 'created_at'].map((c) => 'NEW.$c IS NOT OLD.$c').join(' OR ')} OR
    (NEW.status='posted' AND NOT EXISTS(SELECT 1 FROM supplier_returns r WHERE r.id=NEW.return_id AND r.draft_id=OLD.id
      AND r.confirmed_revision=OLD.revision AND r.reason=NEW.reason AND r.created_at=NEW.updated_at))
    BEGIN SELECT RAISE(ABORT,'invalid_supplier_return_draft'); END''',
  '''CREATE TRIGGER supplier_return_draft_delete BEFORE DELETE ON supplier_return_drafts
    BEGIN SELECT RAISE(ABORT,'retain_supplier_return_draft'); END''',
];
