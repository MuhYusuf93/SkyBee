/// A checkout-only extension. Legacy sales keep their original reference and
/// can still be found without inventing a code during migration or reprint.
final saleReceiptCodeSchema = [
  'CREATE INDEX sale_transactions_receipt_reference ON sale_transactions(created_at,lower(substr(id,1,8)))',
  '''CREATE TABLE sale_receipt_codes(
    sale_transaction_id TEXT NOT NULL PRIMARY KEY REFERENCES sale_transactions(id) ON DELETE RESTRICT,
    store_id TEXT NOT NULL CHECK(length(store_id)=36),
    token TEXT NOT NULL UNIQUE CHECK(length(token)=22 AND substr(token,1,2)='91'
      AND token NOT GLOB '*[^0-9]*'))''',
  '''CREATE TRIGGER sale_receipt_codes_store BEFORE INSERT ON sale_receipt_codes
    WHEN NEW.store_id IS NOT (SELECT store_id FROM m5_store WHERE id=1)
    BEGIN SELECT RAISE(ABORT,'receipt_store_mismatch'); END''',
  for (final action in ['update', 'delete'])
    "CREATE TRIGGER sale_receipt_codes_no_$action BEFORE ${action.toUpperCase()} ON sale_receipt_codes BEGIN SELECT RAISE(ABORT,'immutable_fact'); END",
];
