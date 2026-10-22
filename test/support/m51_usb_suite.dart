import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/features/printer/application/printer_output_gate.dart';
import 'package:kasir_app/features/printer/application/printer_settings_service.dart';
import 'package:kasir_app/features/printer/application/printer_transport.dart';
import 'package:kasir_app/features/printer/domain/printer_device.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';
import 'package:kasir_app/features/printer/presentation/printer_settings_provider.dart';

/// Public descriptor/channel fixtures only: none of these tests prints paper,
/// grants OS permissions, changes system settings or touches a retained DB.
void m51UsbSuite(DatabaseFactory factory) {
  group('USB descriptor and storage fixtures', () {
    const tempId = 'usb:t:00000000-0000-0000-0000-000000000001:0';
    final serialId = 'usb:s:0483:5720:${'ab' * 32}:0';
    const bt = '00:11:22:33:44:55';
    late Directory root;
    late DatabaseCoordinator database;
    late AppServices app;
    late PrinterSettingsService service;
    final calls = <String>[];
    bool granted = false, connected = false, missing = false;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('kasir_m51_usb_');
      database = DatabaseCoordinator(
        factory: factory,
        databasePath:
            '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_0.db',
      );
      app = AppServices(database);
      await app.management.configure('PUBLIC USB fixture', '0001', '0001');
      await app.management.unlock('0001');
      service = PrinterSettingsService(
        database,
        app.management,
        outputGate: const ProcessPrinterOutputGate(),
      );
      calls.clear();
      granted = false;
      connected = false;
      missing = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(KasirPlatform.channel, (call) async {
            calls.add(call.method);
            return switch (call.method) {
              'usbDevices' =>
                missing
                    ? <Object>[]
                    : [
                        {
                          'id': tempId,
                          'name': 'PUBLIC printer',
                          'sessionOnly': true,
                          'permission': granted,
                          'transport': 'usb',
                        },
                      ],
              'usbPermission' => granted,
              'usbIdentity' =>
                missing
                    ? throw PlatformException(code: 'usb_device_missing')
                    : granted
                    ? serialId
                    : throw PlatformException(code: 'usb_permission_denied'),
              'usbConnect' =>
                missing
                    ? throw PlatformException(code: 'usb_device_missing')
                    : connected = true,
              'usbStatus' => {
                'available': true,
                'enabled': true,
                'connected': connected && !missing,
                if (connected && !missing) 'device': serialId,
              },
              'btDisconnect' || 'printerDisconnect' => connected = false,
              'printerConnect' || 'printerWrite' => true,
              _ => throw PlatformException(code: 'unexpected_public_usb_call'),
            };
          });
    });
    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(KasirPlatform.channel, null);
      await database.close();
      await factory.deleteDatabase(database.databasePath);
      await root.delete(recursive: true);
    });
    test(
      'USB identity rejects malformed, vendor paths and implicit transport guesses',
      () {
        for (final value in [bt, tempId, serialId]) {
          expect(PrinterDevice.valid(value), true);
        }
        for (final value in [
          'USB001',
          '/dev/bus/usb/001',
          '0483:5720',
          'usb:s:0483:5720:secret:0',
          '$tempId\n',
          'usb:t:x:0',
        ]) {
          expect(PrinterDevice.valid(value), false);
        }
      },
    );
    test(
      'USB enumeration and denial are read-only with no Bluetooth or output calls',
      () async {
        final before = await database.read(DatabaseValidation.fingerprint);
        final provider = PrinterSettingsProvider(service);
        try {
          await provider.selectTransport('usb');
          await provider.loadUsb();
          expect(provider.devices.length, 1);
          expect(calls, ['usbDevices', 'usbStatus']);
          await provider.connect(tempId);
          await provider.connect(tempId);
          expect(provider.message, 'm51UsbPermissionDenied');
          expect(provider.busy, false);
          expect(calls.where((c) => c == 'usbConnect'), isEmpty);
          expect(
            calls.any((c) => c.startsWith('bt') || c.contains('Write')),
            false,
          );
          expect(await database.read(DatabaseValidation.fingerprint), before);
        } finally {
          provider.dispose();
        }
      },
    );
    test(
      'USB grant canonicalizes selected profile, transport cursor and no auto print',
      () async {
        await service.save(bt, 'PUBLIC BT', const PrinterProfile(font: 18));
        granted = true;
        final provider = PrinterSettingsProvider(service);
        try {
          await provider.selectTransport('usb');
          await provider.connect(tempId);
          expect(provider.connectionStatus, 'm5Connected');
          expect(provider.connectedDevice, serialId);
          expect(
            await service.save(
              tempId,
              'PUBLIC USB',
              const PrinterProfile(font: 32),
            ),
            serialId,
          );
          final usb = await service.profiles(transport: 'usb');
          final bluetooth = await service.profiles(transport: 'bluetooth');
          expect(usb.single['transport'], 'usb');
          expect(usb.single['device_id'], serialId);
          expect(bluetooth.single['device_id'], bt);
          expect(bluetooth.single['selected'], 0);
          expect(
            await service.profiles(transport: 'usb', after: serialId),
            isEmpty,
          );
          expect(await database.read((db) => db.query('print_jobs')), isEmpty);
          expect(
            calls.any((c) => c.contains('Write') || c.startsWith('btConnect')),
            false,
          );
          missing = true;
          await provider.connect(serialId);
          expect(provider.message, 'm51UsbSelectAgain');
          expect(provider.connectedDevice, isNull);
          expect(
            (await service.profiles(transport: 'usb')).single['device_id'],
            serialId,
          );
        } finally {
          provider.dispose();
        }
      },
    );
    test(
      'late USB permission grant cannot revive a locked management session or connect',
      () async {
        final permission = Completer<bool>();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(KasirPlatform.channel, (call) async {
              calls.add(call.method);
              if (call.method == 'usbPermission') return permission.future;
              throw PlatformException(code: 'unexpected_late_usb_call');
            });
        final provider = PrinterSettingsProvider(service);
        try {
          await provider.selectTransport('usb');
          final pending = provider.connect(tempId);
          while (!calls.contains('usbPermission')) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          app.management.lock();
          permission.complete(true);
          await pending;
          expect(provider.message, 'sessionLockedEnterPinAgain');
          expect(provider.busy, false);
          expect(app.management.isUnlocked, false);
          expect(calls, ['usbPermission']);
        } finally {
          provider.dispose();
        }
      },
    );
    test(
      'USB profile cursor pages beyond 50 use the matching transport index',
      () async {
        await database.transaction((db) async {
          for (var i = 0; i < 51; i++) {
            await db.insert('printer_profiles', {
              'device_id':
                  'usb:s:0483:5720:${i.toRadixString(16).padLeft(64, '0')}:0',
              'name': 'PUBLIC $i',
              'settings_json': '{}',
              'transport': 'usb',
            });
          }
          await db.insert('printer_profiles', {
            'device_id': bt,
            'name': 'PUBLIC BT',
            'settings_json': '{}',
            'transport': 'bluetooth',
          });
        });
        final first = await service.profiles(transport: 'usb');
        final second = await service.profiles(
          transport: 'usb',
          after: first.last['device_id'] as String,
        );
        expect(first.length, 50);
        expect(second.length, 1);
        expect(
          {
            ...first.map((r) => r['device_id']),
            ...second.map((r) => r['device_id']),
          }.length,
          51,
        );
        final plan = await database.read(
          (db) => db.rawQuery(
            'EXPLAIN QUERY PLAN SELECT * FROM printer_profiles WHERE transport=? AND device_id COLLATE BINARY>? ORDER BY device_id COLLATE BINARY LIMIT 50',
            ['usb', ''],
          ),
        );
        expect(
          plan.any(
            (r) => r.values.any(
              (v) => v.toString().contains('printer_profiles_transport_cursor'),
            ),
          ),
          true,
        );
      },
    );
    test(
      'native output adapter uses one explicit transport channel without fallback on unknown write',
      () async {
        const wire = NativePrinterTransport();
        await wire.connect(tempId);
        await wire.write(Uint8List.fromList([0x1b, 0x40]));
        await wire.disconnect();
        expect(calls, ['printerConnect', 'printerWrite', 'printerDisconnect']);
        calls.clear();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(KasirPlatform.channel, (call) async {
              calls.add(call.method);
              throw PlatformException(code: 'usb_transfer_unknown');
            });
        await expectLater(
          wire.write(Uint8List.fromList([0x0a])),
          throwsA(isA<PlatformException>()),
        );
        expect(calls, ['printerWrite']);
      },
    );
    test(
      '10 to 11 migration preserves legacy Bluetooth profile and immutable tables',
      () async {
        // This case creates a second encrypted native file. USB channel fakes
        // must not intercept that factory's real Keystore bootstrap/reopen.
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(KasirPlatform.channel, null);
        final path =
            '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_1.db';
        final legacy = DatabaseCoordinator(
          factory: factory,
          databasePath: path,
          schemaVersion: 10,
        );
        await legacy.transaction(
          (db) => db.insert('printer_profiles', {
            'device_id': bt,
            'name': 'PUBLIC legacy',
            'settings_json': '{}',
            'selected': 1,
          }),
        );
        final before = await legacy.read(DatabaseValidation.fingerprint);
        await legacy.close();
        final modern = DatabaseCoordinator(
          factory: factory,
          databasePath: path,
        );
        try {
          expect(await modern.read((db) => db.getVersion()), Schema.version);
          final rows = await modern.read((db) => db.query('printer_profiles'));
          expect(rows.single, {
            'device_id': bt,
            'name': 'PUBLIC legacy',
            'settings_json': '{}',
            'selected': 1,
            'transport': 'bluetooth',
          });
          final after = await modern.read(DatabaseValidation.fingerprint);
          final original = before['tables'] as Map;
          final current = after['tables'] as Map;
          for (final table in original.keys.where(
            (e) => e != 'printer_profiles',
          )) {
            expect(current[table], original[table], reason: 'unchanged $table');
          }
          expect(
            await modern.read((db) => db.rawQuery('PRAGMA foreign_key_check')),
            isEmpty,
          );
        } finally {
          await modern.close();
          await factory.deleteDatabase(path);
        }
      },
    );
  });
}
