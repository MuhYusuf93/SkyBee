/// Refresh old popularity caches once when return-aware scoring is introduced.
const warehouseSortSchema = [
  'CREATE INDEX products_warehouse_modified ON products(is_deleted,updated_at,id COLLATE BINARY)',
  '''CREATE INDEX cashier_popularity_rank ON cashier_product_popularity(
    receipts DESC,net_quantity DESC,product_id COLLATE BINARY DESC)''',
  '''CREATE TRIGGER search_sale_epoch_return_item AFTER INSERT ON sale_return_items BEGIN
    UPDATE cashier_search_versions SET catalogue_epoch=catalogue_epoch+1,
      sale_epoch=sale_epoch+1 WHERE id=1; END''',
  'UPDATE cashier_search_versions SET catalogue_epoch=catalogue_epoch+1,sale_epoch=sale_epoch+1 WHERE id=1',
];
