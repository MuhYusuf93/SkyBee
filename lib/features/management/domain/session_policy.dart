/// Persisted convenience choice; cashier/drafts never require this capability.
enum SessionPolicy {
  legacy,
  oneMinute,
  fiveMinutes,
  fifteenMinutes,
  immediate;

  String get code => switch (this) {
    legacy => 'legacy',
    oneMinute => '1m',
    fiveMinutes => '5m',
    fifteenMinutes => '15m',
    immediate => 'immediate',
  };
  Duration get idle => switch (this) {
    legacy || fiveMinutes || immediate => const Duration(minutes: 5),
    oneMinute => const Duration(minutes: 1),
    fifteenMinutes => const Duration(minutes: 15),
  };
  bool get lockOnBackground => this == legacy || this == immediate;
  static SessionPolicy fromCode(String code) =>
      values.firstWhere((p) => p.code == code);
}

/// A system dialog is a bounded operation, never a remembered unlock. Full
/// external activities still require fresh PIN on return in immediate mode.
final class SystemInteraction {
  const SystemInteraction(
    this.id,
    this.generation,
    this.deadline,
    this.authentication,
  );
  final int id, generation, deadline;
  final bool authentication;
}
