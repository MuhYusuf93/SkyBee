import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/data/database/key_rotation_journal.dart';
import 'package:kasir_app/data/database/durable_promotion.dart';

final class MemoryRotationSecrets implements RotationSecrets {
  final values = <String, String>{
    'database-v1': '1' * 64,
    'backup-master-v1': '3' * 64,
  };
  @override
  Future<String?> read(String alias) async => values[alias];
  @override
  Future<void> write(String alias, String value) async {
    values[alias] = value;
  }

  @override
  Future<void> remove(String alias) async {
    values.remove(alias);
  }
}

void main() {
  late Directory root;
  late String path;
  late MemoryRotationSecrets secrets;
  String content(String key, String store) => jsonEncode({
    'fingerprint': KeyRotationJournal.keyFingerprint(key),
    'store': store,
  });
  Future<void> verify(String file, String key, String store) async {
    if (await File(file).readAsString() != content(key, store)) {
      throw StateError('syntheticCipherMismatch');
    }
  }

  Future<void> after(RotationOutcome outcome) async {
    if (outcome.newSelected && outcome.operation == 'reset') {
      final code = secrets.values['backup-master-v1'];
      if (code != null) {
        secrets.values['retained-backup'] = code;
        secrets.values.remove('backup-master-v1');
      }
      secrets.values['drive-consent'] = 'off';
    }
  }

  KeyRotationJournal journal({String? crash, RotationVerifier? validator}) =>
      KeyRotationJournal(
        path,
        'database-v1',
        secrets,
        validator ?? verify,
        afterSelection: after,
        testPhase: crash == null
            ? null
            : (phase) async {
                if (phase == crash) throw StateError('syntheticCrash:$phase');
              },
      );
  Future<PreparedRotation> prepare(
    KeyRotationJournal j, {
    String operation = 'reset',
    String newStore = 'new-store',
  }) => j.prepare(
    newKey: '2' * 64,
    oldStore: 'old-store',
    newStore: newStore,
    operation: operation,
    backupKeyFingerprint: KeyRotationJournal.keyFingerprint('3' * 64),
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('kasir_rotation_draft_');
    path = '${root.path}/live.db';
    secrets = MemoryRotationSecrets();
    await File(path).writeAsString(content('1' * 64, 'old-store'), flush: true);
    await File(
      '$path.incoming',
    ).writeAsString(content('2' * 64, 'new-store'), flush: true);
  });
  tearDown(() async => root.delete(recursive: true));
  final newPhases = {
    'promotion:committed',
    'defaultAlias',
    'selected',
    'postSelection',
    'oldShadowRemoved',
    'newShadowRemoved',
    'journalRemoved',
    'witnessRemoved',
  };
  for (final phase in [
    'oldShadow',
    'newShadow',
    'witness',
    'prepared',
    'promotion:journal',
    'promotion:oldMoved',
    'promotion:newMoved',
    'verifiedNew',
    ...newPhases,
  ]) {
    test('recover key and file together after $phase', () async {
      PreparedRotation? intent;
      final j = journal(crash: phase);
      await expectLater(() async {
        intent = await prepare(j);
        await j.promote(intent!);
      }, throwsStateError);
      await journal().recover();
      final selectedNew = newPhases.contains(phase),
          key = (selectedNew ? '2' : '1') * 64;
      await verify(
        path,
        secrets.values['database-v1']!,
        selectedNew ? 'new-store' : 'old-store',
      );
      expect(secrets.values['database-v1'], key);
      expect(await journal().recover(), isNull);
      if (selectedNew) {
        expect(secrets.values['retained-backup'], '3' * 64);
        expect(secrets.values.containsKey('backup-master-v1'), false);
      } else {
        expect(secrets.values['backup-master-v1'], '3' * 64);
        expect(secrets.values['drive-consent'], isNull);
      }
      if (intent != null) {
        expect((await journal().resolve(intent!)).newSelected, selectedNew);
      }
      if (await File(j.journalPath).exists()) {
        final public = await File(j.journalPath).readAsString();
        expect(public, isNot(contains('1' * 64)));
        expect(public, isNot(contains('2' * 64)));
      }
    });
  }
  test(
    'public intent contains no raw keys and nonce substitution is rejected before cleanup',
    () async {
      final j = journal();
      await prepare(j);
      final original = await File(j.journalPath).readAsString();
      expect(original, isNot(contains('1' * 64)));
      expect(original, isNot(contains('2' * 64)));
      final r = jsonDecode(original) as Map<String, dynamic>;
      r['nonce'] = 'a' * 32;
      await File(j.journalPath).writeAsString(jsonEncode(r));
      final aliases = Map.of(secrets.values),
          old = await File(path).readAsString();
      await expectLater(journal().recover(), throwsStateError);
      expect(secrets.values, aliases);
      expect(await File(path).readAsString(), old);
      await File(j.journalPath).writeAsString(original);
      expect((await journal().recover())!.newSelected, false);
    },
  );
  test(
    'prepared default key is never accepted when the selected shadow is missing',
    () async {
      final j = journal();
      await prepare(j);
      final r = jsonDecode(await File(j.journalPath).readAsString()) as Map;
      secrets.values.remove('rotation-${r['nonce']}-old');
      await expectLater(journal().recover(), throwsStateError);
      await verify(path, '1' * 64, 'old-store');
      expect(secrets.values['database-v1'], '1' * 64);
    },
  );
  test(
    'selected default fallback remains recoverable after new shadow removal',
    () async {
      final j = journal(crash: 'newShadowRemoved');
      final intent = await prepare(j);
      await expectLater(j.promote(intent), throwsStateError);
      final remaining = secrets.values.keys.where(
        (k) => k.startsWith('rotation-') && !k.startsWith('rotation-meta-'),
      );
      expect(remaining, isEmpty);
      expect((await journal().recover())!.newSelected, true);
      await verify(path, secrets.values['database-v1']!, 'new-store');
    },
  );
  test(
    'missing witness or unknown live hash fails closed without deleting source or aliases',
    () async {
      final j = journal();
      await prepare(j);
      final original = await File(path).readAsString(),
          aliases = Map.of(secrets.values);
      await File(path).writeAsString('UNRECOGNIZED SYNTHETIC BYTES');
      await expectLater(journal().recover(), throwsStateError);
      expect(secrets.values, aliases);
      await File(path).writeAsString(original);
      secrets.values.removeWhere((k, _) => k.startsWith('rotation-meta-'));
      final afterMissing = Map.of(secrets.values);
      await expectLater(journal().recover(), throwsStateError);
      expect(secrets.values, afterMissing);
    },
  );
  test(
    'failed readonly staging verifier cannot promote or replace current key',
    () async {
      final before = await DurablePromotion.digest(File(path));
      final j = journal(
        validator: (file, key, store) async {
          await verify(file, key, store);
          if (file.endsWith('.incoming')) {
            await File(file).writeAsString('CHANGED STAGE');
          }
        },
      );
      await expectLater(prepare(j), throwsStateError);
      expect(await DurablePromotion.digest(File(path)), before);
      expect(secrets.values['database-v1'], '1' * 64);
      expect(await File(j.journalPath).exists(), false);
    },
  );
  test(
    'rollback selection cleanup can resume after its staged file was deleted',
    () async {
      await prepare(journal());
      await expectLater(
        journal(crash: 'stageRemoved').recover(),
        throwsStateError,
      );
      expect((await journal().recover())!.newSelected, false);
      expect(await File('$path.incoming').exists(), false);
      await verify(path, '1' * 64, 'old-store');
    },
  );
  test(
    'reset without a cleanup handler remains selected but blocked until cleanup is supplied',
    () async {
      final j = KeyRotationJournal(path, 'database-v1', secrets, verify);
      final intent = await prepare(j);
      await expectLater(j.promote(intent), throwsStateError);
      await expectLater(j.recover(), throwsStateError);
      expect(await File(j.journalPath).exists(), true);
      expect(secrets.values['backup-master-v1'], '3' * 64);
      expect((await journal().recover())!.newSelected, true);
      expect(secrets.values['retained-backup'], '3' * 64);
    },
  );
  test(
    'same-store replace rotates actual key without clearing active app configuration',
    () async {
      await File(
        '$path.incoming',
      ).writeAsString(content('2' * 64, 'old-store'));
      final j = journal(),
          intent = await prepare(
            j,
            operation: 'replace',
            newStore: 'old-store',
          );
      expect((await j.promote(intent)).newSelected, true);
      expect(secrets.values['backup-master-v1'], '3' * 64);
      expect(secrets.values['drive-consent'], isNull);
      await verify(path, '2' * 64, 'old-store');
    },
  );
}
