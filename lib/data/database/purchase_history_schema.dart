/// Index the immutable header timestamp with the product key. Keeping this
/// projection separate lets migration and insert triggers preserve fact rows.
const purchaseHistorySchema = [
  '''CREATE TABLE stock_receipt_item_dates(
    item_id TEXT PRIMARY KEY NOT NULL REFERENCES stock_receipt_items(id) ON DELETE RESTRICT,
    product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    received_at INTEGER NOT NULL CHECK(typeof(received_at)='integer' AND received_at>=0)
  )''',
  '''INSERT INTO stock_receipt_item_dates(item_id,product_id,received_at)
    SELECT i.id,i.product_id,r.created_at FROM stock_receipt_items i
    JOIN stock_receipts r ON r.id=i.stock_receipt_id''',
  '''CREATE INDEX stock_receipt_item_dates_product ON stock_receipt_item_dates(
    product_id,received_at DESC,item_id COLLATE BINARY DESC)''',
  'CREATE INDEX stock_tracking_changes_receipt ON stock_tracking_changes(stock_receipt_id) WHERE stock_receipt_id IS NOT NULL',
  '''CREATE TRIGGER stock_receipt_item_dates_insert AFTER INSERT ON stock_receipt_items
    BEGIN INSERT INTO stock_receipt_item_dates(item_id,product_id,received_at)
    SELECT NEW.id,NEW.product_id,created_at FROM stock_receipts WHERE id=NEW.stock_receipt_id;
    END''',
];
