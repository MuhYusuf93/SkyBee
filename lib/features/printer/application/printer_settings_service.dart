import 'dart:convert';
import 'package:kasir_platform/kasir_platform.dart';
import '../../../data/database/database_coordinator.dart';
import '../../management/application/management_service.dart';
import '../domain/printer_profile.dart';
import '../domain/printer_device.dart';
import 'printer_output_gate.dart';

/// Discovery is on-demand, cancellable and bounded by Android transport timeout.
/// Forget affects only this application's binding, never system paired devices.
final class PrinterSettingsService {
  const PrinterSettingsService(
    this.database,
    this.access, {
    this.platform = const KasirPlatform(),
    this.outputGate,
  });
  final DatabaseCoordinator database;
  final ManagementService access;
  final KasirPlatform platform;
  final PrinterOutputGate? outputGate;
  Future<bool> permission() async {
    await access.authorizeCurrent();
    return access.systemInteraction(() => platform.call<bool>('btPermissions'));
  }

  Future<List<Map<String, dynamic>>> paired() async {
    await access.authorizeCurrent();
    final rows = await platform.call<List<dynamic>>('btPaired');
    await access.authorizeCurrent();
    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> discover() async {
    await access.authorizeCurrent();
    final result = await platform.call<Map<Object?, Object?>>('btDiscover');
    await access.authorizeCurrent();
    return Map<String, dynamic>.from(result);
  }

  Future<void> cancel() => platform.channelCall('btCancelDiscovery');

  /// Enumeration does not ask permission or open/send to a USB interface.
  Future<List<Map<String, dynamic>>> usbDevices() async {
    await access.authorizeCurrent();
    final rows = await platform.call<List<dynamic>>('usbDevices');
    await access.authorizeCurrent();
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<bool> usbPermission(String device, {bool retry = false}) async {
    await access.authorizeCurrent();
    if (!PrinterDevice.valid(device) ||
        PrinterDevice.transport(device) != 'usb') {
      throw const FormatException('printerDeviceInvalid');
    }
    return access.systemInteraction(
      () => platform.call<bool>('usbPermission', {
        'device': device,
        'retry': retry,
      }),
    );
  }

  /// Explicit socket connection never sends receipt bytes or changes a sale.
  /// Android owns the bounded connect timeout; a lock while awaiting it does not
  /// grant management access when the dialog/socket operation returns.
  Future<void> connect(String device) =>
      withPrinterOutput(outputGate ?? defaultPrinterOutputGate(), () async {
        await access.authorizeCurrent();
        if (!PrinterDevice.valid(device)) {
          throw const FormatException('printerDeviceInvalid');
        }
        await platform.channelCall(
          PrinterDevice.transport(device) == 'usb' ? 'usbConnect' : 'btConnect',
          {'device': device},
        );
        try {
          await access.authorizeCurrent();
        } catch (_) {
          await platform.channelCall('btDisconnect');
          rethrow;
        }
      });

  Future<void> disconnect() =>
      withPrinterOutput(outputGate ?? defaultPrinterOutputGate(), () async {
        await access.authorizeCurrent();
        await platform.channelCall('btDisconnect');
      });

  Future<Map<String, dynamic>> connection({
    String transport = 'bluetooth',
  }) async {
    await access.authorizeCurrent();
    final result = await platform.call<Map<Object?, Object?>>(
      transport == 'usb' ? 'usbStatus' : 'btStatus',
    );
    await access.authorizeCurrent();
    return Map<String, dynamic>.from(result);
  }

  Future<bool> pair(String device) async {
    await access.authorizeCurrent();
    return access.systemInteraction(
      () => platform.call<bool>('btPair', {'device': device}),
    );
  }

  Future<List<Map<String, Object?>>> profiles({
    String? after,
    String? transport,
  }) async {
    access.requireAccess();
    return database.read((db) async {
      await access.authorize(db);
      // Legacy host fixtures may deliberately open an older schema. USB is
      // available only after migration; old Bluetooth profiles remain readable.
      final modern =
          ((await db.rawQuery('PRAGMA user_version')).single.values.single
              as int) >=
          11;
      if (!modern && transport == 'usb') return [];
      if (transport != null && !['bluetooth', 'usb'].contains(transport)) {
        throw const FormatException('printerTransportInvalid');
      }
      final rows = await db.query(
        'printer_profiles',
        where: [
          if (modern && transport != null) 'transport=?',
          if (after != null) 'device_id COLLATE BINARY>?',
        ].join(' AND ').emptyToNull,
        whereArgs: [if (modern && transport != null) transport, ?after],
        orderBy: 'device_id COLLATE BINARY',
        limit: 50,
      );
      await access.authorize(db);
      return rows;
    });
  }

  Future<String> save(
    String device,
    String name,
    PrinterProfile profile,
  ) async {
    await access.authorizeCurrent();
    if (!PrinterDevice.valid(device) ||
        name.runes.length > 200 ||
        name.contains('\u0000')) {
      throw const FormatException('printerDeviceInvalid');
    }
    final transport = PrinterDevice.transport(device);
    // Selected attachment may acquire its serial identity after OS permission.
    // Resolve outside SQL; a USB dialog never holds a database transaction.
    final identity = transport == 'usb'
        ? await platform.call<String>('usbIdentity', {'device': device})
        : device;
    if (!PrinterDevice.valid(identity) ||
        PrinterDevice.transport(identity) != transport) {
      throw const FormatException('printerDeviceInvalid');
    }
    return database.transaction((dbTxn) async {
      await access.authorize(dbTxn);
      profile.validate();
      final modern =
          (await dbTxn.rawQuery('PRAGMA user_version')).single.values.single
              as int >=
          11;
      if (!modern && transport == 'usb') {
        throw const FormatException('printerTransportInvalid');
      }
      await dbTxn.update('printer_profiles', {
        'selected': 0,
      }, where: 'selected=1');
      final row = {
        'device_id': identity,
        if (modern) 'transport': transport,
        'name': name,
        'settings_json': jsonEncode(profile.toJson()),
        'selected': 1,
      };
      final exists = await dbTxn.query(
        'printer_profiles',
        columns: ['device_id'],
        where: 'device_id=?',
        whereArgs: [identity],
      );
      if (exists.isEmpty) {
        await dbTxn.insert('printer_profiles', row);
      } else {
        await dbTxn.update(
          'printer_profiles',
          row,
          where: 'device_id=?',
          whereArgs: [identity],
        );
      }
      await access.authorize(dbTxn);
      return identity;
    });
  }

  Future<void> forget(String device) => database.transaction((dbTxn) async {
    await access.authorize(dbTxn);
    await dbTxn.delete(
      'printer_profiles',
      where: 'device_id=?',
      whereArgs: [device],
    );
  });
}

extension on String {
  String? get emptyToNull => isEmpty ? null : this;
}
