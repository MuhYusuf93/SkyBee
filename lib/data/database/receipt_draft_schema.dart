/// Draft edits never post inventory. Finalized documents and their input
/// snapshots are immutable; the existing receipt/item/batch ledger stays the
/// sole source of purchase and valuation facts.
final receiptDraftSchema = <String>[
  'CREATE INDEX inventory_purchase_revision ON inventory_operations(product_id,kind,stock_revision_after DESC,id COLLATE BINARY DESC)',
  '''ALTER TABLE inventory_operations ADD COLUMN stock_receipt_item_id TEXT
    REFERENCES stock_receipt_items(id) ON DELETE RESTRICT''',
  'ALTER TABLE inventory_operations ADD COLUMN before_reference_cost_micros INTEGER CHECK(before_reference_cost_micros IS NULL OR before_reference_cost_micros>=0)',
  '''ALTER TABLE reference_cost_history ADD COLUMN stock_receipt_item_id TEXT
    REFERENCES stock_receipt_items(id) ON DELETE RESTRICT''',
  '''CREATE TABLE receipt_drafts(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','posted','cancelled')),
    revision INTEGER NOT NULL DEFAULT 0 CHECK(typeof(revision)='integer' AND revision>=0),
    supplier_id TEXT REFERENCES suppliers(id) ON DELETE RESTRICT,
    currency_code TEXT NOT NULL,currency_scale INTEGER NOT NULL,
    time_zone TEXT NOT NULL,created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL,
    receipt_id TEXT UNIQUE REFERENCES stock_receipts(id) ON DELETE RESTRICT,
    confirmed_revision INTEGER,posted_at INTEGER,
    CHECK((status='posted' AND receipt_id IS NOT NULL AND confirmed_revision IS NOT NULL AND posted_at IS NOT NULL)
      OR (status<>'posted' AND receipt_id IS NULL AND confirmed_revision IS NULL AND posted_at IS NULL)))''',
  'CREATE INDEX receipt_drafts_cursor ON receipt_drafts(status,updated_at DESC,id COLLATE BINARY DESC)',
  '''CREATE TABLE receipt_draft_lines(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    draft_id TEXT NOT NULL REFERENCES receipt_drafts(id) ON DELETE RESTRICT,
    product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    product_revision INTEGER NOT NULL CHECK(product_revision>=0),
    product_name TEXT NOT NULL CHECK(length(product_name) BETWEEN 1 AND 200),
    position INTEGER NOT NULL CHECK(typeof(position)='integer' AND position>=0),
    input_unit TEXT NOT NULL CHECK(input_unit IN ('base','pack')),
    input_count INTEGER NOT NULL CHECK(typeof(input_count)='integer' AND input_count>0),
    pack_size INTEGER CHECK(pack_size IS NULL OR (typeof(pack_size)='integer' AND pack_size>0)),
    pack_label TEXT CHECK(pack_label IS NULL OR length(pack_label) BETWEEN 1 AND 80),
    cost_micros INTEGER CHECK(cost_micros IS NULL OR (typeof(cost_micros)='integer' AND cost_micros BETWEEN 0 AND 9000000000000000000 AND cost_micros%1000000=0)),
    confirmed_free INTEGER NOT NULL DEFAULT 0 CHECK(confirmed_free IN (0,1)),
    expiry_date TEXT CHECK(expiry_date IS NULL OR length(expiry_date)=10),
    UNIQUE(draft_id,position),
    CHECK((input_unit='base' AND pack_size IS NULL AND pack_label IS NULL)
      OR (input_unit='pack' AND pack_size IS NOT NULL AND pack_label IS NOT NULL)))''',
  'CREATE INDEX receipt_draft_product ON receipt_draft_lines(draft_id,product_id,position)',
  '''CREATE TRIGGER receipt_draft_final_update BEFORE UPDATE ON receipt_drafts
    WHEN OLD.status<>'draft' BEGIN SELECT RAISE(ABORT,'immutable_document'); END''',
  '''CREATE TRIGGER receipt_draft_no_delete BEFORE DELETE ON receipt_drafts
    BEGIN SELECT RAISE(ABORT,'retain_document'); END''',
  for (final action in ['INSERT', 'UPDATE', 'DELETE'])
    '''CREATE TRIGGER receipt_line_${action.toLowerCase()} BEFORE $action ON receipt_draft_lines
      WHEN (SELECT status FROM receipt_drafts WHERE id=${action == 'DELETE' ? 'OLD' : 'NEW'}.draft_id)<>'draft'
      ${action == 'UPDATE' ? "OR NEW.draft_id<>OLD.draft_id OR NEW.id<>OLD.id OR (SELECT status FROM receipt_drafts WHERE id=OLD.draft_id)<>'draft'" : ''}
      BEGIN SELECT RAISE(ABORT,'immutable_document'); END''',
];
