/// Physical observations are draft input until one atomic finalization. Frozen
/// baselines/results remain readable after later sales and never imply theft.
final stocktakeSchema = <String>[
  '''CREATE TABLE stocktake_drafts(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','posted','cancelled')),
    revision INTEGER NOT NULL DEFAULT 0 CHECK(typeof(revision)='integer' AND revision>=0),
    currency_code TEXT NOT NULL,currency_scale INTEGER NOT NULL,time_zone TEXT NOT NULL,
    created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL,
    reason TEXT CHECK(reason IS NULL OR length(trim(reason)) BETWEEN 1 AND 300),
    actor_role TEXT CHECK(actor_role IS NULL OR actor_role IN ('owner','warehouse')),
    confirmed_revision INTEGER,posted_at INTEGER,
    CHECK((status='posted' AND reason IS NOT NULL AND actor_role IS NOT NULL AND
      confirmed_revision IS NOT NULL AND posted_at IS NOT NULL) OR
      (status<>'posted' AND confirmed_revision IS NULL AND posted_at IS NULL)))''',
  'CREATE INDEX stocktake_drafts_cursor ON stocktake_drafts(status,updated_at DESC,id COLLATE BINARY DESC)',
  '''CREATE TABLE stocktake_lines(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    draft_id TEXT NOT NULL REFERENCES stocktake_drafts(id) ON DELETE RESTRICT,
    product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    position INTEGER NOT NULL CHECK(typeof(position)='integer' AND position>=0),
    product_name TEXT NOT NULL CHECK(length(product_name) BETWEEN 1 AND 200),
    base_unit TEXT NOT NULL CHECK(length(base_unit) BETWEEN 1 AND 80),
    product_revision INTEGER NOT NULL CHECK(typeof(product_revision)='integer' AND product_revision>=0),
    stock_revision INTEGER NOT NULL CHECK(typeof(stock_revision)='integer' AND stock_revision>=0),
    baseline_epoch INTEGER NOT NULL DEFAULT 0 CHECK(typeof(baseline_epoch)='integer' AND baseline_epoch>=0),
    baseline_quantity INTEGER NOT NULL CHECK(typeof(baseline_quantity)='integer' AND baseline_quantity>=0),
    baseline_value_micros INTEGER NOT NULL CHECK(typeof(baseline_value_micros)='integer' AND baseline_value_micros>=0),
    baseline_complete INTEGER NOT NULL CHECK(baseline_complete IN (0,1)),captured_at INTEGER NOT NULL,
    empty_pool_total_micros INTEGER CHECK(empty_pool_total_micros IS NULL OR
      (typeof(empty_pool_total_micros)='integer' AND empty_pool_total_micros BETWEEN 0 AND 9000000000000000000 AND empty_pool_total_micros%1000000=0)),
    valuation_quantity INTEGER CHECK(valuation_quantity IS NULL OR (typeof(valuation_quantity)='integer' AND valuation_quantity>0)),
    confirmed_free INTEGER NOT NULL DEFAULT 0 CHECK(confirmed_free IN (0,1)),
    final_quantity INTEGER CHECK(final_quantity IS NULL OR (typeof(final_quantity)='integer' AND final_quantity>=0)),
    final_value_micros INTEGER CHECK(final_value_micros IS NULL OR (typeof(final_value_micros)='integer' AND final_value_micros>=0)),
    final_complete INTEGER CHECK(final_complete IS NULL OR final_complete IN (0,1)),
    operation_id TEXT UNIQUE REFERENCES inventory_operations(id) ON DELETE RESTRICT,
    UNIQUE(draft_id,product_id),UNIQUE(draft_id,position))''',
  'CREATE INDEX stocktake_line_cursor ON stocktake_lines(draft_id,position,id COLLATE BINARY)',
  '''CREATE TABLE stocktake_observations(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    line_id TEXT NOT NULL REFERENCES stocktake_lines(id) ON DELETE CASCADE,
    position INTEGER NOT NULL CHECK(typeof(position)='integer' AND position>=0),
    baseline_batch_id TEXT REFERENCES stock_batches(id) ON DELETE RESTRICT,
    baseline_quantity INTEGER NOT NULL CHECK(typeof(baseline_quantity)='integer' AND baseline_quantity>=0),
    baseline_expiry TEXT CHECK(baseline_expiry IS NULL OR length(baseline_expiry)=10),
    baseline_received_at INTEGER,
    baseline_item_id TEXT REFERENCES stock_receipt_items(id) ON DELETE RESTRICT,
    counted_quantity INTEGER CHECK(counted_quantity IS NULL OR (typeof(counted_quantity)='integer' AND counted_quantity>=0)),
    input_unit TEXT CHECK(input_unit IS NULL OR input_unit IN ('base','pack')),
    input_count INTEGER CHECK(input_count IS NULL OR (typeof(input_count)='integer' AND input_count>=0)),
    pack_size INTEGER CHECK(pack_size IS NULL OR (typeof(pack_size)='integer' AND pack_size>0)),
    pack_label TEXT CHECK(pack_label IS NULL OR length(pack_label) BETWEEN 1 AND 80),
    observed_expiry TEXT CHECK(observed_expiry IS NULL OR length(observed_expiry)=10),
    result_batch_id TEXT REFERENCES stock_batches(id) ON DELETE RESTRICT,
    UNIQUE(line_id,position),UNIQUE(line_id,baseline_batch_id),
    CHECK((counted_quantity IS NULL AND input_unit IS NULL AND input_count IS NULL AND pack_size IS NULL AND pack_label IS NULL) OR
      (counted_quantity IS NOT NULL AND input_count IS NOT NULL AND
        ((input_unit='base' AND counted_quantity=input_count AND pack_size IS NULL AND pack_label IS NULL) OR
         (input_unit='pack' AND pack_size IS NOT NULL AND pack_label IS NOT NULL AND
          counted_quantity/pack_size=input_count AND counted_quantity%pack_size=0)))))''',
  'CREATE INDEX stocktake_observation_cursor ON stocktake_observations(line_id,position,id COLLATE BINARY)',
  '''CREATE TABLE stocktake_draft_events(
    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
    draft_id TEXT NOT NULL REFERENCES stocktake_drafts(id) ON DELETE RESTRICT,
    observation_id TEXT NOT NULL REFERENCES stocktake_observations(id) ON DELETE CASCADE,
    created_revision INTEGER NOT NULL,undone_revision INTEGER,
    before_json TEXT NOT NULL CHECK(length(before_json)<=2048),
    after_json TEXT NOT NULL CHECK(length(after_json)<=2048))''',
  'CREATE INDEX stocktake_undo ON stocktake_draft_events(draft_id,undone_revision,created_revision DESC,id COLLATE BINARY DESC)',
  '''CREATE TRIGGER stocktake_header_final BEFORE UPDATE ON stocktake_drafts
    WHEN OLD.status<>'draft' BEGIN SELECT RAISE(ABORT,'immutable_stocktake'); END''',
  '''CREATE TRIGGER stocktake_header_retain BEFORE DELETE ON stocktake_drafts
    BEGIN SELECT RAISE(ABORT,'retain_stocktake'); END''',
  for (final table in [
    'stocktake_lines',
    'stocktake_observations',
    'stocktake_draft_events',
  ])
    for (final action in ['INSERT', 'UPDATE', 'DELETE'])
      '''CREATE TRIGGER ${table}_${action.toLowerCase()} BEFORE $action ON $table
      WHEN (SELECT d.status FROM stocktake_drafts d ${table == 'stocktake_observations' ? 'JOIN stocktake_lines l ON l.draft_id=d.id' : ''}
        WHERE ${table == 'stocktake_observations' ? 'l.id' : 'd.id'}=${action == 'DELETE' ? 'OLD' : 'NEW'}.${table == 'stocktake_observations' ? 'line_id' : 'draft_id'})<>'draft'
      ${action == 'UPDATE' ? 'OR NEW.id<>OLD.id OR NEW.${table == 'stocktake_observations' ? 'line_id' : 'draft_id'}<>OLD.${table == 'stocktake_observations' ? 'line_id' : 'draft_id'}' : ''}
      BEGIN SELECT RAISE(ABORT,'immutable_stocktake'); END''',
];
