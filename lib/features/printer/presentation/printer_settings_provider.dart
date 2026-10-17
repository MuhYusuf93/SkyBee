import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../application/printer_settings_service.dart';
import '../application/store_logo_service.dart';

/// Route-scoped UI discovery state; SQL, socket and permission work stay service
/// owned. Its owner can retain a pending Android dialog result behind the PIN gate.
final class PrinterSettingsProvider extends ChangeNotifier {
  PrinterSettingsProvider(this.service);
  final PrinterSettingsService service;
  File? pendingLogo;
  Uint8List? currentLogo;
  StoreLogoService get logos => StoreLogoService(
    service.database,
    service.access,
    platform: service.platform,
  );
  Future<void> chooseLogo() => run(() async {
    final file = await logos.choose();
    if (file == null) return;
    if (_disposed) {
      await file.delete();
      return;
    }
    await pendingLogo?.delete();
    pendingLogo = file;
  });
  Future<void> applyLogo() => run(() async {
    await logos.apply(pendingLogo!);
    await pendingLogo!.delete();
    pendingLogo = null;
    currentLogo = await logos.current();
    message = 'm5SettingsSaved';
  });
  Future<void> removeLogo() => run(() async {
    await logos.remove();
    currentLogo = null;
    message = 'm5SettingsSaved';
  });
  bool busy = false, scanning = false, _disposed = false;
  String? message;
  bool get permissionDenied => message == 'm5PrinterPermissionDenied';

  /// A denial is retained behind the PIN gate; never unlock or replay a
  /// protected operation when the Android permission dialog returns.
  Future<bool> _permission() async {
    if (await service.permission()) {
      if (connectionStatus == 'm5PrinterPermissionDenied') {
        connectionStatus = 'm5ConnectionNotChecked';
      }
      return true;
    }
    message = 'm5PrinterPermissionDenied';
    connectionStatus = 'm5PrinterPermissionDenied';
    connectedDevice = null;
    devices = [];
    return false;
  }

  String connectionStatus = 'm5ConnectionNotChecked';
  String? connectedDevice;
  bool _showConnection(Map<String, dynamic> value) {
    connectedDevice = value['connected'] == true
        ? value['device'] as String?
        : null;
    connectionStatus = value['available'] != true
        ? 'm5BluetoothUnavailable'
        : value['enabled'] != true
        ? 'm5BluetoothDisabled'
        : value['connected'] == true
        ? 'm5Connected'
        : 'm5Disconnected';
    return value['available'] == true && value['enabled'] == true;
  }

  Future<void> connect(String device) => run(() async {
    if (!await _permission()) return;
    try {
      if (!_showConnection(await service.connection())) return;
      connectionStatus = 'm5Connecting';
      connectedDevice = null;
      _notify();
      await service.connect(device);
      final current = await service.connection();
      _showConnection(current);
      if (current['connected'] != true || current['device'] != device) {
        throw StateError('printerConnectionNotConfirmed');
      }
    } catch (_) {
      connectionStatus = 'm5ConnectionFailed';
      connectedDevice = null;
      rethrow;
    }
  });

  Future<void> checkConnection() => run(() async {
    if (!await _permission()) return;
    _showConnection(await service.connection());
  });

  Future<void> disconnect() => run(() async {
    await service.disconnect();
    connectedDevice = null;
    connectionStatus = 'm5Disconnected';
  });
  List<Map<String, Object?>> saved = [];
  List<Map<String, dynamic>> devices = [];
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    message = null;
    _notify();
    try {
      await action();
    } catch (_) {
      message = 'm5OperationFailed';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> load({String? after}) => run(() async {
    saved = await service.profiles(after: after);
    currentLogo = await logos.current();
  });
  Future<void> discover() => run(() async {
    if (!await _permission()) return;
    // A permission dialog may lock management. The next explicit scan after
    // PIN re-entry proceeds with the granted permission, never auto-unlocks.
    scanning = true;
    _notify();
    try {
      final found = await service.discover();
      devices = (found['devices'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      message = found['cancelled'] == true
          ? 'm5ScanCancelled'
          : found['timedOut'] == true
          ? 'm5ScanTimedOut'
          : 'm5ScanFinished';
    } finally {
      scanning = false;
    }
  });
  Future<void> paired() => run(() async {
    if (!await _permission()) return;
    devices = await service.paired();
  });
  @override
  void dispose() {
    _disposed = true;
    if (pendingLogo != null) {
      unawaited(
        pendingLogo!.delete().then<void>((_) {}).catchError((Object _) {}),
      );
    }
    if (scanning) unawaited(service.cancel().catchError((Object _) {}));
    super.dispose();
  }
}
