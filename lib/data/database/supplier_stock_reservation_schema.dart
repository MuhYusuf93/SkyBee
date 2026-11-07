/// Existing drafts keep their requested quantities and acquire reservations
/// only after review. Migration cannot infer which overlapping old drafts
/// represent physical units already set aside.
const supplierStockReservationSchema = [
  '''ALTER TABLE supplier_return_draft_lines ADD COLUMN reservation_active INTEGER NOT NULL
    DEFAULT 0 CHECK(reservation_active IN (0,1))''',
  '''CREATE INDEX supplier_return_reserved_batch
    ON supplier_return_draft_lines(batch_id,draft_id) WHERE reservation_active=1''',
  '''CREATE INDEX supplier_return_reserved_item
    ON supplier_return_draft_lines(receipt_item_id,draft_id) WHERE reservation_active=1''',
  '''CREATE VIEW supplier_return_reservations AS
    SELECT l.id,l.draft_id,l.receipt_item_id,l.batch_id,l.quantity
    FROM supplier_return_draft_lines l JOIN supplier_return_drafts d ON d.id=l.draft_id
    WHERE l.reservation_active=1 AND d.status='draft' ''',
  '''CREATE VIEW supplier_stock_reserved_batches AS
    SELECT batch_id,SUM(quantity) AS quantity FROM supplier_return_reservations
    WHERE batch_id IS NOT NULL GROUP BY batch_id''',
  '''CREATE TRIGGER stock_batch_keep_supplier_reservations
    BEFORE UPDATE OF remaining_quantity ON stock_batches
    WHEN NEW.remaining_quantity<COALESCE(
      (SELECT quantity FROM supplier_stock_reserved_batches WHERE batch_id=OLD.id),0)
    BEGIN SELECT RAISE(ABORT,'m54StockReservedForSupplier'); END''',
  '''CREATE TRIGGER product_keep_supplier_reservations
    BEFORE UPDATE OF stock_quantity,stock_tracking_enabled ON products
    WHEN NEW.stock_quantity<OLD.stock_quantity OR NEW.stock_tracking_enabled<>OLD.stock_tracking_enabled
    BEGIN
      SELECT RAISE(ABORT,'m54StockReservedForSupplier')
      WHERE (SELECT COALESCE(SUM(r.quantity),0)
        FROM stock_batches b JOIN supplier_stock_reserved_batches r ON r.batch_id=b.id
        WHERE b.product_id=OLD.id)>
          CASE WHEN NEW.stock_tracking_enabled=1 THEN NEW.stock_quantity ELSE 0 END;
    END''',
  '''CREATE TRIGGER supplier_reservation_epoch_insert AFTER INSERT ON supplier_return_draft_lines
    WHEN NEW.reservation_active=1 BEGIN
    UPDATE cashier_search_versions SET catalogue_epoch=catalogue_epoch+1 WHERE id=1; END''',
  '''CREATE TRIGGER supplier_reservation_epoch_update AFTER UPDATE OF reservation_active,quantity
    ON supplier_return_draft_lines WHEN OLD.reservation_active=1 OR NEW.reservation_active=1
    BEGIN UPDATE cashier_search_versions SET catalogue_epoch=catalogue_epoch+1 WHERE id=1; END''',
  '''CREATE TRIGGER supplier_reservation_epoch_delete AFTER DELETE ON supplier_return_draft_lines
    WHEN OLD.reservation_active=1 BEGIN
    UPDATE cashier_search_versions SET catalogue_epoch=catalogue_epoch+1 WHERE id=1; END''',
  '''CREATE TRIGGER supplier_reservation_epoch_close AFTER UPDATE OF status ON supplier_return_drafts
    WHEN NEW.status<>OLD.status AND EXISTS(SELECT 1 FROM supplier_return_draft_lines l
      WHERE l.draft_id=OLD.id AND l.reservation_active=1) BEGIN
    UPDATE cashier_search_versions SET catalogue_epoch=catalogue_epoch+1 WHERE id=1; END''',
];
