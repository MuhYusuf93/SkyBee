import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/settings/application/qris_asset_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// An inert drawing, with a visible margin. It does not encode any payment.
Future<Uint8List> picture(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawColor(const ui.Color(0xffffffff), ui.BlendMode.src)
    ..drawRect(const ui.Rect.fromLTWH(20, 20, 15, 20), ui.Paint());
  final drawing = recorder.endRecording();
  final image = await drawing.toImage(width, height);
  try {
    final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
  } finally {
    image.dispose();
    drawing.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'M54 QRIS asset requires owner, preserves full pixels and uses guarded replacement',
    () async {
      final dir = await Directory.systemTemp.createTemp('kasir_qris_asset_');
      final path = '${dir.path}/m5_regression_54.db';
      final db = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final app = AppServices(db);
      final first = await QrisAssetService.normalize(await picture(128, 96));
      final next = await QrisAssetService.normalize(await picture(96, 128));
      try {
        await app.management.configure('PUBLIC QRIS FIXTURE', '0001', '0001');
        await expectLater(
          app.qrisAssets.save(first, expectedHash: null),
          throwsA(isA<AppError>()),
        );
        await app.management.unlock('0001');
        await expectLater(
          QrisAssetService.normalize(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<AppError>()),
        );
        await expectLater(
          QrisAssetService.normalize(await picture(63, 96)),
          throwsA(isA<AppError>()),
        );
        await app.qrisAssets.save(first, expectedHash: null);
        expect((await app.qrisAssets.ownerImage())?.hash, first.hash);
        expect(await app.qrisAssets.checkoutImage(), first.bytes);
        final codec = await ui.instantiateImageCodec(first.bytes);
        final image = (await codec.getNextFrame()).image;
        try {
          expect((image.width, image.height), (128, 96));
          final pixels = (await image.toByteData())!;
          expect(pixels.getUint32(0), 0xffffffff);
          expect(pixels.getUint32((20 * 128 + 20) * 4), 0x000000ff);
        } finally {
          image.dispose();
          codec.dispose();
        }
        await expectLater(
          app.qrisAssets.save(next, expectedHash: null),
          throwsA(
            isA<AppError>().having(
              (e) => e.message,
              'message',
              'm54QrisImageChanged',
            ),
          ),
        );
        expect(await app.qrisAssets.checkoutImage(), first.bytes);
        await app.qrisAssets.save(next, expectedHash: first.hash);
        expect(await app.qrisAssets.checkoutImage(), next.bytes);
        await db.read(QrisAssetService.validate);
        await db.transaction(
          (sql) => sql.update('store_qris_asset', {'width': 97}, where: 'id=1'),
        );
        await expectLater(
          db.read(QrisAssetService.validate),
          throwsFormatException,
        );
        await app.qrisAssets.save(null, expectedHash: next.hash);
        expect(await app.qrisAssets.checkoutImage(), isNull);
        expect(
          await dir
              .list()
              .where(
                (f) => f.path.endsWith('.png') || f.path.endsWith('.input'),
              )
              .toList(),
          isEmpty,
        );
      } finally {
        await db.close();
        await databaseFactoryFfi.deleteDatabase(path);
        await dir.delete();
      }
    },
  );
}
