/// Target counters survive PIN replacement, role changes and cashier source
/// changes. They belong to the encrypted store, never a widget or preferences.
const employeeAccessSchema = [
  '''CREATE TABLE employee_access_attempts(
    target TEXT PRIMARY KEY CHECK(target IN('cashier','warehouse')),
    failures INTEGER NOT NULL DEFAULT 0 CHECK(typeof(failures)='integer' AND failures BETWEEN 0 AND 8),
    hard_locked INTEGER NOT NULL DEFAULT 0 CHECK(hard_locked IN(0,1) AND hard_locked=(failures=8)),
    blocked_until INTEGER NOT NULL DEFAULT 0 CHECK(typeof(blocked_until)='integer' AND blocked_until>=0),
    last_wall_seen INTEGER NOT NULL DEFAULT 0 CHECK(typeof(last_wall_seen)='integer' AND last_wall_seen>=0),
    credential_version TEXT CHECK(credential_version IS NULL OR length(credential_version)=64),
    revision INTEGER NOT NULL DEFAULT 0 CHECK(typeof(revision)='integer' AND revision>=0))''',
  "INSERT INTO employee_access_attempts(target) VALUES('cashier'),('warehouse')",
  // A legacy owner reference did not distinguish cashier from owner failures.
  // Retain the conservative maximum without hard-locking the owner credential.
  '''UPDATE employee_access_attempts SET
    failures=MIN(8,COALESCE((SELECT MAX(failed_attempts) FROM (
      SELECT failed_attempts FROM cashier_credentials UNION ALL
      SELECT failed_attempts FROM management_credentials)),0)),
    hard_locked=(COALESCE((SELECT MAX(failed_attempts) FROM (
      SELECT failed_attempts FROM cashier_credentials UNION ALL
      SELECT failed_attempts FROM management_credentials)),0)>=8),
    blocked_until=COALESCE((SELECT MAX(blocked_until) FROM (
      SELECT blocked_until FROM cashier_credentials UNION ALL
      SELECT blocked_until FROM management_credentials)),0),
    last_wall_seen=COALESCE((SELECT MAX(last_attempt_at) FROM (
      SELECT last_attempt_at FROM cashier_credentials UNION ALL
      SELECT last_attempt_at FROM management_credentials)),0)
    WHERE target='cashier' ''',
  '''UPDATE employee_access_attempts SET
    failures=MIN(8,COALESCE((SELECT failed_attempts FROM warehouse_credentials),0)),
    hard_locked=(COALESCE((SELECT failed_attempts FROM warehouse_credentials),0)>=8),
    blocked_until=COALESCE((SELECT blocked_until FROM warehouse_credentials),0),
    last_wall_seen=COALESCE((SELECT last_attempt_at FROM warehouse_credentials),0)
    WHERE target='warehouse' ''',
];
