/// The original payment role is an owner-only compatibility column. Store the
/// actual role separately so migration never rewrites immutable payment rows.
/// A warehouse payment can be inserted only against the first revision of the
/// invoice for the receipt currently being posted by the draft transaction.
const receiptSupplierPaymentSchema = [
  '''ALTER TABLE supplier_payments ADD COLUMN recorded_actor_role TEXT NOT NULL
    DEFAULT 'owner' CHECK(recorded_actor_role IN ('owner','warehouse'))''',
  '''CREATE TRIGGER supplier_warehouse_payment_scope BEFORE INSERT ON supplier_payments
    WHEN NEW.recorded_actor_role='warehouse' AND NOT EXISTS(
      SELECT 1 FROM supplier_invoices i
      JOIN stock_receipts r ON r.id=i.receipt_id
      JOIN receipt_drafts d ON r.operation_key='receipt-draft/'||d.id
      WHERE i.id=NEW.invoice_id AND NEW.invoice_revision=1 AND i.revision=0
      AND i.status='posted' AND i.source_mode='receipt_exact'
      AND i.actor_role='warehouse' AND i.operation_key='receipt-invoice/'||d.id
      AND d.status='draft' AND NEW.operation_key='receipt-invoice-payment/'||d.id)
    BEGIN SELECT RAISE(ABORT,'warehouse_supplier_payment_requires_receipt'); END''',
];
