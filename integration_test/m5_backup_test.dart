import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/database/durable_promotion.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/printer/application/store_logo_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_platform/kasir_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'portable authenticated archive restores financial facts across different installation DB keys',
    () async {
      final nonce = DateTime.now().microsecondsSinceEpoch;
      final platform = KasirPlatform(fixtureNamespace: 'test-m51-$nonce');
      final root = await getDatabasesPath();
      final sourceDirectory = Directory('$root/m5_backup_source_$nonce'),
          targetDirectory = Directory('$root/m5_backup_target_$nonce');
      expect(await sourceDirectory.exists(), false);
      expect(await targetDirectory.exists(), false);
      await sourceDirectory.create();
      await targetDirectory.create();
      final sourcePath = '${sourceDirectory.path}/source.db',
          targetPath = '${targetDirectory.path}/target.db';
      DatabaseCoordinator coordinator(String path, String key) =>
          DatabaseCoordinator(
            factory: databaseFactory,
            databasePath: path,
            gate: const AndroidDatabaseGate(),
            encryption: EncryptedDatabase(
              path,
              keyName: key,
              platform: platform,
            ),
          );
      final source = coordinator(sourcePath, 'test-backup-source-$nonce'),
          target = coordinator(targetPath, 'test-backup-target-$nonce');
      final app = AppServices(source), other = AppServices(target);
      final snapshotReady = Completer<void>(),
          releaseSnapshot = Completer<void>(),
          safetyReady = Completer<void>(),
          releaseSafety = Completer<void>();
      final backup = BackupService(
            source,
            app.management,
            platform: platform,
            testStage: (stage) async {
              if (stage == 'snapshotExported' && !snapshotReady.isCompleted) {
                snapshotReady.complete();
                await releaseSnapshot.future;
              }
            },
          ),
          restore = BackupService(
            target,
            other.management,
            platform: platform,
            pausePeripherals: other.printing.pauseForRestore,
            resumePeripherals: other.printing.resumeAfterRestore,
            testStage: (stage) async {
              if (stage == 'safetyCreated' && !safetyReady.isCompleted) {
                safetyReady.complete();
                await releaseSafety.future;
              }
            },
          );
      PortableBackup? archive, safety;
      BackupInspection? incoming;
      try {
        await app.management.configure(
          'Synthetic portable source',
          '0001',
          '0001',
        );
        await app.management.unlock('0001');
        final recorder = ui.PictureRecorder();
        ui.Canvas(
          recorder,
        ).drawColor(const ui.Color(0xff000000), ui.BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(32, 16);
        final logoInput = File('${sourceDirectory.path}/synthetic-logo.input');
        try {
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          await logoInput.writeAsBytes(
            png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
          );
        } finally {
          image.dispose();
          picture.dispose();
        }
        await StoreLogoService(source, app.management).apply(logoInput);
        await source.exclusive((db) => db.rawQuery('PRAGMA journal_mode=WAL'));
        final category = await app.inventory.saveMaster(
          MasterKind.category,
          'Synthetic category',
        );
        final supplier = await app.inventory.saveMaster(
          MasterKind.supplier,
          'Synthetic supplier',
        );
        final product = await app.inventory.create(
          ProductInput(
            name: 'Synthetic portable goods',
            attributes: ProductAttributes(
              sizeMilli: 750,
              unit: 'kg',
              shelf: 'A-1',
              note: 'Synthetic internal note',
            ),
            sellingPrice: Money(12000, 'IDR', 0),
            wholesalePrice: Money(10000, 'IDR', 0),
            packSize: 40,
            packLabel: 'dus',
            categoryId: category,
            aliases: ['synthetic alias'],
            barcode: '000123',
          ),
          initialQuantity: 10,
          unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
        );
        await app.inventory.receive(
          product,
          2,
          CostAmount.fromMoney(Money(8000, 'IDR', 0)),
          supplierId: supplier,
          operationKey: 'm5-restock-$nonce',
        );
        var draft = await app.cart.open();
        draft = await app.cart.add(draft.id, product);
        await app.checkout.submit(
          draft.id,
          draft.revision,
          CheckoutInput(
            cash: true,
            tender: Money(0, 'IDR', 0),
            tenderRaw: '0',
            mode: PaymentMode.debt,
            customer: const CustomerChoice(name: 'Synthetic portable debtor'),
          ),
        );
        final customer = (await app.receivables.customers()).items.single;
        final payment = await app.receivables.preview(
          customer.id,
          Money(1000, 'IDR', 0),
        );
        await app.receivables.record(payment);
        var returnedDraft = await app.cart.next(draft.id);
        returnedDraft = await app.cart.add(returnedDraft.id, product);
        final returned = await app.checkout.submit(
          returnedDraft.id,
          returnedDraft.revision,
          CheckoutInput(
            cash: true,
            tender: Money(15000, 'IDR', 0),
            tenderRaw: '15000',
          ),
        );
        await app.corrections.cancelSale(
          returned.id,
          operationKey: 'm5-return-$nonce',
          reason: 'Synthetic returned goods and refund handled',
          goodsReturned: true,
          moneyHandled: true,
        );
        var queuedDraft = await app.cart.next(returnedDraft.id);
        queuedDraft = await app.cart.add(queuedDraft.id, product);
        await app.quickCash.save('USD', [1550, 2000]);
        final before =
            (await source.read(DatabaseValidation.fingerprint))['tables']
                as Map;
        const code =
            'abababababababababababababababababababababababababababababababab';
        await app.management.reauthenticate('0001', 'recovery');
        await backup.confirmRecovery(code, code);
        final creating = backup.create();
        await snapshotReady.future;
        final receiving = app.inventory.receive(
          product,
          2,
          CostAmount.fromMoney(Money(8000, 'IDR', 0)),
          operationKey: 'm5-concurrent-restock-$nonce',
        );
        final checkingOut = app.checkout.submit(
          queuedDraft.id,
          queuedDraft.revision,
          const CheckoutInput(mode: PaymentMode.paid),
        );
        releaseSnapshot.complete();
        archive = await creating;
        await receiving;
        await checkingOut;
        expect((await app.inventory.detail(product)).quantity, 12);
        expect((await app.reports.reconcile()).consistent, true);
        expect(archive.manifest.schema, Schema.version);
        await other.management.configure(
          'Synthetic portable target',
          '0002',
          '0002',
        );
        await other.management.unlock('0002');
        final oldProduct = await other.inventory.create(
          ProductInput(
            name: 'Synthetic pre-restore target',
            sellingPrice: Money(1000, 'IDR', 0),
          ),
          initialQuantity: 4,
          unitCost: CostAmount.fromMoney(Money(500, 'IDR', 0)),
        );
        var oldDraft = await other.cart.open();
        oldDraft = await other.cart.add(oldDraft.id, oldProduct);
        expect(source.encryption!.key, isNot(target.encryption!.key));
        var originalHash = await DurablePromotion.digest(File(targetPath));
        await expectLater(
          restore.inspect(archive.file, '00' * 32),
          throwsA(anything),
        );
        expect(await DurablePromotion.digest(File(targetPath)), originalHash);
        final corrupt = File('$root/m5_corrupt_$nonce.kasirbackup');
        await archive.file.copy(corrupt.path);
        final handle = await corrupt.open(mode: FileMode.append);
        await handle.truncate(await handle.length() - 1);
        await handle.close();
        await expectLater(restore.inspect(corrupt, code), throwsA(anything));
        expect(await DurablePromotion.digest(File(targetPath)), originalHash);
        await corrupt.delete();
        incoming = await restore.inspect(archive.file, code);
        await other.management.reauthenticate('0002', 'restore');
        originalHash = await DurablePromotion.digest(File(targetPath));
        await expectLater(
          BackupService(
            target,
            other.management,
            availableBytes: (_) async => 0,
            platform: platform,
            pausePeripherals: other.printing.pauseForRestore,
            resumePeripherals: other.printing.resumeAfterRestore,
          ).restore(incoming, confirmReplaceAndDrafts: true),
          throwsStateError,
        );
        expect(await DurablePromotion.digest(File(targetPath)), originalHash);
        final staged = File('${incoming.directory.path}/database.db');
        final stageLength = await staged.length();
        await staged.writeAsBytes([0], mode: FileMode.append, flush: true);
        await other.management.reauthenticate('0002', 'restore');
        originalHash = await DurablePromotion.digest(File(targetPath));
        await expectLater(
          restore.restore(incoming, confirmReplaceAndDrafts: true),
          throwsStateError,
        );
        expect(await DurablePromotion.digest(File(targetPath)), originalHash);
        final stageHandle = await staged.open(mode: FileMode.append);
        await stageHandle.truncate(stageLength);
        await stageHandle.close();
        await other.management.reauthenticate('0002', 'restore');
        originalHash = await DurablePromotion.digest(File(targetPath));
        await expectLater(
          restore.restore(incoming, confirmReplaceAndDrafts: false),
          throwsStateError,
        );
        expect(await DurablePromotion.digest(File(targetPath)), originalHash);
        await other.management.reauthenticate('0002', 'restore');
        final replacing = restore.restore(
          incoming,
          confirmReplaceAndDrafts: true,
        );
        await safetyReady.future;
        final staleCheckout = other.checkout.submit(
          oldDraft.id,
          oldDraft.revision,
          const CheckoutInput(mode: PaymentMode.paid),
        );
        // Install the failure expectation before releasing the lease so an
        // expected stale-intent rejection is never an unhandled async error.
        final rejected = expectLater(staleCheckout, throwsStateError);
        releaseSafety.complete();
        safety = await replacing;
        await rejected;
        expect(await safety.file.exists(), true);
        expect(other.management.isUnlocked, false);
        await other.management.unlock('0001');
        expect((await other.reports.reconcile()).consistent, true);
        final after =
            (await target.read(DatabaseValidation.fingerprint))['tables']
                as Map;
        for (final table in [
          'products',
          'categories',
          'suppliers',
          'product_aliases',
          'stock_receipts',
          'stock_receipt_items',
          'stock_batches',
          'stock_history',
          'sale_transactions',
          'sale_transaction_items',
          'sale_batch_allocations',
          'payments',
          'payment_allocations',
          'customers',
          'audit_log',
          'management_credentials',
          'cart_drafts',
          'cart_draft_items',
          'print_receipts',
          'sale_transaction_reversals',
          'checkout_payment_links',
          'receivable_payment_links',
          'price_history',
          'receipt_assets',
          'checkout_tenders',
          'cash_quick_amounts',
        ]) {
          // Unlock changes attempt/session audit state; verifiers are tested by the
          // restored old PIN, not by pretending credential metadata is unchanged.
          if (table != 'management_credentials' && table != 'audit_log') {
            expect(after[table], before[table], reason: table);
          }
        }
        expect(await other.quickCash.read('USD'), [1550, 2000]);
        expect(
          (await target.read(
            (db) => db.query('space_maintenance'),
          )).single['candidate_backup'],
          isNull,
        );
        expect(
          (await other.receivables.customers())
              .items
              .single
              .balance
              .amountMinor,
          11000,
        );
        expect((await other.inventory.detail(product)).quantity, 11);
        expect(
          (await other.inventory.detail(product)).attributes.toRow(),
          ProductAttributes(
            sizeMilli: 750,
            unit: 'kg',
            shelf: 'A-1',
            note: 'Synthetic internal note',
          ).toRow(),
        );
        await target.read((db) async {
          final items = await db.query('sale_transaction_items');
          expect(items, isNotEmpty);
          for (final item in items) {
            expect(
              ProductAttributes.fromRow(item, suffix: '_snapshot').sizeMilli,
              750,
            );
          }
        });
        final restoredSettings = await target.read(
          (db) => db.query('store_settings'),
        );
        final logoPath = restoredSettings.single['logo_path'] as String;
        expect(p.isWithin(targetDirectory.path, logoPath), true);
        expect(await File(logoPath).exists(), true);
        expect(
          await StoreLogoService(target, other.management).current(),
          await StoreLogoService(source, app.management).current(),
        );
        expect(
          (await target.read(
            (db) => db.query('sale_transaction_reversals'),
          )).length,
          1,
        );
        expect(
          (await target.read(
            (db) => db.query('payments', where: "kind='reversal'"),
          )).length,
          1,
        );
        expect(jsonEncode(archive.manifest.values), isNot(contains(code)));
        final safetyInspection = await restore.inspect(safety.file, code);
        try {
          expect(safetyInspection.manifest.values['id'], safety.manifest.id);
        } finally {
          await safetyInspection.dispose();
        }
        // This is cross-key within one isolated installation; it is explicitly not
        // evidence of a second physical device or Google Drive restore.
      } finally {
        await incoming?.dispose();
        await source.close();
        await target.close();
        if (archive != null && await archive.file.parent.exists()) {
          await archive.file.parent.delete(recursive: true);
        }
        if (safety != null && await safety.file.parent.exists()) {
          await safety.file.parent.delete(recursive: true);
        }
        await deleteDatabase(sourcePath);
        await deleteDatabase(targetPath);
        await sourceDirectory.delete(recursive: true);
        await targetDirectory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
