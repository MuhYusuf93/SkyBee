import '../../core/domain/warranty_term.dart';

/// Old products and sales have no recorded warranty. Migration must not infer
/// a past term from current product settings, or rewrite printed receipts.
const saleWarrantySchema = [
  '''ALTER TABLE store_feature_policy ADD COLUMN warranty_visible INTEGER NOT NULL
  DEFAULT 0 CHECK(typeof(warranty_visible)='integer' AND warranty_visible IN (0,1))''',
  '''ALTER TABLE products ADD COLUMN warranty_months INTEGER CHECK(warranty_months IS NULL OR
    (typeof(warranty_months)='integer' AND warranty_months BETWEEN 1 AND ${WarrantyTerm.maxMonths}))''',
  '''ALTER TABLE sale_transaction_items ADD COLUMN warranty_months_snapshot INTEGER
    CHECK(warranty_months_snapshot IS NULL OR (typeof(warranty_months_snapshot)='integer' AND
      warranty_months_snapshot BETWEEN 1 AND ${WarrantyTerm.maxMonths}))''',
  'ALTER TABLE sale_transaction_items ADD COLUMN warranty_started_on TEXT',
  'ALTER TABLE sale_transaction_items ADD COLUMN warranty_until TEXT',
  '''ALTER TABLE sale_transaction_items ADD COLUMN warranty_time_zone TEXT CHECK(
    (warranty_months_snapshot IS NULL AND warranty_started_on IS NULL AND
     warranty_until IS NULL AND warranty_time_zone IS NULL) OR
    (warranty_months_snapshot IS NOT NULL AND warranty_started_on IS NOT NULL AND
     warranty_until IS NOT NULL AND warranty_time_zone IS NOT NULL AND
     length(warranty_started_on)=10 AND length(warranty_until)=10 AND
     warranty_until>=warranty_started_on AND length(warranty_time_zone) BETWEEN 1 AND 64))''',
];
