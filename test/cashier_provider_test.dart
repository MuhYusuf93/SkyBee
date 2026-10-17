import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/features/cashier/application/product_search_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/presentation/product_search_provider.dart';
import 'support/database_contract_suite.dart';

final class DeferredSearch implements ProductSearch {
  final suggestions = <String, Completer<List<CashierProduct>>>{};
  final scans = <Completer<CashierProduct>>[];
  @override
  Future<List<CashierProduct>> suggest(String text) =>
      (suggestions[text] = Completer<List<CashierProduct>>()).future;
  @override
  Future<CashierProduct> scan(String code) {
    final request = Completer<CashierProduct>();
    scans.add(request);
    return request.future;
  }
}

CashierProduct sample(int id) => CashierProduct({
  ...productRow(id, 'Fixture $id'),
  'currency_code': 'IDR',
  'currency_scale': 0,
  'revision': 0,
  'is_deleted': 0,
}, 10);
void main() {
  test('late successful scan cannot clear a newer failed scan/input', () async {
    final service = DeferredSearch();
    final provider = ProductSearchProvider(service);
    final earlier = provider.scan('known');
    final version = provider.inputVersion;
    final later = provider.scan('unknown');
    service.scans.last.completeError(const AppError('productNotFound'));
    expect(await later, isNull);
    expect(provider.error, 'productNotFound');
    service.scans.first.complete(sample(1));
    expect(await earlier, isA<CashierProduct>());
    expect(provider.clearAfter(version), isFalse);
    expect(provider.error, 'productNotFound');
    provider.dispose();
  });
  test(
    'out-of-order suggestions cannot replace newest query; clear invalidates pending work',
    () async {
      final service = DeferredSearch();
      final provider = ProductSearchProvider(service, delay: Duration.zero);
      provider.change('old');
      await Future<void>.delayed(Duration.zero);
      provider.change('new');
      await Future<void>.delayed(Duration.zero);
      service.suggestions['new']!.complete([sample(2)]);
      await Future<void>.delayed(Duration.zero);
      service.suggestions['old']!.complete([sample(1)]);
      await Future<void>.delayed(Duration.zero);
      expect(provider.results.single.id, sample(2).id);
      provider.change('pending');
      await Future<void>.delayed(Duration.zero);
      provider.change('');
      service.suggestions['pending']!.complete([sample(1)]);
      await Future<void>.delayed(Duration.zero);
      expect(provider.results, isEmpty);
      provider.dispose();
    },
  );
  test(
    'overlapping scanner Enter intents all return; latest-query guards do not discard scans',
    () async {
      final service = DeferredSearch();
      final provider = ProductSearchProvider(service);
      final requests = [
        provider.scan('0001'),
        provider.scan('0001'),
        provider.scan('0001'),
      ];
      for (final scan in service.scans.reversed) {
        scan.complete(sample(1));
      }
      expect(
        (await Future.wait(requests)).whereType<CashierProduct>().length,
        3,
      );
      provider.dispose();
    },
  );
  test(
    'dispose discards pending suggestion/scan notifications safely',
    () async {
      final service = DeferredSearch();
      final provider = ProductSearchProvider(service, delay: Duration.zero);
      provider.change('pending');
      await Future<void>.delayed(Duration.zero);
      final scan = provider.scan('0001');
      provider.dispose();
      service.suggestions['pending']!.complete([sample(1)]);
      service.scans.single.complete(sample(1));
      expect(await scan, isNull);
      await Future<void>.delayed(Duration.zero);
    },
  );
}
