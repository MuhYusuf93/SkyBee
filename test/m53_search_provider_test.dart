import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/features/cashier/application/product_search_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/domain/product_search_page.dart';
import 'package:kasir_app/features/cashier/presentation/product_search_provider.dart';
import 'support/database_contract_suite.dart';

final class PagedFixture implements PagedProductSearch {
  final events = StreamController<void>.broadcast();
  final requests =
      <
        ({
          String query,
          ProductSearchOrder order,
          ProductSearchCursor? after,
          Completer<ProductSearchPage> result,
        })
      >[];
  final scans = <Completer<CashierProduct>>[];
  @override
  Stream<void> get invalidations => events.stream;
  @override
  Future<List<CashierProduct>> suggest(String text) =>
      throw StateError('paged path required');
  @override
  Future<CashierProduct> scan(String code) =>
      (scans..add(Completer<CashierProduct>())).last.future;
  @override
  Future<ProductSearchPage> page(
    String text, {
    ProductSearchOrder order = ProductSearchOrder.frequent,
    ProductSearchCursor? after,
    int pageSize = 16,
  }) {
    final result = Completer<ProductSearchPage>();
    requests.add((query: text, order: order, after: after, result: result));
    return result.future;
  }
}

ProductSearchPage page(int start, {bool last = false}) => ProductSearchPage(
  items: List.generate(
    16,
    (i) => CashierProduct({
      ...productRow(start + i, 'Public ${start + i}'),
      'currency_code': 'IDR',
      'currency_scale': 0,
      'revision': 0,
      'is_deleted': 0,
    }, 1),
  ),
  windowFrom: 1,
  windowThrough: 2,
  nextCursor: last
      ? null
      : ProductSearchCursor(
          query: 'b',
          order: ProductSearchOrder.frequent,
          generation: 0,
          catalogueEpoch: 1,
          cacheRevision: 1,
          storeDay: '2026-10-27',
          timeZone: 'Asia/Jakarta',
          codeTier: 1,
          eligibility: 0,
          receipts: 0,
          quantity: 0,
          relevance: 2,
          name: 'public',
          id: EntityId(fixtureId(start + 15)),
        ),
);
Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  late PagedFixture service;
  late ProductSearchProvider provider;
  setUp(() {
    service = PagedFixture();
    provider = ProductSearchProvider(service, delay: Duration.zero);
  });
  tearDown(() async {
    provider.dispose();
    await service.events.close();
  });
  Future<void> initial() async {
    provider.change('b');
    await tick();
    service.requests.last.result.complete(page(1));
    await tick();
  }

  test(
    'M53 paged view bounds memory to 48 while retaining forward cursor',
    () async {
      await initial();
      for (final start in [17, 33, 49]) {
        final work = provider.more();
        service.requests.last.result.complete(page(start));
        await work;
      }
      expect(provider.results.length, 48);
      expect(provider.results.first.id.value, fixtureId(17));
      expect(provider.results.last.id.value, fixtureId(64));
      expect(provider.hasMore, isTrue);
    },
  );
  test(
    'M53 late page cannot replace newer query/order and stale cursor restarts first page',
    () async {
      await initial();
      final old = provider.more();
      final oldRequest = service.requests.last;
      provider.setOrder(ProductSearchOrder.relevance);
      await tick();
      final newest = service.requests.last;
      oldRequest.result.complete(page(17));
      await old;
      expect(provider.results, isEmpty);
      expect(provider.loadingMore, isFalse);
      newest.result.complete(page(65));
      await tick();
      expect(provider.results.first.id.value, fixtureId(65));
      final stale = provider.more();
      service.requests.last.result.completeError(
        const AppError('m3DraftChanged'),
      );
      await stale;
      await tick();
      expect(service.requests.last.after, isNull);
      expect(service.requests.last.order, ProductSearchOrder.relevance);
      service.requests.last.result.complete(page(81));
      await tick();
      expect(provider.results.first.id.value, fixtureId(81));
    },
  );
  test(
    'M53 explicit scan supersedes pending paging and leaves no stuck loading state',
    () async {
      await initial();
      final more = provider.more();
      final oldRequest = service.requests.last;
      final scan = provider.scan('0001');
      expect(provider.loadingMore, isFalse);
      expect(provider.hasMore, isFalse);
      oldRequest.result.complete(page(17));
      await more;
      service.scans.last.complete(page(1).items.first);
      expect(await scan, isNotNull);
      expect(provider.loading, isFalse);
      expect(provider.loadingMore, isFalse);
    },
  );
  test(
    'M53 invalidation preserves query but rejects an older result; clear prevents background requery',
    () async {
      await initial();
      provider.refresh();
      await tick();
      final old = service.requests.last;
      service.events.add(null);
      await tick();
      await tick();
      final newest = service.requests.last;
      expect(newest.query, 'b');
      old.result.complete(page(17));
      await tick();
      expect(provider.results, isEmpty);
      newest.result.complete(page(33));
      await tick();
      expect(provider.results.first.id.value, fixtureId(33));
      provider.change('');
      final count = service.requests.length;
      service.events.add(null);
      await tick();
      expect(service.requests.length, count);
      expect(provider.results, isEmpty);
    },
  );
}
