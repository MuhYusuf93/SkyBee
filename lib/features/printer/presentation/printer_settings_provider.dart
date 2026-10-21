import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/domain/app_error.dart';
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
  String transport = 'bluetooth';
  bool get usb => transport == 'usb';
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
        ? usb
              ? 'm51UsbUnavailable'
              : 'm5BluetoothUnavailable'
        : value['enabled'] != true
        ? 'm5BluetoothDisabled'
        : value['connected'] == true
        ? 'm5Connected'
        : 'm5Disconnected';
    return value['available'] == true && value['enabled'] == true;
  }

  Future<void> connect(
    String device, {
    bool retryUsbPermission = false,
  }) => run(() async {
    if (usb) {
      if (!await service.usbPermission(device, retry: retryUsbPermission)) {
        message = connectionStatus = 'm51UsbPermissionDenied';
        connectedDevice = null;
        return;
      }
    } else if (!await _permission()) {
      return;
    }
    try {
      if (!_showConnection(await service.connection(transport: transport))) {
        return;
      }
      connectionStatus = 'm5Connecting';
      connectedDevice = null;
      _notify();
      await service.connect(device);
      final current = await service.connection(transport: transport);
      _showConnection(current);
      // USB may become a serial-hash identity after selected-device permission.
      if (current['connected'] != true ||
          (!usb && current['device'] != device)) {
        throw StateError('printerConnectionNotConfirmed');
      }
    } catch (_) {
      connectionStatus = 'm5ConnectionFailed';
      connectedDevice = null;
      rethrow;
    }
  });

  Future<void> checkConnection() => run(() async {
    if (!usb && !await _permission()) return;
    _showConnection(await service.connection(transport: transport));
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
    } on AppError catch (error) {
      message = error.message;
    } on PlatformException catch (error) {
      message = usb
          ? switch (error.code) {
              'usb_permission_denied' ||
              'usb_permission_unavailable' => 'm51UsbPermissionDenied',
              'usb_device_missing' ||
              'usb_device_ambiguous' => 'm51UsbSelectAgain',
              'usb_interface_busy' => 'm51UsbBusy',
              _ => 'm51UsbFailed',
            }
          : 'm5OperationFailed';
    } catch (_) {
      message = usb ? 'm51UsbFailed' : 'm5OperationFailed';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> load({String? after}) => run(() async {
    saved = await service.profiles(after: after, transport: transport);
    currentLogo = await logos.current();
  });
  Future<void> selectTransport(String value) => run(() async {
    if (!['bluetooth', 'usb'].contains(value)) return;
    transport = value;
    devices = [];
    connectedDevice = null;
    connectionStatus = 'm5ConnectionNotChecked';
    saved = await service.profiles(transport: value);
  });
  Future<void> loadUsb() => run(() async {
    devices = await service.usbDevices();
    _showConnection(await service.connection(transport: 'usb'));
    message = devices.isEmpty ? 'm51UsbEmpty' : 'm51UsbSelect';
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
