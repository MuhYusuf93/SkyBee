import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/application/inventory_service.dart';
import 'package:kasir_app/features/inventory/application/receipt_photo_validation.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/receipt_photo.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'support/m54_receipt_photo_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  m54ReceiptPhotoSuite(databaseFactoryFfi);
}

void m54ReceiptPhotoSuite(DatabaseFactory factory) {
  test(
    'M54 receipt photo rejects metadata, trailing data and invalid size',
    () {
      final photo = publicReceiptPhoto();
      expect((photo.width, photo.height), (80, 64));
      expect(publicReceiptPhoto(alternate: true).hash, isNot(photo.hash));
      for (final bytes in [
        Uint8List.fromList([
          ...photo.jpeg.take(2),
          0xff,
          0xe1,
          0,
          4,
          0x11,
          0x22,
          ...photo.jpeg.skip(2),
        ]),
        Uint8List.fromList([...photo.jpeg, 0xff, 0xd9]),
        Uint8List(ReceiptPhotoAsset.maxBytes + 1),
      ]) {
        expect(
          () => ReceiptPhotoAsset.fromJpeg(bytes),
          throwsA(isA<AppError>()),
        );
      }
    },
  );

  test(
    'M54 receipt photo pages honor revision, rollback, warehouse draft and owner audit',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'm54_receipt_photo_test_',
      );
      final db = DatabaseCoordinator(
        factory: factory,
        databasePath: '${root.path}/m5_regression_54.db',
      );
      final app = AppServices(db);
      final first = publicReceiptPhoto(),
          second = publicReceiptPhoto(alternate: true);
      try {
        await app.management.configure('PUBLIC PHOTO FIXTURE', '0001', '0001');
        await app.management.unlock('0001');
        final product = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC RECEIVING GOODS',
            sellingPrice: Money(12000, 'IDR', 0),
          ),
        );
        var draft = await app.inventory.createReceiptDraft();
        draft = await app.inventory.addReceiptDraftProduct(
          draft.id,
          draft.revision,
          product,
        );
        draft = await app.inventory.updateReceiptDraftLine(
          draft.id,
          draft.revision,
          draft.lines.single.id,
          input: StockInput(2),
          cost: CostAmount.fromMoney(Money(1000, 'IDR', 0)),
        );
        await app.management.reauthenticate('0001', 'security');
        await app.management.setTaskPattern(
          3,
          warehousePin: '1234',
          confirmation: '1234',
        );
        await app.management.unlock('1234', role: ManagementRole.warehouse);

        await app.inventory.saveReceiptPhoto(draft.id, draft.revision, first);
        await expectLater(
          app.inventory.saveReceiptPhoto(draft.id, draft.revision, second),
          throwsA(isA<AppError>()),
        );
        var pages = await app.inventory.receiptPhotoPages(draft.id);
        final kept = pages.pages.single.id;
        var checks = 0;
        await expectLater(
          app.inventory.saveReceiptPhoto(
            draft.id,
            pages.revision,
            second,
            requireIntent: () {
              if (++checks == 2) throw const AppError('m54ScanRouteChanged');
            },
          ),
          throwsA(isA<AppError>()),
        );
        expect(
          (await app.inventory.receiptPhotoPages(draft.id)).pages,
          hasLength(1),
        );
        await app.inventory.saveReceiptPhoto(draft.id, pages.revision, second);
        pages = await app.inventory.receiptPhotoPages(draft.id);
        expect(pages.pages.map((p) => p.position), [0, 1]);
        final discarded = pages.pages.last.id;
        await app.inventory.rotateReceiptPhoto(draft.id, pages.revision, kept);
        pages = await app.inventory.receiptPhotoPages(draft.id);
        expect(pages.pages.first.rotation, 1);
        await app.inventory.saveReceiptPhoto(
          draft.id,
          pages.revision,
          second,
          replace: kept,
        );
        pages = await app.inventory.receiptPhotoPages(draft.id);
        expect(pages.pages.first.rotation, 0);
        expect(pages.pages.first.width, 96);
        await app.inventory.removeReceiptPhoto(
          draft.id,
          pages.revision,
          discarded,
        );
        pages = await app.inventory.receiptPhotoPages(draft.id);
        expect(pages.pages.single.id, kept);
        expect(
          (await app.inventory.receiptPhoto(draft.id, kept)).hash,
          second.hash,
        );

        await db.transaction((sql) async {
          await sql.update('receipt_photos', {'sha256': '0' * 64});
          await expectLater(
            ReceiptPhotoValidation.validate(sql),
            throwsA(isA<FormatException>()),
          );
          await sql.update('receipt_photos', {'sha256': second.hash});
        });
        final cancelled = await app.inventory.createReceiptDraft();
        await app.inventory.saveReceiptPhoto(
          cancelled.id,
          cancelled.revision,
          first,
        );
        final toCancel = await app.inventory.receiptDraft(cancelled.id);
        await app.inventory.cancelReceiptDraft(toCancel.id, toCancel.revision);
        expect(
          await db.read(
            (sql) => sql.query(
              'receipt_photos',
              where: 'draft_id=?',
              whereArgs: [cancelled.id.value],
            ),
          ),
          isEmpty,
        );

        await app.inventory.confirmReceiptDraft(draft.id, pages.revision);
        await expectLater(
          app.inventory.receiptPhoto(draft.id, kept),
          throwsA(isA<AppError>()),
        );
        await app.management.unlock('0001');
        expect(
          (await app.inventory.receiptPhotoPages(draft.id)).editable,
          isFalse,
        );
        expect(
          (await app.inventory.receiptPhoto(draft.id, kept)).jpeg,
          second.jpeg,
        );
        expect((await app.inventory.detail(product)).quantity, 2);
        await expectLater(
          db.transaction(
            (sql) => sql.update('receipt_photos', {'quarter_turns': 2}),
          ),
          throwsA(isA<DatabaseException>()),
        );
        await db.read(ReceiptPhotoValidation.validate);
      } finally {
        await db.close();
        await factory.deleteDatabase(db.databasePath);
        await root.delete();
      }
    },
  );
}
