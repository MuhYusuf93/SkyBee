import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/domain/change_record.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';

/// Queue real reads behind a barrier, revoke the capability, then release SQL.
/// UI visibility is not an authorization control and cannot substitute for this.
void protectedReadsSuite(
  DatabaseFactory factory,
  Future<String> Function() newPath,
) {
  test(
    'queued inventory/settings reads reject a revoked management capability',
    () async {
      final path = await newPath();
      final db = DatabaseCoordinator(factory: factory, databasePath: path);
      final services = AppServices(db);
      try {
        await services.management.configure(
          'Synthetic read fixture',
          '0001',
          '0001',
        );
        await services.management.unlock('0001');
        final id = await services.inventory.create(
          ProductInput(
            name: 'Synthetic secret cost',
            sellingPrice: Money(1000, 'IDR', 0),
          ),
          initialQuantity: 5,
          unitCost: CostAmount.fromMoney(Money(600, 'IDR', 0)),
        );
        final entered = Completer<void>(), release = Completer<void>();
        final barrier = db.read((sql) async {
          entered.complete();
          await release.future;
        });
        await entered.future;
        Future<bool> denied(Future<Object?> pending) async {
          try {
            await pending;
            return false;
          } on AppError catch (error) {
            return error.message == 'managementSessionLockedEnterPinAgain';
          }
        }

        final pending = [
          denied(services.inventory.detail(id)),
          denied(services.inventory.batches(id)),
          denied(services.inventory.latestReceipt(id)),
          denied(services.inventory.masterPage(MasterKind.category, '', null)),
          denied(services.inventory.history(id, ChangeKind.stock, null)),
          denied(services.settings.load()),
        ];
        services.management.lock();
        release.complete();
        await barrier;
        expect(
          await Future.wait(pending),
          everyElement(true),
          reason:
              'Detail, batches, receipt, masters, history and settings must reject queued reads',
        );
        await services.management.unlock('0001');
        expect((await services.inventory.detail(id)).quantity, 5);
        expect((await services.inventory.batches(id)).items, hasLength(1));
        expect(await services.inventory.latestReceipt(id), isNotNull);
        expect(
          (await services.inventory.masterPage(
            MasterKind.category,
            '',
            null,
          )).items,
          isEmpty,
        );
        expect(
          (await services.inventory.history(id, ChangeKind.stock, null)).items,
          isNotEmpty,
        );
        expect(
          (await services.settings.load())['name'],
          'Synthetic read fixture',
        );
      } finally {
        await db.close();
        await factory.deleteDatabase(path);
      }
    },
  );
}
