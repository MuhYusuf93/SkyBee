import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/features/barcode/application/native_barcode_camera.dart';
import 'package:kasir_app/features/barcode/domain/barcode_camera.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'M53 barcode native adapter ignores a queued result from a prior arm or pause',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const view = MethodChannel('kasir_app/barcode_camera/41');
      final camera = NativeBarcodeCamera(), received = <BarcodeCameraEvent>[];
      var token = 0;
      messenger.setMockMethodCallHandler(view, (call) async {
        if (call.method == 'arm') {
          token = (call.arguments as Map)['token'] as int;
        }
        return null;
      });
      final subscription = camera.events.listen(received.add);
      Future<void> frame(int epoch) async {
        // The SDK test messenger simulates an inbound platform message; no actual
        // camera or platform permission is involved in this transport boundary.
        await messenger.handlePlatformMessage(
          view.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('decoded', {
              'text': '0000123',
              'format': 'CODE_128',
              'token': epoch,
            }),
          ),
          null,
        );
        await Future<void>.delayed(Duration.zero);
      }

      try {
        await camera.attach(41);
        await camera.arm();
        final first = token;
        await frame(first);
        expect(received.whereType<BarcodeDecoded>().length, 1);
        await camera.pause();
        await camera.arm();
        expect(token, greaterThan(first));
        await frame(first);
        expect(received.whereType<BarcodeDecoded>().length, 1);
        await frame(token);
        expect(received.whereType<BarcodeDecoded>().length, 2);
        await camera.pause();
        await frame(token);
        expect(received.whereType<BarcodeDecoded>().length, 2);
      } finally {
        await subscription.cancel();
        await camera.dispose();
        messenger.setMockMethodCallHandler(view, null);
      }
    },
  );
}
