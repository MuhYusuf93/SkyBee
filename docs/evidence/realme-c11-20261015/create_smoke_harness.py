"""Create a Realme-only derivative of the proven isolated restart harness."""
from pathlib import Path

root = Path(__file__).resolve().parents[3]
source = (root / 'tools/dv8910_smoke.dart').read_text(encoding='utf-8')
source = source.replace('DV8910', 'Realme C11').replace('dv8910', 'realme')
source = source.replace('Realme C11_SMOKE', 'REALME_SMOKE').replace('Realme C11_UI_STATE', 'REALME_UI_STATE').replace('Realme C11_UI_STATE_ERROR', 'REALME_UI_STATE_ERROR').replace('Realme C11_FRAMES', 'REALME_FRAMES')
source = source.replace('realme_restart_20261014.db', 'realme_restart_20261015.db')
source = source.replace('DateTime.utc(2026, 10, 14, 3)', 'DateTime.utc(2026, 10, 15, 3)')
old = '''sellingPrice: Money(12000, 'IDR', 0),
          ),
          initialQuantity: 20,
          unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
        );'''
new = '''sellingPrice: Money(12000, 'IDR', 0),
            wholesalePrice: Money(10000, 'IDR', 0),
            packLabel: 'dus',
            packSize: 40,
          ),
          initialQuantity: 10,
          unitCost: CostAmount.fromMoney(Money(8000, 'IDR', 0)),
        );
        await s.inventory.receive(product, 10,
          CostAmount.fromMoney(Money(10000, 'IDR', 0)),
          operationKey: 'realme-smoke-restock');
        final weighted = await s.inventory.detail(product);
        verify(weighted.quantity == 20 && weighted.valueMicros == 180000000000,
          'actual moving average 10x8000 plus 10x10000');'''
assert source.count(old) == 1
source = source.replace(old, new)
old = '''        s.management.lock();
        publish({
          'stage': 'committed_recovered','''
new = '''        final searchSamples = <int>[], reportSamples = <int>[];
        for (var sample = 0; sample < 5; sample++) {
          final searchTimer = Stopwatch()..start();
          verify((await s.search.suggest('000123')).isNotEmpty, 'repeat search');
          searchSamples.add(searchTimer.elapsedMicroseconds);
          final reportTimer = Stopwatch()..start();
          final repeated = await s.reports.summary(await s.reports.period(
            CalendarDate('2026-10-01'), CalendarDate('2026-10-31')));
          verify(repeated.saleCount == 1 && repeated.salesMinor == 36000,
            'repeat summary stable');
          reportSamples.add(reportTimer.elapsedMicroseconds);
        }
        s.management.lock();
        publish({
          'search_5_samples_us': searchSamples,
          'report_5_samples_us': reportSamples,
          'sample_scope': 'service latency small fixture; no debounce/UI/large-dataset claim',
          'stage': 'committed_recovered','''
assert source.count(old) == 1
source = source.replace(old, new)
(root / 'tools/realme_smoke.dart').write_text(source, encoding='utf-8', newline='\n')
print('Created isolated Realme harness: actual weighted restock, process recovery, five latency samples, actual KasirApp.')
