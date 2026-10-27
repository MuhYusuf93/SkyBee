import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/data/database/database_security_error.dart';
import 'package:kasir_app/demo/skybee_upgrade_audit.dart';
import 'package:kasir_app/features/backup/application/backup_validation.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';
import 'package:kasir_app/features/cashier/application/checkout_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/presentation/cart_provider.dart';
import 'package:kasir_app/features/cashier/presentation/checkout_provider.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/members/application/member_service.dart';
import 'package:kasir_app/features/members/domain/member_models.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';

void m53MemberSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  late Map<String, Object?> credentials;
  late EntityId product;
  late final Future<BackupManifest> Function(DatabaseCoordinator database)
  manifest;
  var serial = 0;
  Money m(int value) => Money(value, 'IDR', 0);
  String path() =>
      '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  Matcher error(String key) =>
      isA<AppError>().having((e) => e.message, 'message', key);
  MemberInput profile(String name, [String phone = '081234567890']) =>
      MemberInput(name: name, phone: phone, address: 'PUBLIC ADDRESS');
  Future<CartSnapshot> basket() async {
    var cart = await app.cart.open();
    if (cart.completedId != null) cart = await app.cart.next(cart.id);
    return app.cart.add(cart.id, product);
  }

  Future<SaleReceipt> sale({
    EntityId? member,
    String? name,
    String phone = '',
    int tender = 10000,
    bool intent = true,
  }) async {
    final cart = await basket();
    return app.checkout.submit(
      cart.id,
      cart.revision,
      CheckoutInput(
        cash: true,
        mode: tender < 10000 ? PaymentMode.partial : PaymentMode.paid,
        tender: m(tender),
        tenderRaw: '$tender',
        memberIntent: intent,
        customer: CustomerChoice(
          id: member,
          name: name ?? 'PUBLIC MEMBER',
          phone: phone,
          address: 'PUBLIC ADDRESS',
        ),
      ),
    );
  }

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m53_member_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    try {
      await AppServices(
        seed,
      ).management.configure('PUBLIC MEMBER FIXTURE', '0001', '0001');
      credentials = Map.of(
        (await seed.read((sql) => sql.query('management_credentials'))).single,
      );
      manifest = (database) => database.read((sql) async {
        final settings = (await sql.query('store_settings')).single;
        final shop = await sql.query('m5_store');
        return BackupManifest({
          'format': 1,
          'cipher': 'SQLCipher',
          'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
          'id': 'public-member',
          'storeId': shop.isEmpty ? 'public-store' : shop.single['store_id'],
          'originId': 'public-origin',
          'schema': Schema.version,
          'createdAt': 1,
          'currency': settings['currency_code'],
          'currencyScale': settings['currency_scale'],
          'timeZone': settings['time_zone'],
          'appVersion': '0.5.2+12',
          'files': {
            'database.db': {'bytes': 1, 'sha256': '0' * 64},
          },
        });
      });
    } finally {
      await seed.close();
      await factory.deleteDatabase(seed.databasePath);
    }
  });
  setUp(() async {
    db = DatabaseCoordinator(factory: factory, databasePath: path());
    await db.transaction(
      (sql) => sql.insert('management_credentials', credentials),
    );
    app = AppServices(db);
    await app.management.unlock('0001');
    product = await app.inventory.create(
      ProductInput(name: 'PUBLIC ITEM', sellingPrice: m(10000)),
      initialQuantity: 20,
      unitCost: CostAmount.fromMoney(m(5000)),
    );
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(db.databasePath);
  });
  tearDownAll(() async => directory.delete());

  test(
    'M53 member requires valid unique phone without merging same-name identities',
    () async {
      await expectLater(
        app.members.create(profile('')),
        throwsA(error('m53MemberFieldsInvalid')),
      );
      await expectLater(
        app.members.create(profile('PUBLIC', '')),
        throwsA(error('m53MemberPhoneRequired')),
      );
      await expectLater(
        app.members.create(profile('PUBLIC', '123')),
        throwsA(error('m52PhoneInvalid')),
      );
      final first = await app.members.create(profile('PUBLIC SAME'));
      expect(first.phone, '+6281234567890');
      await expectLater(
        app.members.create(profile('OTHER', '+6281234567890')),
        throwsA(error('m53MemberPhoneUsed')),
      );
      final second = await app.members.create(
        profile('PUBLIC SAME', '081234567891'),
      );
      expect(first.id, isNot(second.id));
      expect((await app.members.ownerList()).items.length, 2);
    },
  );
  test(
    'M53 owner CRUD preserves identity and checks stale revision and archived phone ownership',
    () async {
      final request = const IdGenerator().next();
      final first = await app.members.create(
        profile('PUBLIC ORIGINAL'),
        requestId: request,
      );
      expect(
        (await app.members.create(
          profile('PUBLIC ORIGINAL'),
          requestId: request,
        )).id,
        first.id,
      );
      final changed = await app.members.update(
        first.id,
        first.revision,
        profile('PUBLIC EDITED', '081234567892'),
      );
      expect(changed.id, first.id);
      expect(changed.revision, 1);
      await expectLater(
        app.members.update(first.id, 0, profile('STALE', '081234567893')),
        throwsA(error('m3DraftChanged')),
      );
      final archived = await app.members.archive(
        changed.id,
        changed.revision,
        true,
      );
      expect((await app.members.ownerList()).items, isEmpty);
      expect(
        (await app.members.ownerList(archived: true)).items.single.id,
        first.id,
      );
      await expectLater(
        app.members.create(profile('NEW', '081234567892')),
        throwsA(error('m53MemberPhoneUsed')),
      );
      expect(
        (await app.members.archive(
          archived.id,
          archived.revision,
          false,
        )).archived,
        isFalse,
      );
    },
  );
  test(
    'M53 member country follows phone region rather than IDR or UI language',
    () async {
      await db.transaction(
        (sql) => sql.update('store_settings', {'phone_region': 'US'}),
      );
      final member = await app.members.create(
        profile('PUBLIC USA', '2025550123'),
      );
      expect(member.phone, '+12025550123');
      await db.transaction(
        (sql) => sql.update('store_settings', {'phone_region': 'ID'}),
      );
      final receipt = await sale(member: member.id);
      expect(receipt.customerPhone, '+12025550123');
      expect(receipt.total.currencyCode, 'IDR');
    },
  );
  test(
    'M53 paid guest remains anonymous while explicitly linked paid purchase snapshots a member once',
    () async {
      await sale(phone: '081234567890', intent: false);
      expect(await db.read((sql) => sql.query('customers')), isEmpty);
      final receipt = await sale(phone: '081234567890');
      final member = (await app.members.ownerList()).items.single;
      expect(member.visits, 1);
      expect(receipt.customerPhone, '+6281234567890');
      await app.members.update(
        member.id,
        member.revision,
        profile('PUBLIC NEW NAME', '081234567891'),
      );
      final historical = await app.checkout.receipt(receipt.id);
      expect(historical.customerName, 'PUBLIC MEMBER');
      expect(historical.customerPhone, '+6281234567890');
    },
  );
  test(
    'M53 every new credit requires complete member while failed customer stage rolls back identity sale and stock',
    () async {
      await expectLater(
        sale(tender: 5000, phone: '', intent: false),
        throwsA(error('m53MemberPhoneRequired')),
      );
      final cart = await app.cart.open();
      final input = CheckoutInput(
        cash: true,
        mode: PaymentMode.partial,
        tender: m(5000),
        tenderRaw: '5000',
        memberIntent: true,
        customer: const CustomerChoice(
          name: 'PUBLIC DEBT',
          phone: '081234567890',
        ),
      );
      final failing = CheckoutService(
        db,
        app.checkout.store,
        testStage: (stage) async {
          if (stage == 'customer') throw StateError('PUBLIC MEMBER FAULT');
        },
      );
      await expectLater(
        failing.submit(cart.id, cart.revision, input),
        throwsStateError,
      );
      expect(await db.read((sql) => sql.query('customers')), isEmpty);
      expect(await db.read((sql) => sql.query('sale_transactions')), isEmpty);
      expect((await app.inventory.detail(product)).quantity, 20);
      final receipt = await app.checkout.submit(cart.id, cart.revision, input);
      expect(
        (await app.checkout.submit(cart.id, cart.revision, input)).id,
        receipt.id,
      );
      expect((await app.members.ownerList()).items.single.visits, 1);
    },
  );
  test(
    'M53 repayment adds no visit and full reversal removes exactly one completed visit',
    () async {
      final member = await app.members.create(profile('PUBLIC VISITS'));
      await sale(member: member.id, tender: 5000);
      final paid = await sale(member: member.id);
      expect((await app.members.ownerDetail(member.id)).visits, 2);
      final plan = await app.receivables.preview(member.id, m(5000));
      await app.receivables.record(plan);
      await app.receivables.record(plan);
      expect((await app.members.ownerDetail(member.id)).visits, 2);
      await app.corrections.cancelSale(
        paid.id,
        operationKey: 'public-member-reversal',
        reason: 'PUBLIC TEST',
        goodsReturned: true,
        moneyHandled: true,
      );
      expect((await app.members.ownerDetail(member.id)).visits, 1);
      expect((await app.receivables.balance(member.id)).amountMinor, 0);
    },
  );
  test(
    'M53 archive never hides existing debt and cannot be selected for new credit',
    () async {
      final member = await app.members.create(profile('PUBLIC ARCHIVE'));
      await sale(member: member.id, tender: 5000);
      await app.members.archive(member.id, member.revision, true);
      final debts = await app.receivables.customers();
      expect(debts.items.single.id, member.id);
      expect(debts.items.single.archived, isTrue);
      await expectLater(
        sale(member: member.id, tender: 5000),
        throwsA(error('m3CustomerUnavailable')),
      );
      final plan = await app.receivables.preview(member.id, m(5000));
      await app.receivables.record(plan);
      expect((await app.receivables.customers()).items, isEmpty);
    },
  );
  test(
    'M53 member keyset follows visits stable ties phone prefixes and invalidates after edits',
    () async {
      final a = await app.members.create(profile('PUBLIC A'));
      final b = await app.members.create(profile('PUBLIC B', '081234567891'));
      await app.members.create(profile('PUBLIC C', '081234567892'));
      await sale(member: b.id);
      final page = await app.members.ownerList(query: 'PUBLIC', pageSize: 1);
      expect(page.items.single.id, b.id);
      final next = await app.members.ownerList(
        query: 'PUBLIC',
        pageSize: 1,
        after: page.nextCursor,
      );
      expect(next.items.single.id, a.id);
      expect(
        (await app.members.ownerList(query: '081234567891')).items.single.id,
        b.id,
      );
      await app.members.update(a.id, a.revision, profile('PUBLIC A UPDATED'));
      await expectLater(
        app.members.ownerList(query: 'PUBLIC', after: page.nextCursor),
        throwsA(error('m3DraftChanged')),
      );
    },
  );
  test(
    'M53 direct cashier and warehouse admin calls deny owner authority; late revocation rolls profile and audit back',
    () async {
      final member = await app.members.create(profile('PUBLIC OWNER'));
      final before = await db.read((sql) => sql.query('customers'));
      final auditBefore = await db.read((sql) => sql.query('audit_log'));
      final guarded = MemberService(
        db,
        app.management,
        app.checkout.store,
        testStage: (stage) async {
          if (stage == 'write') app.management.lock();
        },
      );
      await expectLater(
        guarded.update(
          member.id,
          member.revision,
          profile('REVOKED', '081234567891'),
        ),
        throwsA(isA<AppError>()),
      );
      expect(await db.read((sql) => sql.query('customers')), before);
      expect(await db.read((sql) => sql.query('audit_log')), auditBefore);
      await app.management.unlock('0001');
      final lateRead = MemberService(
        db,
        app.management,
        app.checkout.store,
        testStage: (stage) async {
          if (stage == 'read') app.management.lock();
        },
      );
      var published = false;
      await expectLater(
        lateRead.ownerDetail(member.id).then((value) {
          published = true;
          return value;
        }),
        throwsA(isA<AppError>()),
      );
      expect(published, isFalse);
      await expectLater(
        () => app.members.ownerList(),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.members.create(profile('DENIED', '081234567891')),
        throwsA(isA<AppError>()),
      );
      await app.management.unlock('0001');
      await app.management.reauthenticate('0001', 'security');
      await app.management.setTaskPattern(
        3,
        warehousePin: '0002',
        confirmation: '0002',
      );
      await app.management.unlock('0002', role: ManagementRole.warehouse);
      await expectLater(
        () => app.members.ownerDetail(member.id),
        throwsA(error('m53OwnerRequired')),
      );
      await expectLater(
        app.members.update(
          member.id,
          member.revision,
          profile('DENIED', '081234567891'),
        ),
        throwsA(error('m53OwnerRequired')),
      );
      final cart = await basket();
      app.management.lock();
      expect(
        (await app.members.forCheckout(
          cart.id,
          query: 'PUBLIC',
        )).items.single.id,
        member.id,
      );
      expect(app.management.isUnlocked, isFalse);
    },
  );
  test(
    'M53 legacy21 invalid duplicate and blank phones migrate without rewriting old facts and all old debts remain payable',
    () async {
      final legacyPath = path();
      var legacy = DatabaseCoordinator(
        factory: factory,
        databasePath: legacyPath,
        schemaVersion: 21,
      );
      final phones = <String?>['081234567890', '+6281234567890', null, '123'];
      final ids = <EntityId>[];
      final attempts = <(EntityId, int, CheckoutInput, EntityId)>[];
      try {
        await legacy.transaction(
          (sql) => sql.insert('management_credentials', credentials),
        );
        var older = AppServices(legacy);
        await older.management.unlock('0001');
        final item = await older.inventory.create(
          ProductInput(name: 'PUBLIC LEGACY ITEM', sellingPrice: m(10000)),
          initialQuantity: 20,
          unitCost: CostAmount.fromMoney(m(5000)),
        );
        for (var i = 0; i < phones.length; i++) {
          final id = const IdGenerator().next();
          ids.add(id);
          await legacy.transaction(
            (sql) => sql.insert('customers', {
              'id': id.value,
              'name': 'PUBLIC LEGACY $i',
              'normalized_name': 'public legacy $i',
              'phone_number': phones[i],
              'created_at': 1,
            }),
          );
          var cart = await older.cart.open();
          if (cart.completedId != null) cart = await older.cart.next(cart.id);
          cart = await older.cart.add(cart.id, item);
          final input = CheckoutInput(
            mode: PaymentMode.debt,
            customer: CustomerChoice(id: id),
          );
          final receipt = await older.checkout.submit(
            cart.id,
            cart.revision,
            input,
          );
          attempts.add((cart.id, cart.revision, input, receipt.id));
        }
        final before = await legacy.read(SkybeeUpgradeAudit.capture);
        await legacy.close();
        await expectLater(
          factory.openDatabase(
            legacyPath,
            options: OpenDatabaseOptions(
              version: Schema.version,
              singleInstance: false,
              onUpgrade: (sql, from, to) async {
                await Schema.migrate(sql, from, to);
                throw StateError('PUBLIC MEMBER MIGRATION FAULT');
              },
            ),
          ),
          throwsA(
            anyOf(
              isA<StateError>().having(
                (e) => e.message,
                'fault',
                'PUBLIC MEMBER MIGRATION FAULT',
              ),
              isA<DatabaseSecurityError>().having(
                (e) => e.code,
                'native fault',
                'm5DatabaseUnlockFailed',
              ),
            ),
          ),
        );
        legacy = DatabaseCoordinator(
          factory: factory,
          databasePath: legacyPath,
          schemaVersion: 21,
        );
        await legacy.read((sql) async {
          expect(await sql.getVersion(), 21);
          await SkybeeUpgradeAudit.verify(sql, before);
        });
        await legacy.close();
        legacy = DatabaseCoordinator(
          factory: factory,
          databasePath: legacyPath,
        );
        await legacy.read((sql) => SkybeeUpgradeAudit.verify(sql, before));
        older = AppServices(legacy);
        await older.management.unlock('0001');
        for (final (draft, revision, input, receipt) in attempts) {
          expect(
            (await older.checkout.submit(draft, revision, input)).id,
            receipt,
          );
        }
        final rows = await legacy.read(
          (sql) =>
              sql.query('customers', orderBy: 'normalized_name COLLATE BINARY'),
        );
        expect(rows.map((r) => r['phone_number']).toList(), phones);
        expect(rows.map((r) => r['phone_e164']).toList(), [
          '+6281234567890',
          '+6281234567890',
          null,
          null,
        ]);
        expect(
          rows.every((r) => r['profile_version'] == 0 && r['visit_count'] == 1),
          isTrue,
        );
        expect(
          (await older.members.ownerList(query: '123')).items.single.id,
          ids[3],
        );
        final metadata = await manifest(legacy);
        await legacy.read((sql) => BackupValidation.validate(sql, metadata));
        final last = await older.cart.open();
        var newCart = await older.cart.next(last.id);
        newCart = await older.cart.add(newCart.id, item);
        for (final id in ids) {
          await expectLater(
            older.checkout.submit(
              newCart.id,
              newCart.revision,
              CheckoutInput(
                mode: PaymentMode.debt,
                customer: CustomerChoice(id: id),
              ),
            ),
            throwsA(error('m53MemberRepairRequired')),
          );
        }
        await older.members.archive(ids[2], 0, true);
        expect((await older.receivables.customers()).items.length, 4);
        for (final id in ids) {
          final plan = await older.receivables.preview(id, m(10000));
          await older.receivables.record(plan);
          await older.receivables.record(plan);
          expect((await older.receivables.balance(id)).amountMinor, 0);
        }
        expect((await older.receivables.customers()).items, isEmpty);
        expect(
          (await legacy.read((sql) => sql.query('sale_transactions'))).length,
          4,
        );
        expect(
          (await legacy.read(
            (sql) => sql.query(
              'customers',
              orderBy: 'normalized_name COLLATE BINARY',
            ),
          )).map((r) => r['phone_number']).toList(),
          phones,
        );
        await legacy.read((sql) => BackupValidation.validate(sql, metadata));
      } finally {
        await legacy.close();
        await factory.deleteDatabase(legacyPath);
      }
    },
  );
  test(
    'M53 backup rejects forged visit cache and validated phone metadata without rejecting valid member snapshots',
    () async {
      final member = await app.members.create(
        profile('PUBLIC ARCHIVE VALIDATION'),
      );
      await sale(member: member.id);
      final metadata = await manifest(db);
      await db.read((sql) => BackupValidation.validate(sql, metadata));
      await db.transaction(
        (sql) => sql.update(
          'customers',
          {'visit_count': 0},
          where: 'id=?',
          whereArgs: [member.id.value],
        ),
      );
      await expectLater(
        db.read((sql) => BackupValidation.validate(sql, metadata)),
        throwsFormatException,
      );
      await db.transaction((sql) async {
        await sql.update(
          'customers',
          {'visit_count': 1},
          where: 'id=?',
          whereArgs: [member.id.value],
        );
        await sql.execute('DROP TRIGGER member_phone_update');
        await sql.update(
          'customers',
          {'phone_e164': '+6281234567891'},
          where: 'id=?',
          whereArgs: [member.id.value],
        );
      });
      await expectLater(
        db.read((sql) => BackupValidation.validate(sql, metadata)),
        throwsFormatException,
      );
    },
  );
  test(
    'M53 explicitly selected paid sale can retain incomplete legacy member while new credit requires repair',
    () async {
      final id = const IdGenerator().next();
      await db.transaction(
        (sql) => sql.insert('customers', {
          'id': id.value,
          'name': 'PUBLIC INCOMPLETE',
          'normalized_name': 'public incomplete',
          'phone_number': null,
          'created_at': 1,
        }),
      );
      final receipt = await sale(member: id);
      expect(receipt.customerName, 'PUBLIC INCOMPLETE');
      expect(receipt.customerPhone, isNull);
      await expectLater(
        sale(member: id, tender: 5000),
        throwsA(error('m53MemberRepairRequired')),
      );
      expect((await app.members.ownerDetail(id)).visits, 1);
    },
  );
  test(
    'M53 reopening implicit credit preserves guest choice separately from explicit paid member opt-in',
    () async {
      final snapshot = await basket();
      final cart = CartProvider(app.cart)..snapshot = snapshot;
      CheckoutProvider? form = CheckoutProvider(cart, app.cart, app.checkout);
      try {
        await form.receive(m(5000));
        expect(form.needsCustomer, isTrue);
        expect(form.useMember, isFalse);
        form.dispose();
        form = null;
        await cart.refresh();
        form = CheckoutProvider(cart, app.cart, app.checkout);
        expect(form.useMember, isFalse);
        await form.exact();
        expect(form.needsMember, isFalse);
        form.setUseMember(true);
        await form.persist();
        form.dispose();
        form = null;
        await cart.refresh();
        form = CheckoutProvider(cart, app.cart, app.checkout);
        expect(form.useMember, isTrue);
        expect(form.needsMember, isTrue);
        expect(form.hasUnsavedInput, isFalse);
      } finally {
        form?.dispose();
        cart.dispose();
      }
    },
  );
}
