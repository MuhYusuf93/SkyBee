import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'support/m53_retention_host_fixture.dart';

/// Opaque host archive fails before cipher open: these cases prove exclusion,
/// candidate release and stale authority, not archive authentication.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late RetentionHostFixture f;
  late _SerialWorkGate gate;
  late BackupService service;
  setUp(() async {
    f = RetentionHostFixture();
    await f.initialize();
    gate = _SerialWorkGate();
    service = BackupService(
      f.database,
      f.app.management,
      workGate: gate,
      availableBytes: (_) async => 134217728,
    );
  });
  tearDown(() => f.dispose());
  test(
    'inspection holds backup-work through unpack and failure releases its candidate without reentry',
    () async {
      final manifest = await f.add(0), archive = f.archive(manifest);
      final entered = Completer<void>(), release = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(KasirPlatform.channel, (call) async {
            final args = call.arguments as Map;
            if (call.method == 'key') {
              final value = f.secrets[args['name']];
              if (value == null) throw PlatformException(code: 'key_missing');
              return value;
            }
            if (call.method == 'saveSecret') {
              f.secrets[args['name'] as String] = args['secret'] as String;
              return true;
            }
            if (call.method == 'unpackArchive') {
              expect(gate.active, 1);
              entered.complete();
              await release.future;
              throw PlatformException(code: 'PUBLIC_SYNTHETIC_AUTH_FAILURE');
            }
            throw StateError('Unexpected host inspection operation');
          });
      final inspection = service.inspect(archive, 'a' * 64);
      final failure = expectLater(
        inspection,
        throwsA(isA<PlatformException>()),
      );
      await entered.future.timeout(const Duration(seconds: 10));
      var resetEntered = false;
      final queuedReset = gate.run(() async {
        resetEntered = true;
      });
      await Future<void>.value();
      expect(resetEntered, false);
      final scope = await f.retention.localScope();
      expect(
        (await f.retention.metadata.proof(
          scope,
          manifest.id,
        ))!.candidates.length,
        1,
      );
      release.complete();
      await failure.timeout(const Duration(seconds: 10));
      await queuedReset;
      expect(resetEntered, true);
      expect(gate.active, 0);
      expect(
        (await f.retention.metadata.proof(scope, manifest.id))!.candidates,
        isEmpty,
      );
      expect(await archive.exists(), true);
    },
  );
  test(
    'inspection queued before a new unlock cannot adopt that new owner grant',
    () async {
      final manifest = await f.add(0), archive = f.archive(manifest);
      final entered = Completer<void>(), release = Completer<void>();
      final holding = gate.run(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final pending = service.inspect(archive, 'a' * 64);
      final failure = expectLater(pending, throwsStateError);
      f.app.management.lock();
      await f.app.management.unlock('0001');
      release.complete();
      await holding;
      await failure;
      expect(await archive.exists(), true);
    },
  );
}

final class _SerialWorkGate implements DatabaseGate {
  Future<void> _tail = Future.value();
  int active = 0;
  @override
  Future<T> run<T>(Future<T> Function() action) {
    final result = _tail.then((_) async {
      active++;
      try {
        return await action();
      } finally {
        active--;
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
