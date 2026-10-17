import 'dart:convert';
import 'package:kasir_platform/kasir_platform.dart';
import '../../../data/database/database_coordinator.dart';
import '../../management/application/management_service.dart';
import '../domain/printer_profile.dart';

/// Discovery is on-demand, cancellable and bounded by Android transport timeout.
/// Forget affects only this application's binding, never system paired devices.
final class PrinterSettingsService {
  const PrinterSettingsService(
    this.database,
    this.access, {
    this.platform = const KasirPlatform(),
  });
  final DatabaseCoordinator database;
  final ManagementService access;
  final KasirPlatform platform;
  Future<bool> permission() async {
    access.requireAccess();
    return platform.call<bool>('btPermissions');
  }

  Future<List<Map<String, dynamic>>> paired() async {
    access.requireAccess();
    final rows = await platform.call<List<dynamic>>('btPaired');
    access.requireAccess();
    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> discover() async {
    access.requireAccess();
    final result = await platform.call<Map<Object?, Object?>>('btDiscover');
    access.requireAccess();
    return Map<String, dynamic>.from(result);
  }

  Future<void> cancel() => platform.channelCall('btCancelDiscovery');

  /// Explicit socket connection never sends receipt bytes or changes a sale.
  /// Android owns the bounded connect timeout; a lock while awaiting it does not
  /// grant management access when the dialog/socket operation returns.
  Future<void> connect(String device) async {
    access.requireAccess();
    if (!RegExp(r'^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$').hasMatch(device)) {
      throw const FormatException('printerDeviceInvalid');
    }
    await platform.channelCall('btConnect', {'device': device});
    try {
      access.requireAccess();
    } catch (_) {
      await platform.channelCall('btDisconnect');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    access.requireAccess();
    await platform.channelCall('btDisconnect');
  }

  Future<Map<String, dynamic>> connection() async {
    access.requireAccess();
    final result = await platform.call<Map<Object?, Object?>>('btStatus');
    access.requireAccess();
    return Map<String, dynamic>.from(result);
  }

  Future<bool> pair(String device) async {
    access.requireAccess();
    return platform.call<bool>('btPair', {'device': device});
  }

  Future<List<Map<String, Object?>>> profiles({String? after}) async {
    access.requireAccess();
    return database.read((db) async {
      access.requireAccess();
      final rows = await db.query(
        'printer_profiles',
        where: after == null ? null : 'device_id COLLATE BINARY>?',
        whereArgs: after == null ? null : [after],
        orderBy: 'device_id COLLATE BINARY',
        limit: 50,
      );
      access.requireAccess();
      return rows;
    });
  }

  Future<void> save(String device, String name, PrinterProfile profile) =>
      database.transaction((dbTxn) async {
        access.requireAccess();
        profile.validate();
        if (!RegExp(
              r'^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$',
            ).hasMatch(device) ||
            name.length > 200) {
          throw const FormatException('printerDeviceInvalid');
        }
        await dbTxn.update('printer_profiles', {
          'selected': 0,
        }, where: 'selected=1');
        final row = {
          'device_id': device,
          'name': name,
          'settings_json': jsonEncode(profile.toJson()),
          'selected': 1,
        };
        final exists = await dbTxn.query(
          'printer_profiles',
          columns: ['device_id'],
          where: 'device_id=?',
          whereArgs: [device],
        );
        if (exists.isEmpty) {
          await dbTxn.insert('printer_profiles', row);
        } else {
          await dbTxn.update(
            'printer_profiles',
            row,
            where: 'device_id=?',
            whereArgs: [device],
          );
        }
      });
  Future<void> forget(String device) => database.transaction((dbTxn) async {
    access.requireAccess();
    await dbTxn.delete(
      'printer_profiles',
      where: 'device_id=?',
      whereArgs: [device],
    );
  });
}
