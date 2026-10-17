import 'dart:convert';
import 'dart:async';
import 'dart:ui' show FrameTiming;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/presentation/product_search_provider.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';

/// Test-only process-restart/release harness, never the operational entrypoint.
/// Fixed clock and fixture credentials live only in the integration sandbox.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST')) {
    throw StateError('Fixture isolation flag required');
  }
  runApp(const MaterialApp(home: _Probe()));
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  AppServices? services;
  Map<String, Object?>? nativeBackend;
  Map<String, Object?> result = {'stage': 'loading'};
  bool actual = false, busy = true;
  final buildUs = <int>[], rasterUs = <int>[];
  int framesSeen = 0;
  Timer? probeTimer;
  bool readingProbe = false;
  static const fixturePin = '0001';
  CheckoutInput get payment => CheckoutInput(
    mode: PaymentMode.partial,
    paid: Money(10000, 'IDR', 0),
    customer: const CustomerChoice(name: 'Synthetic Realme C11 customer'),
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addTimingsCallback(recordFrames);
    probeTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (actual && services != null) unawaited(reportUiState());
    });
    load();
  }

  /// Only synthetic fixture metadata. Does not mutate or log product/customer
  /// names. Useful to distinguish ADB input from hardware-scanner evidence.
  Future<void> reportUiState() async {
    if (readingProbe) return;
    readingProbe = true;
    try {
      final data = await services!.database.read((d) async {
        final cart = (await d.rawQuery(
          '''SELECT d.state,
          (SELECT COUNT(*) FROM cart_draft_items i WHERE i.draft_id=d.id) AS rows,
          (SELECT COALESCE(SUM(i.quantity),0) FROM cart_draft_items i WHERE i.draft_id=d.id) AS quantity
          FROM cart_drafts d JOIN cashier_state s ON s.draft_id=d.id''',
        )).single;
        return {
          'draft_state': cart['state'],
          'cart_rows': cart['rows'],
          'cart_quantity': cart['quantity'],
          'sales': (await d.rawQuery(
            'SELECT COUNT(*) AS n FROM sale_transactions',
          )).single['n'],
          'stock': (await d.rawQuery(
            'SELECT SUM(stock_quantity) AS n FROM products',
          )).single['n'],
        };
      });
      debugPrint('REALME_UI_STATE ${jsonEncode(data)}');
    } on Object catch (e) {
      debugPrint('REALME_UI_STATE_ERROR ${e.runtimeType}');
    } finally {
      readingProbe = false;
    }
  }

  void recordFrames(List<FrameTiming> timings) {
    for (final timing in timings) {
      framesSeen++;
      buildUs.add(timing.buildDuration.inMicroseconds);
      rasterUs.add(timing.rasterDuration.inMicroseconds);
      if (buildUs.length > 240) {
        buildUs.removeAt(0);
        rasterUs.removeAt(0);
      }
    }
  }

  void frameSummary() {
    int maximum(List<int> values) => values.fold(0, (a, b) => a > b ? a : b);
    debugPrint(
      'REALME_FRAMES ${jsonEncode({'scope': 'rolling harness/actual cashier initial frames; not sustained jank acceptance', 'frames_seen': framesSeen, 'rolling_samples': buildUs.length, 'max_build_us': maximum(buildUs), 'max_raster_us': maximum(rasterUs)})}',
    );
  }

  @override
  void dispose() {
    probeTimer?.cancel();
    WidgetsBinding.instance.removeTimingsCallback(recordFrames);
    super.dispose();
  }

  void verify(bool condition, String name) {
    if (!condition) {
      throw StateError('Fixture invariant: $name');
    }
  }

  void publish(Map<String, Object?> value) {
    value = {'native_backend': nativeBackend, ...value};
    // Metadata/amounts only; never verifier, PIN, customer or raw SQL payload.
    debugPrint('REALME_SMOKE ${jsonEncode(value)}');
    if (mounted) {
      setState(() {
        result = value;
        busy = false;
      });
    }
  }

  Future<void> load() async {
    try {
      nativeBackend = await const MethodChannel(
        'kasir_app/pin_kdf',
      ).invokeMapMethod<String, Object?>('backendInfo');
      verify(
        nativeBackend?['available'] == true &&
            nativeBackend?['mainThread'] == false,
        'native KDF available off UI thread',
      );
      final db = DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: path.join(
          await getDatabasesPath(),
          'realme_restart_20261015.db',
        ),
      );
      final timer = Stopwatch()..start();
      final s = services = AppServices(
        db,
        clock: StoreClock(
          now: () => DateTime.utc(2026, 10, 15, 3),
          elapsedMilliseconds: () => timer.elapsedMilliseconds,
        ),
      );
      await db.transaction(
        (t) => t.execute(
          'CREATE TABLE IF NOT EXISTS realme_probe (id INTEGER PRIMARY KEY, phase TEXT NOT NULL, launches INTEGER NOT NULL, device_anchor_ms INTEGER NOT NULL)',
        ),
      );
      var rows = await db.read((d) => d.query('realme_probe'));
      final fresh = rows.isEmpty;
      if (fresh) {
        await s.management.configure(
          'Synthetic Realme C11 test',
          fixturePin,
          fixturePin,
        );
        await s.management.unlock(fixturePin);
        final product = await s.inventory.create(
          ProductInput(
            name: 'Realme C11 fixture goods',
            barcode: '000123',
            sellingPrice: Money(12000, 'IDR', 0),
            wholesalePrice: Money(10000, 'IDR', 0),
            packLabel: 'dus',
            packSize: 40,
          ),
          initialQuantity: 10,
          unitCost: CostAmount.fromMoney(Money(8000, 'IDR', 0)),
        );
        await s.inventory.receive(
          product,
          10,
          CostAmount.fromMoney(Money(10000, 'IDR', 0)),
          operationKey: 'realme-smoke-restock',
        );
        final weighted = await s.inventory.detail(product);
        verify(
          weighted.quantity == 20 && weighted.valueMicros == 180000000000,
          'actual moving average 10x8000 plus 10x10000',
        );
        var cart = await s.cart.open();
        await s.cart.add(cart.id, product);
        await s.cart.quantity(cart.id, product, 3);
        await db.transaction(
          (t) => t.insert('realme_probe', {
            'id': 1,
            'phase': 'draft',
            'launches': 0,
            'device_anchor_ms': DateTime.now().millisecondsSinceEpoch,
          }),
        );
        rows = await db.read((d) => d.query('realme_probe'));
      }
      // A new process must begin locked even though credential hashes persist.
      if (!fresh) {
        var locked = false;
        try {
          s.management.requireAccess();
        } on AppError {
          locked = true;
        }
        verify(locked, 'restart management lock');
      }
      final launch = (rows.single['launches'] as int) + 1;
      await db.transaction(
        (t) => t.update('realme_probe', {'launches': launch}, where: 'id=1'),
      );
      final cart = await s.cart.open();
      if (rows.single['phase'] == 'draft') {
        verify(cart.lines.single.quantity == 3, 'persisted draft quantity');
        final stocks = await db.read((d) => d.query('products'));
        verify(stocks.single['stock_quantity'] == 20, 'draft leaves stock');
        s.management.lock();
        publish({
          'stage': launch > 1 ? 'draft_recovered' : 'draft_seeded',
          'launches': launch,
          'draft_quantity': 3,
          'stock': 20,
          'management_locked': true,
        });
      } else {
        verify(cart.completedId != null, 'completed recovery pointer');
        final receipt = await s.checkout.submit(
          cart.id,
          cart.revision,
          payment,
        );
        verify(receipt.id == cart.completedId, 'retry original sale');
        final pinWatch = Stopwatch()..start();
        await s.management.unlock(fixturePin);
        pinWatch.stop();
        final searchWatch = Stopwatch()..start();
        verify((await s.search.suggest('000123')).isNotEmpty, 'barcode search');
        searchWatch.stop();
        final reportWatch = Stopwatch()..start();
        final report = await s.reports.summary(
          await s.reports.period(
            CalendarDate('2026-10-01'),
            CalendarDate('2026-10-31'),
          ),
        );
        reportWatch.stop();
        verify(
          report.saleCount == 1 &&
              report.salesMinor == 36000 &&
              report.costMicros == 27000000000 &&
              report.grossProfitMicros == BigInt.from(9000000000) &&
              report.receivablesMinor == 26000 &&
              report.inventoryQuantity == 17,
          'checkout report and stock',
        );
        verify((await s.reports.reconcile()).consistent, 'reconciliation');
        final searchSamples = <int>[], reportSamples = <int>[];
        for (var sample = 0; sample < 5; sample++) {
          final searchTimer = Stopwatch()..start();
          verify(
            (await s.search.suggest('000123')).isNotEmpty,
            'repeat search',
          );
          searchSamples.add(searchTimer.elapsedMicroseconds);
          final reportTimer = Stopwatch()..start();
          final repeated = await s.reports.summary(
            await s.reports.period(
              CalendarDate('2026-10-01'),
              CalendarDate('2026-10-31'),
            ),
          );
          verify(
            repeated.saleCount == 1 && repeated.salesMinor == 36000,
            'repeat summary stable',
          );
          reportSamples.add(reportTimer.elapsedMicroseconds);
        }
        s.management.lock();
        publish({
          'search_5_samples_us': searchSamples,
          'report_5_samples_us': reportSamples,
          'sample_scope':
              'service latency small fixture; no debounce/UI/large-dataset claim',
          'stage': 'committed_recovered',
          'pin_verification_us': pinWatch.elapsedMicroseconds,
          'launches': launch,
          'sales': 1,
          'revenue': 36000,
          'cost': 27000,
          'gross_profit': 9000,
          'debt': 26000,
          'stock': 17,
          'retry_same_sale': true,
          'reconciled': true,
          'search_us_single_sample': searchWatch.elapsedMicroseconds,
          'report_us_single_sample': reportWatch.elapsedMicroseconds,
          'management_locked': true,
        });
      }
    } on Object catch (e) {
      publish({'stage': 'failed', 'error_type': e.runtimeType.toString()});
    }
  }

  Future<void> commit() async {
    setState(() => busy = true);
    try {
      final s = services!;
      final cart = await s.cart.open();
      final checkoutWatch = Stopwatch()..start();
      await s.checkout.submit(cart.id, cart.revision, payment);
      checkoutWatch.stop();
      await s.database.transaction(
        (t) => t.update('realme_probe', {'phase': 'committed'}, where: 'id=1'),
      );
      publish({
        'stage': 'committed_before_acknowledgement',
        'restart_required': true,
        'checkout_us_single_sample': checkoutWatch.elapsedMicroseconds,
        'sample_scope':
            'small weighted fixture, checkout service through commit',
      });
    } on Object catch (e) {
      publish({'stage': 'failed', 'error_type': e.runtimeType.toString()});
    }
  }

  /// Separate opt-in sample phase, so the recovery timing remains comparable
  /// to the earlier harness. Includes the real 275ms debounce, not UI rendering.
  Future<void> measureDebounce() async {
    setState(() => busy = true);
    final provider = ProductSearchProvider(services!.search);
    try {
      final samples = <int>[];
      for (var i = 0; i < 5; i++) {
        final complete = Completer<void>();
        void changed() {
          if (!provider.loading && !complete.isCompleted) complete.complete();
        }

        provider.addListener(changed);
        final timer = Stopwatch()..start();
        provider.change('000123');
        await complete.future.timeout(const Duration(seconds: 10));
        samples.add(timer.elapsedMicroseconds);
        provider.removeListener(changed);
        verify(
          provider.error == null && provider.results.isNotEmpty,
          'debounced search',
        );
      }
      publish({
        ...result,
        'debounced_search_5_samples_us': samples,
        'debounced_scope':
            'production Provider 275ms debounce + service; no keyboard/render/transport claim',
      });
    } on Object catch (error) {
      publish({'stage': 'failed', 'error_type': error.runtimeType.toString()});
    } finally {
      provider.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (actual) return KasirApp(services: services);
    return Scaffold(
      appBar: AppBar(title: const Text('Realme C11 isolated test')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            jsonEncode(result),
            maxLines: 12,
            overflow: TextOverflow.ellipsis,
          ),
          if (busy) const LinearProgressIndicator(),
          if (result['stage'] == 'committed_recovered')
            FilledButton(
              onPressed: busy ? null : measureDebounce,
              child: const Text('MEASURE DEBOUNCED SEARCH'),
            ),
          FilledButton(
            onPressed: busy || result['stage'] == 'committed_recovered'
                ? null
                : commit,
            child: const Text('COMMIT FIXTURE'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () {
                    setState(() => actual = true);
                    Future<void>.delayed(
                      const Duration(seconds: 3),
                      frameSummary,
                    );
                  },
            child: const Text('OPEN CASHIER'),
          ),
        ],
      ),
    );
  }
}
