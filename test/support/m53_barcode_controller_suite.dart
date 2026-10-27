import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/features/barcode/domain/barcode_camera.dart';
import 'package:kasir_app/features/barcode/presentation/barcode_scanner_controller.dart';

/// Test transport only. Its frames are synthetic; they are not evidence that a
/// physical device camera recognized a printed barcode.
final class SyntheticBarcodeCamera implements BarcodeCamera {
  CameraAvailability status = const CameraAvailability(
    available: true,
    permission: true,
    cameras: 1,
  );
  int arms = 0, pauses = 0;
  bool disposed = false;
  Completer<CameraAvailability>? pendingPermission;
  final stream = StreamController<BarcodeCameraEvent>.broadcast(sync: true);
  @override
  bool get needsPlatformView => false;
  @override
  Stream<BarcodeCameraEvent> get events => stream.stream;
  @override
  Future<CameraAvailability> probe() async => status;
  @override
  Future<CameraAvailability> requestPermission() async =>
      pendingPermission == null ? status : await pendingPermission!.future;
  @override
  Future<void> attach(int id) async {}
  @override
  Future<void> arm() async {
    arms++;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await stream.close();
  }

  void frame(String text, [String format = 'CODE_128']) =>
      stream.add(BarcodeDecoded(BarcodeValue(text, format)));
}

void m53BarcodeControllerSuite() {
  test(
    'M53 barcode EAN13 leading zero remains default; UPC equivalent requires explicit choice before one confirmation',
    () async {
      final camera = SyntheticBarcodeCamera(), codes = <String>[];
      final controller = BarcodeScannerController(
        camera: camera,
        authorize: () async {},
        permission: (a) => a(),
        lookup: (code) async {
          codes.add(code);
          return const BarcodeFeedback('m53CameraAdded', success: true);
        },
      );
      await controller.prepare();
      camera.frame('0123456789012', 'EAN_13');
      expect(controller.value!.text, '0123456789012');
      expect(controller.choices.map((v) => v.text), [
        '0123456789012',
        '123456789012',
      ]);
      controller.selectCode(controller.choices.last);
      expect(codes, isEmpty);
      await controller.accept();
      controller.selectCode(controller.choices.first);
      await controller.accept();
      expect(codes, ['123456789012']);
      await controller.prepare();
      camera.frame('0123456789012', 'EAN_13');
      await controller.accept();
      expect(codes, ['123456789012', '0123456789012']);
      controller.dispose();
    },
  );
  test(
    'M53 barcode repeated frames and double confirmation count once; deliberate same-code rearm counts again',
    () async {
      final camera = SyntheticBarcodeCamera(), codes = <String>[];
      final controller = BarcodeScannerController(
        camera: camera,
        authorize: () async {},
        permission: (action) => action(),
        lookup: (text) async {
          codes.add(text);
          return const BarcodeFeedback('m53CameraAdded', success: true);
        },
      );
      await controller.prepare();
      for (var n = 0; n < 20; n++) {
        camera.frame('0000123456789');
      }
      expect(codes, isEmpty);
      expect(controller.value!.text, '0000123456789');
      await Future.wait([
        controller.accept(),
        controller.accept(),
        controller.accept(),
      ]);
      expect(codes, ['0000123456789']);
      expect(controller.armed, isFalse);
      camera.frame('0000123456789');
      await controller.accept();
      expect(codes.length, 1);
      await controller.prepare();
      camera.frame('0000123456789');
      await controller.accept();
      expect(codes, ['0000123456789', '0000123456789']);
      expect(camera.arms, 2);
      controller.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(camera.disposed, isTrue);
    },
  );
  test(
    'M53 barcode unavailable and denied permission preserve fallback and never perform lookup',
    () async {
      final camera = SyntheticBarcodeCamera()
        ..status = const CameraAvailability(
          available: false,
          permission: false,
        );
      var lookups = 0;
      final controller = BarcodeScannerController(
        camera: camera,
        authorize: () async {},
        permission: (a) => a(),
        lookup: (text) async {
          lookups++;
          return const BarcodeFeedback('productNotFound');
        },
      );
      await controller.prepare();
      expect(controller.error, 'm53CameraUnavailable');
      expect(camera.arms, 0);
      camera.status = const CameraAvailability(
        available: true,
        permission: false,
        cameras: 1,
      );
      await controller.prepare();
      expect(controller.error, 'm53CameraPermissionDenied');
      expect(camera.arms, 0);
      expect(lookups, 0);
      controller.dispose();
    },
  );
  test(
    'M53 barcode lock during permission or authorization cannot arm or publish a pending result',
    () async {
      final camera = SyntheticBarcodeCamera()
        ..status = const CameraAvailability(
          available: true,
          permission: false,
          cameras: 1,
        )
        ..pendingPermission = Completer<CameraAvailability>();
      var allowed = true, lookups = 0;
      final controller = BarcodeScannerController(
        camera: camera,
        authorize: () async {
          if (!allowed) throw const AppError('m53CashierLocked');
        },
        permission: (action) => action(),
        lookup: (text) async {
          lookups++;
          return const BarcodeFeedback('m53CameraAdded', success: true);
        },
      );
      final opening = controller.prepare();
      await Future<void>.delayed(Duration.zero);
      expect(controller.permissionPending, isTrue);
      allowed = false;
      controller.suspend(inactive: true);
      camera.pendingPermission!.complete(
        const CameraAvailability(available: true, permission: true, cameras: 1),
      );
      await opening;
      expect(camera.arms, 0);
      expect(controller.previewReady, isFalse);
      expect(lookups, 0);
      controller.resume();
      await controller.prepare();
      expect(controller.error, 'm53CashierLocked');
      controller.dispose();
    },
  );
  test(
    'M53 barcode lifecycle stops frames, restore clears old code and late lookup feedback is dropped',
    () async {
      final camera = SyntheticBarcodeCamera(),
          pending = Completer<BarcodeFeedback>();
      final controller = BarcodeScannerController(
        camera: camera,
        authorize: () async {},
        permission: (a) => a(),
        lookup: (_) => pending.future,
      );
      await controller.prepare();
      camera.frame('https://example.invalid/product');
      final lookup = controller.accept();
      await Future<void>.delayed(Duration.zero);
      controller.suspend(inactive: true, clear: true);
      pending.complete(const BarcodeFeedback('m53CameraAdded', success: true));
      await lookup;
      expect(controller.value, isNull);
      expect(controller.feedback, isNull);
      expect(controller.previewReady, isFalse);
      expect(controller.error, 'm53CameraStoreChanged');
      expect(camera.pauses, greaterThan(0));
      camera.frame('0001');
      expect(controller.value, isNull);
      controller.dispose();
    },
  );
  test(
    'M53 barcode preserves leading zeros and treats URL as literal; oversized control and unsupported formats rejected',
    () {
      expect(BarcodeValue('0000123', 'CODE_128').text, '0000123');
      expect(
        BarcodeValue('https://example.invalid/a', 'QR_CODE').text,
        'https://example.invalid/a',
      );
      expect(() => BarcodeValue('A\u0000B', 'QR_CODE'), throwsFormatException);
      expect(() => BarcodeValue('A' * 257, 'QR_CODE'), throwsFormatException);
      expect(() => BarcodeValue('123', 'NOT_A_FORMAT'), throwsFormatException);
    },
  );
}
