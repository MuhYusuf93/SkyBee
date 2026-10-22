import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:workmanager/workmanager.dart';
import 'm5_live_drive_probe_app.dart' as probe;
import 'm5_post_restore_audit_test.dart' show compareBusiness;
import 'm5_acceptance_audit_test.dart' show postRestoreFinancialFacts;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real headless Google uploads retain seven and preserve cashier data',
    () async {
      probe.validate(probe.nonce);
      expect(
        await (await probe.marker(probe.nonce, 'failure')).exists(),
        false,
      );
      final setup = await probe.read(probe.nonce, 'setup');
      final result = await probe.read(probe.nonce, 'result');
      expect(result['workerPid'], isNot(setup['setupPid']));
      expect(result['workerPid'], isNot(pid));
      expect(result['verifiedUploads'], 8);
      expect(result['retainedCount'], 7);
      expect(result['duplicateCallCoalesced'], true);
      expect(result['policyUnchanged'], true);
      expect(result['oldLocalArchivesUnchanged'], true);
      expect(result['businessTablesUnchanged'], true);
      expect(result['automaticCalendarDeliveryProven'], false);
      expect(
        (await Workmanager().getWorkInfo(
          probe.taskName(probe.nonce),
        ))?.state.name,
        'succeeded',
      );
      final database = await probe.existingDatabase();
      try {
        final before = await probe.read(probe.nonce, 'checkpoint');
        final after = await database.exclusive((db) async {
          await DatabaseValidation.integrity(db);
          await postRestoreFinancialFacts(db);
          return DatabaseValidation.fingerprint(db);
        });
        compareBusiness(after, before['fingerprint'] as Map);
        expect(await probe.policyDigest(), before['policyDigest']);
        final archives = await probe.archiveDigests(database);
        for (final entry in (before['archives'] as Map).entries) {
          expect(
            archives[entry.key],
            entry.value,
            reason: 'Retained pre-probe local archive',
          );
        }
      } finally {
        await database.close();
      }
      // Only sanitized counts/booleans are returned by the shell marker reader.
      // Checkpoint/Google IDs/recovery remain in the existing isolated sandbox.
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
