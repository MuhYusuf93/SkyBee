import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:kasir_app/data/database/archive_recovery_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, String> values;
  late ArchiveRecoveryKeys keys;
  final removed = <String>[];
  setUp(() {
    values = {
      'backup-master-v1': 'a' * 64,
      'unrelated-owner-alias': 'PUBLIC KEEP',
    };
    removed.clear();
    keys = const ArchiveRecoveryKeys(KasirPlatform());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(KasirPlatform.channel, (call) async {
          final args = call.arguments as Map;
          final name = args['name'] as String;
          if (call.method == 'key') {
            expect(args['create'], false);
            if (!values.containsKey(name)) {
              throw PlatformException(code: 'key_missing');
            }
            return values[name];
          }
          if (call.method == 'saveSecret') {
            values[name] = args['secret'] as String;
            return true;
          }
          if (call.method == 'removeSecret') {
            removed.add(name);
            values.remove(name);
            return true;
          }
          throw StateError('Unexpected recovery fixture operation');
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(KasirPlatform.channel, null),
  );
  test(
    'retain verifies archived key before clearing active, preserving unrelated aliases',
    () async {
      final fp = await keys.retainConfigured('old-store');
      final alias = ArchiveRecoveryKeys.retainedAlias('old-store', fp!);
      expect(values[alias], 'a' * 64);
      expect(await keys.available('old-store', fp), true);
      await keys.clearActiveAfterRetention('old-store', fp);
      expect(values['backup-master-v1'], isNull);
      expect(values[alias], 'a' * 64);
      expect(values['unrelated-owner-alias'], 'PUBLIC KEEP');
      expect(removed, ['backup-master-v1']);
      expect(await keys.available('old-store', fp), true);
      await keys.clearActiveAfterRetention('old-store', fp);
      expect(values[alias], 'a' * 64);
      expect(alias.length + 31, lessThanOrEqualTo(96));
    },
  );
  test(
    'missing active code is not created and unknown key stays unavailable',
    () async {
      values.remove('backup-master-v1');
      expect(await keys.retainConfigured('old-store'), isNull);
      expect(await keys.available('old-store', 'b' * 64), false);
      await expectLater(
        keys.clearActiveAfterRetention('old-store', 'b' * 64),
        throwsStateError,
      );
      expect(removed, isEmpty);
    },
  );
  test(
    'a changed active recovery code cannot be silently cleared by stale reset',
    () async {
      final fp = (await keys.retainConfigured('old-store'))!;
      values['backup-master-v1'] = 'b' * 64;
      await expectLater(
        keys.clearActiveAfterRetention('old-store', fp),
        throwsStateError,
      );
      expect(values['backup-master-v1'], 'b' * 64);
      expect(removed, isEmpty);
    },
  );
  test(
    'malformed or conflicting retained aliases never destroy current recovery',
    () async {
      final fp = ArchiveRecoveryKeys.fingerprint('a' * 64),
          alias = ArchiveRecoveryKeys.retainedAlias(
            'old-store',
            ArchiveRecoveryKeys.fingerprint('a' * 64),
          );
      values[alias] = 'b' * 64;
      await expectLater(keys.retainConfigured('old-store'), throwsStateError);
      await expectLater(
        keys.clearActiveAfterRetention('old-store', fp),
        throwsStateError,
      );
      expect(values[alias], 'b' * 64);
      expect(values['backup-master-v1'], 'a' * 64);
      expect(removed, isEmpty);
      values['backup-master-v1'] = 'malformed';
      await expectLater(
        keys.clearActiveAfterRetention('old-store', fp),
        throwsStateError,
      );
      expect(removed, isEmpty);
    },
  );
  test(
    'new unexpected active recovery prevents cleanup with an empty old-key declaration',
    () async {
      await expectLater(
        keys.clearActiveAfterRetention('old-store', null),
        throwsStateError,
      );
      expect(values['backup-master-v1'], 'a' * 64);
      expect(removed, isEmpty);
    },
  );
}
