import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..defaultTestTimeout = const Timeout(Duration(minutes: 5))
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  // Draw the isolated window before widget-test platform IO begins.
  runApp(const SizedBox.expand());
  testWidgets(
    'Android setup PIN → warehouse product/receipt → average → background lock',
    (tester) async {
      final databasePath = path.join(
        await getDatabasesPath(),
        'm2_ui_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final database = DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: databasePath,
      );
      var now = DateTime.utc(2026, 10, 12, 17);
      final services = AppServices(
        database,
        clock: StoreClock(
          now: () => now,
          elapsedMilliseconds: () => now.millisecondsSinceEpoch,
        ),
      );
      Future<void> waitFor(Finder finder) async {
        final timer = Stopwatch()..start();
        while (finder.evaluate().isEmpty &&
            timer.elapsed < const Duration(seconds: 90)) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(finder, findsWidgets);
      }

      Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      Future<void> show(Finder target) async {
        if (target.evaluate().isEmpty) {
          final scrollable = find.byType(Scrollable).first;
          tester.state<ScrollableState>(scrollable).position.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(target, 180, scrollable: scrollable);
        }
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
      }

      Future<void> tap(Finder target, {bool unfocus = true}) async {
        if (unfocus) FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await show(target);
        // Live Android frames can still have a route/inset transition absorbing
        // the pointer after the test clock has settled. Require an actual hit;
        // never suppress the warning or accept an unsaved product as success.
        final hitWatch = Stopwatch()..start();
        while (target.hitTestable().evaluate().isEmpty &&
            hitWatch.elapsed < const Duration(seconds: 4)) {
          debugPrint(
            'M2_HIT_WAIT target=$target rect=${tester.getRect(target)}',
          );
          await Scrollable.ensureVisible(tester.element(target), alignment: .5);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(target.hitTestable(), findsWidgets);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      Future<void> fill(String label, String value) async {
        final target = field(label);
        await show(target);
        await tester.enterText(target, value);
      }

      try {
        debugPrint('M2_FIXTURE_PHASE before language IO');
        await tester.runAsync(() => services.settings.setLanguage('id'));
        debugPrint('M2_FIXTURE_PHASE before application pump');
        await tester.pumpWidget(KasirApp(services: services));
        debugPrint('M2_FIXTURE_PHASE application pumped');
        await waitFor(field('Cari barang'));
        await tap(find.text('Kelola'));
        await waitFor(find.text('Buat PIN pengelolaan'));
        await fill('Nama toko', 'Toko pengujian');
        await fill('PIN baru', '0001');
        await fill('Konfirmasi PIN baru', '0001');
        await tap(find.widgetWithText(FilledButton, 'Simpan'));
        await waitFor(find.text('Simpan kode pemulihan'));
        await tap(find.text('Sudah saya simpan'));
        await waitFor(find.text('Kelola'));
        await waitFor(find.text('Toko pengujian'));
        await tap(find.text('Kelola'));
        await waitFor(find.text('Akses pengelolaan'));
        await fill('PIN', '0001');
        await tap(find.text('Buka pengelolaan'));
        await waitFor(find.text('Pengelolaan'));
        await tap(find.text('Gudang'));
        await waitFor(find.text('Tambah barang'));
        await tap(find.text('Kategori'));
        await waitFor(find.text('Tambah kategori'));
        await tap(find.text('Tambah kategori'));
        await waitFor(field('Nama'));
        await fill('Nama', 'Minuman');
        await tap(find.widgetWithText(FilledButton, 'Simpan'));
        await waitFor(find.widgetWithText(ListTile, 'Minuman'));
        await tester.pumpAndSettle();
        await tap(find.text('Barang'));
        await waitFor(find.text('Tambah barang'));
        await tap(find.text('Tambah barang'));
        await waitFor(field('Nama barang'));
        await fill('Nama barang', 'Barang contoh');
        await fill('Harga jual (IDR)', '12000');
        // Dismiss the editing focus and reveal the expansion on short TV forms.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();
        await tap(find.text('Stok awal & harga beli'));
        await tester.pumpAndSettle();
        await waitFor(field('Jumlah awal'));
        await fill('Jumlah awal', '10');
        await fill('Harga beli per pcs (IDR)', '8000');
        await tap(find.text('Stok awal & harga beli'));
        await tester.pumpAndSettle();
        await tap(find.text('Kode, barcode & kategori'));
        await tester.pumpAndSettle();
        await fill('Kategori (opsional)', 'Min');
        await waitFor(find.widgetWithText(ListTile, 'Minuman'));
        // Autocomplete must retain editing focus until the option is selected.
        await tap(find.widgetWithText(ListTile, 'Minuman'), unfocus: false);
        await tap(find.text('Simpan barang'));
        await waitFor(find.text('Gudang'));
        await tester.pumpAndSettle();
        await waitFor(find.text('Barang contoh'));
        await tap(find.widgetWithText(ListTile, 'Barang contoh'));
        await waitFor(find.text('Barang masuk'));
        await tap(find.text('Barang masuk'));
        await waitFor(field('Jumlah unit'));
        await fill('Jumlah unit', '10');
        await fill('Harga beli per pcs (IDR)', '10000');
        await tap(find.widgetWithText(FilledButton, 'Simpan'));
        await waitFor(find.text('Harga beli rata-rata IDR 9.000'));
        await tester.pumpAndSettle();
        await tap(find.text('Ubah barang'));
        await waitFor(field('Harga jual (IDR)'));
        await fill('Harga jual (IDR)', '15000');
        await tap(find.text('Simpan barang'));
        await waitFor(find.text('Harga jual IDR 15.000'));
        await tester.pumpAndSettle();
        await tap(find.text('Urungkan'));
        await waitFor(find.text('Harga jual IDR 12.000'));
        await tester.pumpAndSettle();
        await tap(find.text('Ubah barang'));
        await waitFor(field('Harga jual (IDR)'));
        now = now.add(const Duration(minutes: 4));
        await fill('Harga jual (IDR)', '14000');
        now = now.add(const Duration(minutes: 2));
        expect(services.management.isUnlocked, true);
        await tester.pumpAndSettle();
        await tap(find.byType(BackButton).last);
        await waitFor(find.text('Harga jual IDR 12.000'));
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        expect(services.management.isUnlocked, false);
        // Live binding cannot render while paused. Assert the synchronous gate
        // now; inspect the concealed UI after resumed re-enables native frames.
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pump();
        expect(find.text('Pengelolaan terkunci'), findsWidgets);
        expect(tester.takeException(), isNull);
      } finally {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(const SizedBox());
        await database.close();
        await databaseFactory.deleteDatabase(databasePath);
      }
    },
  );
}
