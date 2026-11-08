import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/archive/application/archive_purge_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/management/application/management_service.dart';
import 'package:kasir_app/features/members/domain/member_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  m54ArchivePurgeSuite(databaseFactoryFfi);
}

void m54ArchivePurgeSuite(DatabaseFactory factory) {
  test(
    'M54 purge only removes approved archived rows and retains every business witness',
    () async {
      final root = await Directory.systemTemp.createTemp('m54_archive_purge_');
      final path = '${root.path}/m5_regression_54.db';
      final db = DatabaseCoordinator(factory: factory, databasePath: path);
      final app = AppServices(db);
      final purge = ArchivePurgeService(db, app.management);
      final scopeChanged = isA<AppError>().having(
        (e) => e.message,
        'message',
        'm54ArchiveScopeChanged',
      );
      Future<FreshActionProof> fresh() async {
        await app.management.reauthenticate(
          '0001',
          ArchivePurgeService.ownerPurpose,
        );
        return app.management.claimFresh(ArchivePurgeService.ownerPurpose);
      }

      try {
        await app.management.configure('PUBLIC PURGE', '0001', '0001');
        await app.management.unlock('0001');
        final supplier = await app.inventory.saveMaster(
          MasterKind.supplier,
          'PUBLIC SUPPLIER',
        );
        final category = await app.inventory.saveMaster(
          MasterKind.category,
          'PUBLIC CATEGORY',
        );
        final empty = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC EMPTY',
            aliases: const ['PUBLIC ALIAS'],
            sellingPrice: Money(10000, 'IDR', 0),
            masterSupplierId: supplier,
          ),
        );
        final sold = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC SOLD',
            sellingPrice: Money(10000, 'IDR', 0),
          ),
          initialQuantity: 1,
          unitCost: CostAmount.fromMoney(Money(5000, 'IDR', 0)),
        );
        final safeMember = await app.members.create(
          const MemberInput(
            name: 'PUBLIC UNUSED MEMBER',
            phone: '081234567890',
          ),
        );
        final paidMember = await app.members.create(
          const MemberInput(name: 'PUBLIC PAID MEMBER', phone: '081234567891'),
        );
        var cart = await app.cart.open();
        cart = await app.cart.add(cart.id, sold);
        final sale = await app.checkout.submit(
          cart.id,
          cart.revision,
          CheckoutInput(
            memberIntent: true,
            customer: CustomerChoice(id: paidMember.id, name: paidMember.name),
          ),
        );
        expect((await app.receivables.balance(paidMember.id)).amountMinor, 0);
        for (final id in [empty, sold]) {
          final detail = await app.inventory.detail(id);
          expect(detail.quantity, 0);
          await app.inventory.archive(id, detail.revision);
        }
        await app.inventory.archiveMaster(MasterKind.supplier, supplier);
        await app.inventory.archiveMaster(MasterKind.category, category);
        await app.members.archive(safeMember.id, safeMember.revision, true);
        await app.members.archive(paidMember.id, paidMember.revision, true);

        final productPlan = await purge.preview(ArchivePurgeKind.product, [
          empty,
          sold,
        ]);
        expect(productPlan.eligible.single.id, empty);
        expect(productPlan.entries.last.blocker, ArchivePurgeBlocker.reference);
        expect(
          (await purge.preview(ArchivePurgeKind.supplier, [supplier])).eligible,
          isEmpty,
        );
        final oldAudit = await db.read((sql) => sql.query('audit_log'));
        var checks = 0;
        await expectLater(
          purge.purge(
            productPlan,
            await fresh(),
            requireIntent: () {
              if (++checks == 2) throw const AppError('m54ArchiveScopeChanged');
            },
          ),
          throwsA(scopeChanged),
        );
        expect((await app.inventory.detail(empty)).isDeleted, isTrue);
        expect(
          await db.read((sql) => sql.query('product_aliases')),
          hasLength(1),
        );
        final reusable = await fresh();
        expect(await purge.purge(productPlan, reusable), 1);
        await expectLater(
          purge.purge(productPlan, reusable),
          throwsA(isA<AppError>()),
        );
        expect(await db.read((sql) => sql.query('product_aliases')), isEmpty);
        expect(await db.read((sql) => sql.query('product_suppliers')), isEmpty);
        expect((await app.checkout.receipt(sale.id)).id, sale.id);
        expect(
          await db.read((sql) => sql.query('audit_log')),
          containsAll(oldAudit),
        );
        final supplierPlan = await purge.preview(ArchivePurgeKind.supplier, [
          supplier,
        ]);
        expect(await purge.purge(supplierPlan, await fresh()), 1);

        final stale = await purge.preview(ArchivePurgeKind.category, [
          category,
        ]);
        // A legacy or newly imported reference may become visible during review.
        await db.transaction(
          (sql) => sql.update(
            'products',
            {'category_id': category.value},
            where: 'id=?',
            whereArgs: [sold.value],
          ),
        );
        await expectLater(
          purge.purge(stale, await fresh()),
          throwsA(scopeChanged),
        );
        expect(
          (await purge.preview(ArchivePurgeKind.category, [category])).eligible,
          isEmpty,
        );

        final members = await purge.preview(ArchivePurgeKind.member, [
          safeMember.id,
          paidMember.id,
        ]);
        expect(members.eligible.single.id, safeMember.id);
        expect(members.entries.last.blocker, ArchivePurgeBlocker.reference);
        app.management.lock();
        expect(
          () => purge.preview(ArchivePurgeKind.member, [safeMember.id]),
          throwsA(isA<AppError>()),
        );
        expect(await purge.purge(members, await fresh()), 1);
        expect((await app.members.ownerDetail(paidMember.id)).archived, isTrue);
        expect(
          await db.read((sql) => sql.rawQuery('PRAGMA foreign_key_check')),
          isEmpty,
        );
      } finally {
        await db.close();
        await factory.deleteDatabase(path);
        await root.delete();
      }
    },
  );
}
