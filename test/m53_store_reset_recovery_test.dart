import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:path/path.dart' as p;
import 'package:kasir_app/data/database/archive_recovery_keys.dart';
import 'package:kasir_app/data/database/key_rotation_journal.dart';
import 'package:kasir_app/features/store_reset/application/store_reset_recovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Map<String, String> secrets;
  late List<String> calls;
  late StoreResetRecovery recovery;
  late String fp;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('m53_reset_recovery_');
    calls = [];
    fp = ArchiveRecoveryKeys.fingerprint('a' * 64);
    secrets = {
      ArchiveRecoveryKeys.activeAlias: 'a' * 64,
      ArchiveRecoveryKeys.retainedAlias('old-store', fp): 'a' * 64,
      'backup-origin-v1': 'b' * 64,
      'backup-retry-v1': 'PUBLIC OLD RETRY',
      'PUBLIC-unrelated': 'KEEP',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(KasirPlatform.channel, (call) async {
          final args = call.arguments as Map;
          calls.add(call.method);
          if (call.method == 'key') {
            expect(args['create'], false);
            final value = secrets[args['name']];
            if (value == null) throw PlatformException(code: 'key_missing');
            return value;
          }
          if (call.method == 'saveSecret') {
            secrets[args['name'] as String] = args['secret'] as String;
            return true;
          }
          if (call.method == 'removeSecret') {
            secrets.remove(args['name']);
            return true;
          }
          if (call.method == 'clearResetUploadSessions') {
            expect(args['prefix'], 'drive-session-');
            return true;
          }
          if (call.method == 'syncDirectory') {
            expect(p.equals(args['path'] as String, root.path), true);
            return true;
          }
          throw StateError('Unexpected reset fixture method');
        });
    recovery = StoreResetRecovery(
      p.join(root.path, 'live.db'),
      const KasirPlatform(),
      clearBiometrics: (scope) async {
        expect(
          scope,
          sha256.convert(utf8.encode(p.join(root.path, 'live.db'))).toString(),
        );
        calls.add('appBiometrics');
      },
      resetJobs: () async {
        calls.add('jobs');
      },
    );
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(KasirPlatform.channel, null);
    await root.delete(recursive: true);
  });
  RotationOutcome outcome({bool selected = true, String operation = 'reset'}) =>
      RotationOutcome(
        selected,
        operation,
        'old-store',
        'new-store',
        backupKeyFingerprint: fp,
      );
  test(
    'rollback and same-store replace never clear old recovery consent files or jobs',
    () async {
      final original = Map.of(secrets);
      await recovery.complete(outcome(selected: false));
      await recovery.complete(outcome(operation: 'replace'));
      expect(secrets, original);
      expect(calls, isEmpty);
    },
  );
  test(
    'reset retains archive key, revokes local consent and scoped app effects, and is repeatable',
    () async {
      await recovery.complete(outcome());
      expect(secrets.containsKey(ArchiveRecoveryKeys.activeAlias), false);
      expect(
        secrets[ArchiveRecoveryKeys.retainedAlias('old-store', fp)],
        'a' * 64,
      );
      expect(secrets['PUBLIC-unrelated'], 'KEEP');
      expect(secrets.containsKey('backup-origin-v1'), false);
      expect(secrets.containsKey('backup-retry-v1'), false);
      var policy = jsonDecode(secrets['drive-policy-v1']!) as Map;
      expect(policy['enabled'], false);
      expect(policy['accountId'], isNull);
      expect(
        calls,
        containsAllInOrder([
          'clearResetUploadSessions',
          'appBiometrics',
          'jobs',
          'syncDirectory',
        ]),
      );
      await recovery.complete(outcome());
      policy = jsonDecode(secrets['drive-policy-v1']!) as Map;
      expect(policy['enabled'], false);
      expect(
        secrets[ArchiveRecoveryKeys.retainedAlias('old-store', fp)],
        'a' * 64,
      );
    },
  );
  test(
    'a conflicting retained key blocks every destructive cleanup effect',
    () async {
      secrets[ArchiveRecoveryKeys.retainedAlias('old-store', fp)] = 'b' * 64;
      final original = Map.of(secrets);
      await expectLater(recovery.complete(outcome()), throwsStateError);
      expect(secrets, original);
      expect(calls, isNot(contains('removeSecret')));
      expect(calls, isNot(contains('jobs')));
    },
  );
  test(
    'only known private staging is cleaned; backups and foreign or unknown entries survive',
    () async {
      const id = '12345678-1234-1234-1234-123456789012';
      Future<File> put(String relative) async {
        final file = File(p.join(root.path, relative));
        await file.parent.create(recursive: true);
        return file.writeAsString('PUBLIC SYNTHETIC');
      }

      final report = await put('m51_report_$id/report.csv');
      final sheet = await put('m51_report_$id/sheet1.xml');
      final restore = await put('m5_restore_$id/database.db');
      final logo = await put('logos/${'a' * 64}.png');
      final loose = await put('m5_import_$id.kasirbackup');
      final check = await put('m5_check_$id/database.db');
      final backup = await put('m5_backups/$id/$id.kasirbackup');
      final userExport = await put('user-export.csv');
      final unknown = await put(
        'm51_report_aaaaaaaa-1234-1234-1234-123456789012/unknown.txt',
      );
      final matchingWithUnknown = await put(
        'm51_report_aaaaaaaa-1234-1234-1234-123456789012/report.csv',
      );
      await recovery.complete(outcome());
      for (final f in [report, sheet, restore, check, logo, loose]) {
        expect(await f.exists(), false);
      }
      for (final f in [backup, userExport, unknown, matchingWithUnknown]) {
        expect(await f.readAsString(), 'PUBLIC SYNTHETIC');
      }
    },
  );
  test(
    'canonical alias spelling still cleans only owned transient files',
    () async {
      const id = '12345678-1234-1234-1234-123456789012';
      final report = File(p.join(root.path, 'm51_report_$id', 'report.csv'));
      await report.parent.create();
      await report.writeAsString('PUBLIC REPORT');
      final kept = File(p.join(root.path, 'PUBLIC-keep.txt'));
      await kept.writeAsString('KEEP');
      // Models an Android public app-data alias without requiring Windows
      // symlink privileges. Real native source725 reproduced the same rejection.
      await StoreResetRecovery.cleanOwnedTransientFiles(_CanonicalAlias(root));
      expect(await report.exists(), false);
      expect(await kept.readAsString(), 'KEEP');
    },
  );
}

final class _CanonicalAlias implements Directory {
  _CanonicalAlias(this.target);
  final Directory target;
  @override
  String get path => '${target.path}_public_alias';
  @override
  Directory get absolute => this;
  @override
  Future<String> resolveSymbolicLinks() => target.resolveSymbolicLinks();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected alias fixture call');
}
