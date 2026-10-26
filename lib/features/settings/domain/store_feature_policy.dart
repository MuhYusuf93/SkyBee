/// The store policy describes new product creation; it is never a stock balance.
enum StockMode { off, partial, all }

/// Persisted preferences contain no credentials and never erase feature data.
final class StoreFeaturePolicy {
  const StoreFeaturePolicy({
    this.stockMode = StockMode.partial,
    this.enforced = false,
    this.taskPattern = 1,
    this.wholesale = true,
    this.packaging = true,
    this.cost = true,
    this.barcode = true,
    this.expiry = true,
    this.onboardingCompleted = true,
    this.revision = 1,
  });
  factory StoreFeaturePolicy.fromRow(Map<String, Object?> row) =>
      StoreFeaturePolicy(
        stockMode: StockMode.values.byName(row['stock_mode'] as String),
        enforced: row['policy_enforced'] == 1,
        taskPattern: row['task_pattern'] as int,
        wholesale: row['wholesale_visible'] == 1,
        packaging: row['packaging_visible'] == 1,
        cost: row['cost_visible'] == 1,
        barcode: row['barcode_visible'] == 1,
        expiry: row['expiry_visible'] == 1,
        onboardingCompleted: row['onboarding_completed'] == 1,
        revision: row['revision'] as int,
      );
  final StockMode stockMode;
  final bool enforced, wholesale, packaging, cost, barcode, expiry;
  final bool onboardingCompleted;
  final int taskPattern, revision;

  Map<String, Object?> get values => {
    'stock_mode': stockMode.name,
    'policy_enforced': enforced ? 1 : 0,
    'task_pattern': taskPattern,
    'wholesale_visible': wholesale ? 1 : 0,
    'packaging_visible': packaging ? 1 : 0,
    'cost_visible': cost ? 1 : 0,
    'barcode_visible': barcode ? 1 : 0,
    'expiry_visible': expiry ? 1 : 0,
  };
}

/// A preview counts conflicts over the full catalog, including archived rows
/// which would violate the policy when restored. Saving rechecks inside SQL.
final class StockPolicyImpact {
  const StockPolicyImpact(this.tracked, this.untracked);
  final int tracked, untracked;
  int conflicts(StockMode mode) => switch (mode) {
    StockMode.off => tracked,
    StockMode.partial => 0,
    StockMode.all => untracked,
  };
}
