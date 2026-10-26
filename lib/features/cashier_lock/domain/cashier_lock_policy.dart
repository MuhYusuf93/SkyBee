enum CashierPinSource { owner, cashier }

/// Owner-controlled gate settings, not an employee identity or a management
/// session. A disabled gate stays compatible with every existing cashier flow.
final class CashierLockPolicy {
  const CashierLockPolicy({
    this.enabled = false,
    this.screenLock = false,
    this.source = CashierPinSource.owner,
    this.revision = 1,
    this.epoch = 0,
  });
  final bool enabled, screenLock;
  final CashierPinSource source;
  final int revision, epoch;
  factory CashierLockPolicy.fromRow(Map<String, Object?> row) =>
      CashierLockPolicy(
        enabled: row['enabled'] == 1,
        screenLock: row['screen_lock'] == 1,
        source: CashierPinSource.values.byName(row['pin_source'] as String),
        revision: row['revision'] as int,
        epoch: row['gate_epoch'] as int,
      );
}
