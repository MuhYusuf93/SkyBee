import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/settings/presentation/language_button.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..defaultTestTimeout = const Timeout(Duration(minutes: 5))
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  // Bootstrap the native fixture surface before async database setup.
  runApp(const SizedBox.expand());
  for (final usd in [false, true]) {
    testWidgets(
      usd
          ? 'M3 USD partial payment live locale and explicit same-name customer selection'
          : 'M3 three scans weighted checkout double-submit restart recovery and public settlement',
      (tester) async {
        var phase = 'fixture';
        final previousError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) {
            debugPrint(
              'DV8910_LAYOUT phase=$phase ${details.exceptionAsString()}',
            );
          }
          previousError?.call(details);
        };
        final databasePath = path.join(
          await getDatabasesPath(),
          'm3_ui_${DateTime.now().microsecondsSinceEpoch}.db',
        );
        final db = DatabaseCoordinator(
          factory: databaseFactory,
          databasePath: databasePath,
        );
        final services = AppServices(db);
        Future<void> waitFor(Finder finder) async {
          final timer = Stopwatch()..start();
          while (finder.evaluate().isEmpty &&
              timer.elapsed < const Duration(seconds: 90)) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(finder, findsWidgets);
          await tester.pumpAndSettle();
        }

        Finder field(String label) => find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              (widget.decoration?.labelText == label ||
                  (widget.decoration?.labelText?.startsWith('$label (') ??
                      false)),
        );
        Future<void> tap(Finder finder) async {
          phase = 'tap $finder';
          if (finder.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              finder,
              180,
              scrollable: find.byType(Scrollable).first,
            );
          }
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        Future<void> fill(String label, String value) async {
          phase = 'field $label';
          final finder = field(label);
          if (finder.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              finder,
              180,
              scrollable: find.byType(Scrollable).first,
            );
          }
          await tester.ensureVisible(finder);
          await tester.enterText(finder, value);
          await tester.pump();
        }

        Future<void> language(String code) async {
          await tap(find.byType(LanguageButton).last);
          await tap(
            find
                .text(code == 'id' ? 'ID · Bahasa Indonesia' : 'EN · English')
                .last,
          );
        }

        try {
          String? selectedId;
          debugPrint('M3_FIXTURE_PHASE before seed IO');
          await tester.runAsync(() async {
            await services.management.configure(
              'Synthetic M3 store',
              '0001',
              '0001',
            );
            await services.management.unlock('0001');
            if (usd) await services.settings.setCurrency('USD');
            await services.settings.setLanguage(usd ? 'en' : 'id');
            final policy = CurrencyPolicy.forCode(usd ? 'USD' : 'IDR');
            final product = await services.inventory.create(
              ProductInput(
                name: 'Le Minerale user name',
                sellingPrice: Money(
                  usd ? 2000 : 12000,
                  policy.code,
                  policy.scale,
                ),
                sku: 'M3-ITEM',
                barcode: '000123',
                aliases: const ['air mineral'],
              ),
              initialQuantity: usd ? 3 : 10,
              unitCost: CostAmount.fromMoney(
                Money(usd ? 1 : 8000, policy.code, policy.scale),
              ),
            );
            if (!usd) {
              await services.inventory.receive(
                product,
                10,
                CostAmount.fromMoney(Money(10000, 'IDR', 0)),
                operationKey: 'm3-ui-receipt',
              );
            }
            if (usd) {
              await db.transaction((dbTxn) async {
                for (var index = 0; index < 2; index++) {
                  final id = const IdGenerator().next().value;
                  if (index == 1) selectedId = id;
                  await dbTxn.insert('customers', {
                    'id': id,
                    'name': 'Morgan',
                    'normalized_name': 'morgan',
                    'phone_number': index == 0 ? '001' : '002',
                    'created_at': 1,
                  });
                }
              });
            }
            services.management.lock();
          });
          debugPrint('M3_FIXTURE_PHASE before application pump');
          await tester.pumpWidget(KasirApp(services: services));
          final searchLabel = usd ? 'Search products' : 'Cari barang';
          await waitFor(field(searchLabel));
          final scans = usd ? 1 : 3;
          for (var index = 0; index < scans; index++) {
            await fill(searchLabel, '000123');
            await tester.testTextInput.receiveAction(TextInputAction.search);
            final timer = Stopwatch()..start();
            while (timer.elapsed < const Duration(seconds: 30)) {
              await tester.pump(const Duration(milliseconds: 200));
              final cart = await services.cart.open();
              if (cart.lines.singleOrNull?.quantity == index + 1) break;
            }
          }
          final draft = await services.cart.open();
          expect(draft.lines.single.quantity, scans);
          expect(draft.lines.length, 1);
          await tap(find.text(usd ? 'Pay' : 'Bayar'));
          await waitFor(find.text(usd ? 'Paid in full' : 'Lunas'));
          expect(field(usd ? 'Customer name' : 'Nama pelanggan'), findsNothing);
          await tap(find.text(usd ? 'Partly on credit' : 'Sebagian hutang'));
          await fill(
            usd ? 'Amount paid' : 'Nominal dibayar',
            usd ? '15.50' : '10000',
          );
          await fill(
            usd ? 'Customer name' : 'Nama pelanggan',
            usd ? 'Morgan' : 'Alex',
          );
          if (usd) {
            // On short TV viewports the lazy customer suggestion may sit below
            // the edited name. Drain the lookup and reveal it before waiting.
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 500)),
            );
            await tester.pumpAndSettle();
            if (find.text('002').evaluate().isEmpty) {
              await tester.scrollUntilVisible(
                find.text('002'),
                180,
                scrollable: find.byType(Scrollable).first,
              );
            }
            await waitFor(find.text('002'));
            await tap(find.text('002'));
            await language('id');
            await waitFor(field('Nominal dibayar'));
            expect(
              tester
                  .widget<TextField>(field('Nominal dibayar'))
                  .controller!
                  .text,
              '15,50',
            );
            expect(
              tester
                  .widget<TextField>(field('HP pelanggan (opsional)'))
                  .controller!
                  .text,
              '002',
            );
          } else {
            await fill('HP pelanggan (opsional)', '00123');
          }
          final save = find.text('Simpan penjualan');
          if (save.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              save,
              200,
              scrollable: find.byType(Scrollable).first,
            );
          }
          await tester.ensureVisible(save);
          await tester.tap(save);
          await tester.tap(save); // Second tap cannot duplicate commit.
          await waitFor(find.text('Penjualan berhasil disimpan.'));
          final rows = await db.read(
            (database) => database.query('sale_transactions'),
          );
          expect(rows.length, 1);
          expect(rows.single['total_rupiah'], usd ? 2000 : 36000);
          expect(rows.single['cost_micros'], usd ? 1000000 : 27000000000);
          if (usd) {
            expect(rows.single['customer_id'], selectedId);
            expect(rows.single['currency_code'], 'USD');
            expect(rows.single['currency_scale'], 2);
          } else {
            // Recreate the UI after commit, before acknowledgement: recovery must
            // show the saved result and not create/re-sell an active basket.
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
            await tester.pumpWidget(KasirApp(services: services));
            await waitFor(
              find.text(
                'Penjualan tersimpan dipulihkan. Belanja ini sudah selesai.',
              ),
            );
            expect(
              (await services.cart.open()).completedId,
              EntityId(rows.single['id'] as String),
            );
            await tap(find.text('Belanja berikutnya'));
            await waitFor(field('Cari barang'));
            await tap(find.text('Hutang'));
            await waitFor(find.text('Alex'));
            await tap(find.text('Alex'));
            await waitFor(field('Nominal pelunasan'));
            await fill('Nominal pelunasan', '26000');
            await tap(find.text('Catat pembayaran'));
            await waitFor(find.text('Rincian pembayaran hutang'));
            await tap(find.text('Catat pembayaran ini'));
            final customer = EntityId(rows.single['customer_id'] as String);
            final timer = Stopwatch()..start();
            while ((await services.receivables.balance(customer)).amountMinor !=
                    0 &&
                timer.elapsed < const Duration(seconds: 30)) {
              await tester.pump(const Duration(milliseconds: 200));
            }
            await tester.pumpAndSettle();
            expect(
              (await services.receivables.balance(customer)).amountMinor,
              0,
            );
            expect(
              (await db.read(
                (database) => database.query('sale_transactions'),
              )).length,
              1,
            );
            expect(
              (await db.read((database) => database.query('payments'))).length,
              2,
            );
            await expectLater(
              services.history.detail(EntityId(rows.single['id'] as String)),
              throwsA(isA<AppError>()),
            );
          }
          expect(tester.takeException(), isNull);
        } finally {
          FlutterError.onError = previousError;
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await db.close();
          await databaseFactory.deleteDatabase(databasePath);
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}
