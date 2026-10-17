import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/features/backup/application/backup_scheduler.dart';

void main() {
  setUpAll(StoreClock.new);
  test('daily target uses shop 21:00 and catches missed days once', () {
    final early = DailyBackupTarget.calculate(
      DateTime.utc(2026, 10, 16, 13),
      'Asia/Jakarta',
    );
    expect(early.due, isNull);
    expect(early.next, DateTime.utc(2026, 10, 16, 14));
    final exact = DailyBackupTarget.calculate(
      DateTime.utc(2026, 10, 16, 14),
      'Asia/Jakarta',
    );
    expect(exact.due, DateTime.utc(2026, 10, 16, 14));
    expect(exact.next, DateTime.utc(2026, 10, 17, 14));
    final missed = DailyBackupTarget.calculate(
      DateTime.utc(2026, 10, 20, 3),
      'Asia/Jakarta',
      previousTarget: DateTime.utc(2026, 10, 16, 14).millisecondsSinceEpoch,
    );
    expect(missed.due, DateTime.utc(2026, 10, 19, 14));
    expect(missed.next, DateTime.utc(2026, 10, 20, 14));
  });
  test('completed target does not repeat and next local day honors DST', () {
    final repeated = DailyBackupTarget.calculate(
      DateTime.utc(2026, 10, 16, 15),
      'Asia/Jakarta',
      previousTarget: DateTime.utc(2026, 10, 16, 14).millisecondsSinceEpoch,
      lastSuccess: DateTime.utc(2026, 10, 16, 14, 1).millisecondsSinceEpoch,
    );
    expect(repeated.due, isNull);
    final spring = DailyBackupTarget.calculate(
      DateTime.utc(2026, 3, 8, 2),
      'America/New_York',
    );
    expect(spring.next, DateTime.utc(2026, 3, 9, 1));
    final change = DailyBackupTarget.calculate(
      DateTime.utc(2026, 10, 16, 15),
      'Asia/Jakarta',
      previousTarget: DateTime.utc(2026, 10, 17, 14).millisecondsSinceEpoch,
      zoneChanged: true,
    );
    expect(change.due, DateTime.utc(2026, 10, 16, 14));
  });
}
