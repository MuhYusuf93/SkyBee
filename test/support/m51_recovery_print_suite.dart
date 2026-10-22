import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/printer/application/printer_output_gate.dart';
import 'package:kasir_app/features/printer/application/printer_settings_service.dart';
import 'package:kasir_app/features/printer/application/print_queue_service.dart';
import 'package:kasir_app/features/printer/application/printer_transport.dart';
import 'package:kasir_app/features/printer/application/recovery_print_service.dart';
import 'package:kasir_app/features/printer/application/receipt_layout.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';
import 'm51_security_suite.dart';

/// Wire fixture retains both an observed COPY and the original view to check
/// best-effort wiping. The key and every rendered value are public test data.
final class PublicRecoveryWire implements PrinterTransport {
  PublicRecoveryWire(this.label, this.events);
  final String label;
  final List<String> events;
  final views = <Uint8List>[];
  int connections = 0, writes = 0;
  bool failConnect = false;
  int? failWrite;
  Future<void> Function()? firstWrite;
  @override
  Future<void> connect(String deviceId) async {
    events.add('$label:connect');
    connections++;
    if (failConnect) throw const SocketException('PUBLIC connect failure');
  }

  @override
  Future<void> write(Uint8List bytes) async {
    writes++;
    views.add(bytes);
    events.add('$label:write');
    if (writes == 1) await firstWrite?.call();
    if (writes == failWrite) {
      throw const SocketException('PUBLIC partial write');
    }
  }

  @override
  Future<void> disconnect() async => events.add('$label:disconnect');
}

void m51RecoveryPrintSuite(DatabaseFactory factory) {
  const publicCode =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  test(
    'dedicated recovery template round-trips 64 hex at 58/80mm without sale fields',
    () {
      for (final language in ['id', 'en']) {
        for (final profile in [
          const PrinterProfile(),
          PrinterProfile.generic80,
        ]) {
          final layout = ReceiptLayout.recovery(
            publicCode,
            profile,
            language: language,
            createdAt: DateTime.utc(2026, 10, 19),
          );
          final grouped = layout.lines
              .where((line) => RegExp(r'^[0-9a-f ]{19}$').hasMatch(line.text))
              .map((line) => line.text);
          expect(grouped.length, 4);
          expect(grouped.join().replaceAll(' ', ''), publicCode);
          expect(
            layout.lines.any((line) => line.text.contains('Hex256 / v1')),
            true,
          );
          expect(layout.lines.any((line) => line.text.endsWith('Z')), true);
          for (final line in layout.lines) {
            final painter = layout.painter(line);
            try {
              expect(
                painter.computeLineMetrics().every(
                  (m) => m.width <= profile.effectiveDots + .01,
                ),
                true,
              );
            } finally {
              painter.dispose();
            }
          }
          expect(
            layout.lines.any(
              (line) =>
                  line.text.contains('12000') ||
                  line.text.contains('HPP') ||
                  line.text.startsWith('Total:'),
            ),
            false,
          );
        }
      }
    },
  );
  group('volatile recovery output', () {
    late Directory directory;
    late DatabaseCoordinator db;
    late AppServices app;
    late RecoveryPrintService recovery;
    late PublicRecoveryWire wire;
    late PrintQueueService queue;
    late RecoveryPrintTarget selected;
    late Map<String, Object?> credentials;
    final events = <String>[];
    var nonce = 0, ticks = 1000, keyReads = 0, settingsConnections = 0;
    setUpAll(() async {
      directory = await Directory.systemTemp.createTemp('kasir_m51_recovery_');
      final seed = DatabaseCoordinator(
        factory: factory,
        databasePath: p.join(
          directory.path,
          'm5_regression_${DateTime.now().microsecondsSinceEpoch}_${nonce++}.db',
        ),
      );
      try {
        final service = AppServices(
          seed,
          biometrics: SyntheticStrongBiometrics(),
        );
        await service.management.configure(
          'PUBLIC recovery print',
          '0001',
          '0001',
        );
        credentials = Map.of(
          (await seed.read(
            (sql) => sql.query('management_credentials'),
          )).single,
        );
      } finally {
        await seed.close();
      }
    });
    setUp(() async {
      ticks = 1000;
      keyReads = 0;
      settingsConnections = 0;
      events.clear();
      db = DatabaseCoordinator(
        factory: factory,
        databasePath: p.join(
          directory.path,
          'm5_regression_${DateTime.now().microsecondsSinceEpoch}_${nonce++}.db',
        ),
      );
      app = AppServices(
        db,
        clock: StoreClock(
          now: () => DateTime.utc(2026, 10, 19),
          elapsedMilliseconds: () => ticks,
        ),
        biometrics: SyntheticStrongBiometrics(),
        printerGate: const ProcessPrinterOutputGate(),
      );
      await db.transaction(
        (sql) => sql.insert('management_credentials', credentials),
      );
      await app.management.reauthenticate('0001', 'recoveryPrint');
      await app.printers.save(
        '00:11:22:33:44:55',
        'PUBLIC printer',
        const PrinterProfile(),
      );
      wire = PublicRecoveryWire('recovery', events);
      queue = PrintQueueService(
        db,
        app.checkout,
        app.management,
        wire,
        outputGate: const ProcessPrinterOutputGate(),
      );
      recovery = RecoveryPrintService(
        db,
        app.management,
        BackupService(db, app.management),
        queue,
      );
      selected = await recovery.target();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('kasir_app/platform'), (
            call,
          ) async {
            if (call.method == 'key' &&
                call.arguments['name'] == 'backup-master-v1') {
              keyReads++;
              return publicCode;
            }
            if (call.method == 'btConnect') {
              settingsConnections++;
              return true;
            }
            if (call.method == 'btDisconnect') return true;
            throw PlatformException(
              code: 'unexpected_public_print_fixture_call',
            );
          });
    });
    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('kasir_app/platform'),
            null,
          );
      await db.close();
    });
    tearDownAll(() async {
      if (!p.isWithin(Directory.systemTemp.path, directory.path) ||
          !p.basename(directory.path).startsWith('kasir_m51_recovery_')) {
        throw StateError('Unsafe recovery fixture cleanup');
      }
      await directory.delete(recursive: true);
    });
    Future<RecoveryPrintOutcome> send() =>
        recovery.print(selected, confirmed: true, language: 'id');
    test(
      'fresh authorization and explicit confirmation precede any key read or write',
      () async {
        final before = await db.read(DatabaseValidation.fingerprint);
        await expectLater(
          recovery.print(selected, confirmed: false, language: 'id'),
          throwsA(isA<AppError>()),
        );
        await expectLater(send(), throwsA(isA<AppError>()));
        expect(keyReads, 0);
        expect(wire.connections, 0);
        expect(await db.read(DatabaseValidation.fingerprint), before);
      },
    );
    test(
      'calibration reads credential epoch after another service rotates PIN',
      () async {
        final other = AppServices(
          db,
          clock: app.management.clock,
          biometrics: SyntheticStrongBiometrics(),
        );
        await other.management.changePin('0001', '0002', '0002');
        await expectLater(queue.prepareCalibration(), throwsA(isA<AppError>()));
        expect(keyReads, 0);
        expect((await db.read((sql) => sql.query('print_jobs'))), isEmpty);
      },
    );
    test(
      'success wipes mutable buffers and persists no key job or business mutation',
      () async {
        final before = await db.read(DatabaseValidation.fingerprint);
        expect(await send(), RecoveryPrintOutcome.submitted);
        expect(keyReads, 1);
        expect(wire.writes, greaterThan(2));
        expect(wire.views.every((v) => v.every((byte) => byte == 0)), true);
        expect(await db.read(DatabaseValidation.fingerprint), before);
        await expectLater(send(), throwsA(isA<AppError>()));
        final restarted = RecoveryPrintService(
          db,
          app.management,
          BackupService(db, app.management),
          queue,
        );
        await expectLater(
          restarted.print(selected, confirmed: true, language: 'en'),
          throwsA(isA<AppError>()),
        );
        await recovery.acknowledgeStoredCopy();
        final log = await db.read(
          (sql) => sql.query(
            'audit_log',
            where: 'action=?',
            whereArgs: ['backup_recovery_copy_stored_confirmed'],
          ),
        );
        expect(log.length, 1);
        expect(log.single['entity_id'], isNull);
        expect((await db.read((sql) => sql.query('print_jobs'))), isEmpty);
      },
    );
    for (final partial in [false, true]) {
      test(
        '${partial ? 'partial write' : 'connect failure'} never retries or changes facts',
        () async {
          wire.failConnect = !partial;
          wire.failWrite = partial ? 2 : null;
          final before = await db.read(DatabaseValidation.fingerprint);
          expect(
            await send(),
            partial
                ? RecoveryPrintOutcome.unknown
                : RecoveryPrintOutcome.notSent,
          );
          expect(wire.writes, partial ? 2 : 0);
          expect(keyReads, partial ? 1 : 0);
          expect(await db.read(DatabaseValidation.fingerprint), before);
          await expectLater(send(), throwsA(isA<AppError>()));
          expect(wire.connections, 1);
        },
      );
    }
    test(
      'a changed confirmed profile is rejected before reading the code',
      () async {
        await app.printers.save(
          selected.deviceId,
          'PUBLIC changed',
          const PrinterProfile(),
        );
        final before = await db.read(DatabaseValidation.fingerprint);
        expect(await send(), RecoveryPrintOutcome.notSent);
        expect(keyReads, 0);
        expect(wire.connections, 0);
        expect(await db.read(DatabaseValidation.fingerprint), before);
      },
    );
    test('fresh proof expires while waiting for output ownership', () async {
      final lease = await const ProcessPrinterOutputGate().acquire();
      final sending = send();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      ticks += 60001;
      await lease.release();
      expect(await sending, RecoveryPrintOutcome.notSent);
      expect(keyReads, 0);
      expect(wire.writes, 0);
    });
    test(
      'ordinary calibration and settings connection cannot interleave recovery bytes',
      () async {
        final first = Completer<void>(), release = Completer<void>();
        wire.firstWrite = () async {
          first.complete();
          await release.future;
        };
        final normalWire = PublicRecoveryWire('normal', events);
        final normal = PrintQueueService(
          db,
          app.checkout,
          app.management,
          normalWire,
          outputGate: const ProcessPrinterOutputGate(),
        );
        final calibration = await normal.prepareCalibration();
        final printing = send();
        await first.future;
        final ordinary = normal.send(calibration);
        final settings = PrinterSettingsService(
          db,
          app.management,
          outputGate: const ProcessPrinterOutputGate(),
        );
        final connecting = settings.connect(selected.deviceId);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        try {
          expect(normalWire.connections, 0);
          expect(settingsConnections, 0);
          final other = RecoveryPrintService(
            db,
            app.management,
            BackupService(db, app.management),
            normal,
          );
          await expectLater(
            other.print(selected, confirmed: true, language: 'en'),
            throwsA(isA<AppError>()),
            reason: 'A fresh print proof has one consumer',
          );
        } finally {
          release.complete();
        }
        expect(await printing, RecoveryPrintOutcome.submitted);
        expect(await ordinary, 'submitted');
        await connecting;
        expect(settingsConnections, 1);
        expect(
          events.indexOf('recovery:disconnect'),
          lessThan(events.indexOf('normal:connect')),
        );
        final jobs = await db.read((sql) => sql.query('print_jobs'));
        expect(jobs.length, 1);
        expect(
          (jobs.single['snapshot_json'] as String).contains(publicCode),
          false,
        );
      },
    );
    test(
      'restore owns global output until resume and explicit lock stops sensitive output',
      () async {
        await queue.pauseForRestore();
        var started = false;
        final second = PrintQueueService(
          db,
          app.checkout,
          app.management,
          PublicRecoveryWire('second', events),
          outputGate: const ProcessPrinterOutputGate(),
        );
        final pending = second.serialOutput(() async {
          started = true;
        });
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(started, false);
        await queue.resumeAfterRestore();
        await pending;
        expect(started, true);
        wire.firstWrite = () async => app.management.lock();
        final before = await db.read(DatabaseValidation.fingerprint);
        expect(await send(), RecoveryPrintOutcome.unknown);
        expect(wire.writes, 1);
        expect(await db.read(DatabaseValidation.fingerprint), before);
      },
    );
  });
}
