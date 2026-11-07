/// Master associations never alter receipt provenance or inventory valuation.
/// Keep the legacy primary supplier and add its existing association.
const productSupplierSchema = [
  '''CREATE TABLE product_suppliers(
    product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    supplier_id TEXT NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    PRIMARY KEY(product_id,supplier_id))''',
  'CREATE INDEX product_suppliers_by_supplier ON product_suppliers(supplier_id,product_id COLLATE BINARY)',
  'INSERT INTO product_suppliers SELECT id,master_supplier_id FROM products WHERE master_supplier_id IS NOT NULL',
  '''CREATE TRIGGER product_supplier_primary_insert AFTER INSERT ON products
    WHEN EXISTS(SELECT 1 FROM suppliers WHERE id=NEW.master_supplier_id) BEGIN
    INSERT INTO product_suppliers VALUES(NEW.id,NEW.master_supplier_id); END''',
  '''CREATE TRIGGER product_supplier_primary_update AFTER UPDATE OF master_supplier_id ON products
    WHEN NEW.master_supplier_id IS NOT OLD.master_supplier_id
    AND EXISTS(SELECT 1 FROM suppliers WHERE id=NEW.master_supplier_id)
    BEGIN INSERT OR IGNORE INTO product_suppliers VALUES(NEW.id,NEW.master_supplier_id); END''',
];
