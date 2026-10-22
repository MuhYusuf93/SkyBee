/// Shared validation of a debug-only preflight proof. A scoped recovery never
/// claims byte-for-byte equality for counters which a verified worker advanced.
final class SkybeeUpgradeProof {
  static const counterColumns = {
    'm5_store.alert_generation',
    'alert_state.evaluation',
  };

  static bool isComplete(Object? value, int targetVersion) {
    if (value is! Map ||
        value['status'] != 'complete' ||
        value['toVersion'] != targetVersion) {
      return false;
    }
    if (value['allExistingFactsMatch'] == true) return true;
    final recovery = value['derivedAlertMetadata'];
    if (value['allExistingBusinessFactsMatch'] != true || recovery is! Map) {
      return false;
    }
    final columns = recovery['columns'];
    return columns is List &&
        columns.length == counterColumns.length &&
        columns.toSet().containsAll(counterColumns) &&
        recovery['sourceSnapshotMatchesPreparedProof'] == true &&
        recovery['monotonicCountersOnly'] == true &&
        recovery['rowSetsUnchanged'] == true &&
        recovery['otherOldColumnsMatch'] == true;
  }
}
