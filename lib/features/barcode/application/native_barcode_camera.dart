import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/barcode_camera.dart';

/// Thin local Android adapter. Unsupported platforms and absent cameras retain
/// manual/HID entry. Native exception details and scanned payloads are not logged.
final class NativeBarcodeCamera implements BarcodeCamera {
  static const control = MethodChannel('kasir_app/barcode_camera');
  final _events = StreamController<BarcodeCameraEvent>.broadcast();
  MethodChannel? _view;
  bool _disposed = false;
  int _token = 0;
  @override
  bool get needsPlatformView => true;
  @override
  Stream<BarcodeCameraEvent> get events => _events.stream;
  Future<CameraAvailability> _availability(String method) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const CameraAvailability(available: false, permission: false);
    }
    final row = await control.invokeMapMethod<String, dynamic>(method);
    return CameraAvailability(
      available: row?['available'] == true,
      permission: row?['permission'] == true,
      cameras: row?['cameras'] is int ? row!['cameras'] as int : 0,
    );
  }

  @override
  Future<CameraAvailability> probe() => _availability('probe');
  @override
  Future<CameraAvailability> requestPermission() => _availability('permission');
  @override
  Future<void> attach(int id) async {
    if (_disposed) return;
    _view?.setMethodCallHandler(null);
    _view = MethodChannel('kasir_app/barcode_camera/$id');
    _view!.setMethodCallHandler((call) async {
      if (_disposed) return;
      if (call.method == 'decoded') {
        try {
          final row = Map<String, dynamic>.from(call.arguments as Map);
          if (row['token'] != _token) return;
          _events.add(
            BarcodeDecoded(
              BarcodeValue(row['text'] as String, row['format'] as String),
            ),
          );
        } catch (_) {
          _events.add(const BarcodeCameraFailure('m53CameraInvalidCode'));
        }
      } else if (call.method == 'error') {
        _events.add(const BarcodeCameraFailure('m53CameraUnavailable'));
      }
    });
  }

  @override
  Future<void> arm() async {
    if (!_disposed) await _view?.invokeMethod<void>('arm', {'token': ++_token});
  }

  @override
  Future<void> pause() async {
    _token++;
    try {
      await _view?.invokeMethod<void>('pause');
    } catch (_) {
      /* View may already be gone. */
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await pause();
    _view?.setMethodCallHandler(null);
    await _events.close();
  }
}
