import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/domain/app_error.dart';
import '../domain/barcode_camera.dart';

/// Exactly one accepted code per explicit arm. Repeated camera frames are
/// ignored; an intentional Scan again can accept the identical text again.
final class BarcodeScannerController extends ChangeNotifier {
  BarcodeScannerController({
    required this.camera,
    required this.authorize,
    required this.permission,
    required this.lookup,
  }) {
    _events = camera.events.listen(_event);
  }
  final BarcodeCamera camera;
  final Future<void> Function() authorize;
  final Future<CameraAvailability> Function(
    Future<CameraAvailability> Function(),
  )
  permission;
  final Future<BarcodeFeedback> Function(String) lookup;
  late final StreamSubscription<BarcodeCameraEvent> _events;
  bool busy = false,
      armed = false,
      previewReady = false,
      visible = true,
      attached = false;
  bool permissionPending = false, consumed = false, _disposed = false;
  int _generation = 0;
  BarcodeValue? value;
  List<BarcodeValue> choices = const [];
  BarcodeFeedback? feedback;
  String? error;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int generation) =>
      !_disposed && generation == _generation && visible;

  Future<void> prepare() async {
    if (busy || _disposed || !visible) return;
    final epoch = ++_generation;
    busy = true;
    error = null;
    armed = false;
    value = null;
    choices = const [];
    feedback = null;
    consumed = false;
    _emit();
    try {
      await authorize();
      var status = await camera.probe();
      if (!_current(epoch)) return;
      if (!status.available) throw const AppError('m53CameraUnavailable');
      if (!status.permission) {
        permissionPending = true;
        try {
          status = await permission(camera.requestPermission);
        } finally {
          permissionPending = false;
        }
      }
      if (!_current(epoch)) return;
      await authorize();
      if (!_current(epoch)) return;
      if (!status.permission) throw const AppError('m53CameraPermissionDenied');
      previewReady = true;
      if (!camera.needsPlatformView && !attached) {
        await camera.attach(0);
        attached = true;
      }
      if (attached) await _arm(epoch);
    } catch (e) {
      if (!_disposed && epoch == _generation) {
        error = e is AppError ? e.message : 'm53CameraUnavailable';
      }
    } finally {
      if (!_disposed && epoch == _generation) {
        busy = false;
        _emit();
      }
    }
  }

  Future<void> attach(int id) async {
    if (_disposed) return;
    final epoch = _generation;
    await camera.attach(id);
    attached = true;
    if (_current(epoch) && previewReady) {
      try {
        await _arm(epoch);
      } catch (_) {
        if (_current(epoch)) {
          error = 'm53CameraUnavailable';
          _emit();
        }
      }
    }
  }

  Future<void> _arm(int epoch) async {
    await authorize();
    if (!_current(epoch)) return;
    armed = true;
    consumed = false;
    await camera.arm();
    _emit();
  }

  void _event(BarcodeCameraEvent event) {
    if (_disposed || !armed || !visible) return;
    armed = false;
    unawaited(camera.pause());
    if (event is BarcodeDecoded) {
      value = event.value;
      choices = List.unmodifiable(event.value.choices);
      feedback = null;
      error = null;
    } else if (event is BarcodeCameraFailure) {
      error = event.message;
    }
    _emit();
  }

  Future<void> accept() async {
    if (_disposed || busy || value == null || consumed || !visible) return;
    final epoch = _generation, text = value!.text;
    consumed = true;
    busy = true;
    error = null;
    _emit();
    try {
      await authorize();
      if (!_current(epoch)) return;
      final result = await lookup(text);
      await authorize();
      if (_current(epoch)) feedback = result;
    } catch (e) {
      if (_current(epoch)) {
        error = e is AppError ? e.message : 'm53CameraLookupFailed';
      }
    } finally {
      if (!_disposed && epoch == _generation) {
        busy = false;
        _emit();
      }
    }
  }

  void selectCode(BarcodeValue selected) {
    if (busy || consumed || _disposed) return;
    if (!choices.any(
      (v) => v.text == selected.text && v.format == selected.format,
    )) {
      return;
    }
    value = selected;
    _emit();
  }

  /// A covered route, lock, restore or lifecycle event revokes decode intent.
  /// Resume does not rearm or authenticate; the user explicitly scans again.
  void suspend({bool inactive = false, bool clear = false}) {
    if (_disposed) return;
    if (inactive) visible = false;
    _generation++;
    if (clear) {
      value = null;
      choices = const [];
      feedback = null;
      error = 'm53CameraStoreChanged';
      previewReady = false;
      attached = false;
    }
    armed = false;
    busy = false;
    unawaited(camera.pause());
    _emit();
  }

  void resume() {
    if (!_disposed) {
      visible = true;
      _emit();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    unawaited(_events.cancel());
    unawaited(camera.dispose());
    super.dispose();
  }
}
