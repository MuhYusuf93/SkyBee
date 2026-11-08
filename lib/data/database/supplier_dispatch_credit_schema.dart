/// Preserve credit IDs and every dependent ledger row. Only the origin column
/// is replaced, so the original FK to an actual supplier return stays optional
/// beside the new FK to an actual dispatch. The migration keeps FK enforcement.
const supplierDispatchCreditSchema = [
  'DROP TRIGGER supplier_credits_update',
  'DROP TRIGGER supplier_credit_single_active',
  'DROP INDEX supplier_credits_return',
  'ALTER TABLE supplier_credits RENAME COLUMN return_id TO legacy_return_id',
  '''ALTER TABLE supplier_credits ADD COLUMN return_id TEXT
    REFERENCES supplier_returns(id) ON DELETE RESTRICT''',
  'UPDATE supplier_credits SET return_id=legacy_return_id',
  'ALTER TABLE supplier_credits DROP COLUMN legacy_return_id',
  '''ALTER TABLE supplier_credits ADD COLUMN dispatch_id TEXT
    REFERENCES supplier_return_dispatches(id) ON DELETE RESTRICT
    CHECK((return_id IS NOT NULL)+(dispatch_id IS NOT NULL)=1)''',
  'CREATE INDEX supplier_credits_return ON supplier_credits(return_id,id)',
  'CREATE INDEX supplier_credits_dispatch ON supplier_credits(dispatch_id,id) WHERE dispatch_id IS NOT NULL',
  '''CREATE TRIGGER supplier_credits_update BEFORE UPDATE ON supplier_credits
    BEGIN SELECT RAISE(ABORT,'immutable_supplier_credit'); END''',
  '''CREATE TRIGGER supplier_credit_single_active BEFORE INSERT ON supplier_credits
    WHEN (NEW.return_id IS NOT NULL AND (
      EXISTS(SELECT 1 FROM supplier_return_reversals v WHERE v.return_id=NEW.return_id) OR
      EXISTS(SELECT 1 FROM supplier_credits c WHERE c.return_id=NEW.return_id
        AND NOT EXISTS(SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=c.id))
    )) OR (NEW.dispatch_id IS NOT NULL AND (
      NEW.approved_invoice_id IS NOT NULL OR
      NOT EXISTS(SELECT 1 FROM supplier_return_dispatches d
        JOIN supplier_return_preparations p ON p.id=d.preparation_id
        WHERE d.id=NEW.dispatch_id AND d.credit_claim_minor>0
          AND p.supplier_id=NEW.supplier_id AND p.currency_code=NEW.currency_code
          AND p.currency_scale=NEW.currency_scale
          AND NOT EXISTS(SELECT 1 FROM supplier_return_dispatch_reversals v WHERE v.dispatch_id=d.id)) OR
      EXISTS(SELECT 1 FROM supplier_credits c WHERE c.dispatch_id=NEW.dispatch_id
        AND NOT EXISTS(SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=c.id))
    ))
    BEGIN SELECT RAISE(ABORT,'supplier_credit_already_approved'); END''',
  '''CREATE TRIGGER supplier_dispatch_reverse_credit_guard
    BEFORE INSERT ON supplier_return_dispatch_reversals
    WHEN EXISTS(SELECT 1 FROM supplier_credits c WHERE c.dispatch_id=NEW.dispatch_id
      AND NOT EXISTS(SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=c.id))
    BEGIN SELECT RAISE(ABORT,'supplier_dispatch_has_credit'); END''',
];
