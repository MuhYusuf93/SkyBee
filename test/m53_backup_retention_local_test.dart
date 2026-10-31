import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/members/domain/member_models.dart';
import 'package:kasir_app/features/backup/domain/backup_retention.dart';
import 'support/m53_retention_host_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late RetentionHostFixture f;
  setUp(() async {
    f = RetentionHostFixture();
    await f.initialize();
  });
  tearDown(() async => f.dispose());
  test(
    'pending upload source remains protected after a crash until its operation succeeds',
    () async {
      final recent = [for (var i = 0; i < 3; i++) await f.add(i)];
      final pending = await f.add(200);
      await f.database.exclusive(
        (db) => db.insert('backup_runs', {
          'id': 'public-pending',
          'operation_key': 'public-resume',
          'origin_id': 'b' * 64,
          'status': 'failed',
          'started_at': f.now,
          'snapshot_path': f.archive(pending).path,
        }),
      );
      final preview = await f.retention.previewLocal(RetentionMode.age90);
      expect(preview.plan.eligible, 0);
      await f.retention.activateLocal(preview);
      expect(await f.retention.afterLocalBackup(recent.first), 0);
      expect(await f.archive(pending).exists(), true);
      await f.database.exclusive(
        (db) => db.update(
          'backup_runs',
          {'status': 'success'},
          where: 'id=?',
          whereArgs: ['public-pending'],
        ),
      );
      final next = await f.add(0);
      expect(await f.retention.afterLocalBackup(next), 1);
      expect(await f.archive(pending).exists(), false);
    },
  );
  test(
    'local preview and activation delete nothing; only a later verified backup cleans with floor3',
    () async {
      final rows = [for (var i = 0; i < 7; i++) await f.add(200 + i)];
      final scope = await f.retention.localScope();
      expect(
        (await f.retention.metadata.policy(scope)).mode,
        RetentionMode.off,
      );
      final preview = await f.retention.previewLocal(RetentionMode.age90);
      expect(preview.plan.eligible, 4);
      await f.retention.activateLocal(preview);
      for (final m in rows) {
        expect(await f.archive(m).exists(), true);
      }
      final latest = await f.add(0);
      expect(await f.retention.afterLocalBackup(latest), 5);
      expect(await f.archive(rows[0]).exists(), true);
      expect(await f.archive(rows[1]).exists(), true);
      expect(await f.archive(latest).exists(), true);
      for (final m in rows.skip(2)) {
        expect(await f.archive(m).exists(), false);
      }
      expect(
        (await f.database.read((db) => db.query('local_backups'))).length,
        3,
      );
    },
  );
  test(
    'pins safety active candidates unknown files and unknown keys survive local cleanup',
    () async {
      final recent = [for (var i = 0; i < 3; i++) await f.add(i)];
      final pin = await f.add(200),
          safety = await f.add(201, safety: true),
          candidate = await f.add(202),
          legacy = await f.add(203, verified: false),
          extra = await f.add(204),
          changed = await f.add(205);
      final scope = await f.retention.localScope();
      await f.retention.pinLocal(pin.id, true);
      final lease = await f.retention.protectLocal(f.archive(candidate));
      final note = File(
        '${f.archive(extra).parent.path}/synthetic-user-note.txt',
      );
      await note.writeAsString('PUBLIC KEEP');
      await f.archive(changed).writeAsString('changed opaque bytes');
      final preview = await f.retention.previewLocal(RetentionMode.age90);
      expect(preview.plan.eligible, 0);
      await f.retention.activateLocal(preview);
      expect(await f.retention.afterLocalBackup(recent.first), 0);
      for (final m in [pin, safety, candidate, legacy, extra, changed]) {
        expect(await f.archive(m).exists(), true);
      }
      expect(await note.readAsString(), 'PUBLIC KEEP');
      await lease.release();
      final unknownKey = await f.add(206);
      f.secrets.remove('backup-master-v1');
      await expectLater(
        f.retention.afterLocalBackup(recent.first),
        throwsStateError,
      );
      expect(await f.archive(unknownKey).exists(), true);
      expect(
        (await f.retention.describeLocal(scope, unknownKey.id)).keyAvailable,
        false,
      );
    },
  );
  test(
    'pin edit or re-unlock invalidates owner preview, including unchanged policy revision',
    () async {
      for (var i = 0; i < 3; i++) {
        await f.add(i);
      }
      final old = await f.add(200);
      final a = await f.retention.previewLocal(RetentionMode.age90);
      await f.retention.pinLocal(old.id, true);
      await expectLater(f.retention.activateLocal(a), throwsStateError);
      final b = await f.retention.previewLocal(RetentionMode.age90);
      f.app.management.lock();
      await f.app.management.unlock('0001');
      await expectLater(f.retention.activateLocal(b), throwsA(isA<AppError>()));
      expect(await f.archive(old).exists(), true);
    },
  );
  test(
    'candidate capabilities survive catalog repair and release one handle at a time',
    () async {
      final old = await f.add(200), scope = await f.retention.localScope();
      final one = await f.retention.protectLocal(f.archive(old)),
          two = await f.retention.protectLocal(f.archive(old));
      await f.database.exclusive((db) => db.delete('local_backups'));
      await f.app.backups.recoverLocalCatalog();
      expect(
        (await f.retention.metadata.proof(scope, old.id))!.candidates.length,
        2,
      );
      await one.release();
      await one.release();
      expect(
        (await f.retention.metadata.proof(scope, old.id))!.candidates.length,
        1,
      );
      await two.release();
      expect(
        (await f.retention.metadata.proof(scope, old.id))!.candidates,
        isEmpty,
      );
    },
  );
  test(
    'warehouse direct preview pin and headless cleanup are denied',
    () async {
      final old = await f.add(200);
      await f.app.management.reauthenticate('0001', 'security');
      await f.app.management.setTaskPattern(
        3,
        warehousePin: '1234',
        confirmation: '1234',
      );
      await f.app.management.unlock('1234', role: ManagementRole.warehouse);
      await expectLater(
        f.retention.previewLocal(RetentionMode.age90),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        f.retention.pinLocal(old.id, true),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        f.retention.afterLocalBackup(
          old,
          headless: true,
          checkAuthorization: () async {},
        ),
        throwsA(isA<AppError>()),
      );
      expect(await f.archive(old).exists(), true);
    },
  );
  test(
    'cleanup preserves actual sale stock HPP customer and audit rows exactly',
    () async {
      await f.app.members.create(
        const MemberInput(name: 'PUBLIC KEEP MEMBER', phone: '08000000001'),
      );
      final product = await f.app.inventory.create(
        ProductInput(
          name: 'PUBLIC KEEP PRODUCT',
          sellingPrice: Money(1000, 'IDR', 0),
        ),
        initialQuantity: 10,
        unitCost: CostAmount.fromMoney(Money(400, 'IDR', 0)),
      );
      var cart = await f.app.cart.open();
      cart = await f.app.cart.add(cart.id, product);
      await f.app.checkout.submit(
        cart.id,
        cart.revision,
        const CheckoutInput(),
      );
      Future<String> snapshot() => f.database.read((db) async {
        final names = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name!='local_backups' ORDER BY name",
        );
        final tables = <String, Object?>{};
        for (final row in names) {
          final name = row['name'] as String;
          tables[name] = await db.query(name);
        }
        return jsonEncode(tables);
      });
      for (var i = 0; i < 8; i++) {
        await f.add(200 + i);
      }
      await f.retention.activateLocal(
        await f.retention.previewLocal(RetentionMode.age90),
      );
      final latest = await f.add(0), before = await snapshot();
      expect(await f.retention.afterLocalBackup(latest), 6);
      expect(await snapshot(), before);
      expect(
        (await f.database.read((db) => db.query('sale_transactions'))).length,
        1,
      );
    },
  );
}
