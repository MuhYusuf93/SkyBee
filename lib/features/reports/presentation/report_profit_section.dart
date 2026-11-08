import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/money/money_field.dart';
import '../../../l10n/localization.dart';
import '../domain/report_profit.dart';
import 'reports_provider.dart';

String profitPeriodLabel(ReportProfitPeriod period) => switch (period) {
  ReportProfitPeriod.day => 'm54ProfitDaily',
  ReportProfitPeriod.week => 'm54ProfitWeekly',
  ReportProfitPeriod.month => 'm54ProfitMonthly',
};

class ReportProfitSection extends StatelessWidget {
  const ReportProfitSection(this.state, {super.key});
  final ReportsProvider state;

  @override
  Widget build(BuildContext context) {
    final page = state.profitPage;
    final theme = Theme.of(context);
    String t(String key) => tr(context, key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('m54ProfitTrend'), style: theme.textTheme.titleLarge),
        Wrap(
          spacing: 8,
          children: [
            for (final period in ReportProfitPeriod.values)
              ChoiceChip(
                label: Text(t(profitPeriodLabel(period))),
                selected: state.profitPeriod == period,
                onSelected: (selected) {
                  if (selected) state.loadProfit(period);
                },
              ),
          ],
        ),
        if (state.profitLoading) const LinearProgressIndicator(),
        if (state.profitError case final error?) Text(t(error)),
        if (page != null) ...[
          Text('${page.zone} · ${t('m54ProfitCalendarPolicy')}'),
          ExcludeSemantics(
            child: SizedBox(
              width: double.infinity,
              height: 112,
              child: CustomPaint(
                painter: _ProfitBars(page.buckets, theme.colorScheme),
              ),
            ),
          ),
          Text(t('m54ProfitChartLegend')),
          _ProfitTable(page),
          if (page.pages > 1)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                IconButton(
                  tooltip: t('m54ProfitPrevious'),
                  onPressed: page.index == 0
                      ? null
                      : () => state.loadProfit(
                          state.profitPeriod,
                          page: page.index - 1,
                        ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${page.index + 1} / ${page.pages}'),
                IconButton(
                  tooltip: t('m54ProfitNext'),
                  onPressed: page.index == page.pages - 1
                      ? null
                      : () => state.loadProfit(
                          state.profitPeriod,
                          page: page.index + 1,
                        ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class _ProfitTable extends StatelessWidget {
  const _ProfitTable(this.page);
  final ReportProfitPage page;

  @override
  Widget build(BuildContext context) {
    final codec = moneyCodec(context, currency: page.currency);
    String cost(BigInt? value) => value == null
        ? tr(context, 'm53CostIncomplete')
        : codec.formatSignedCost(value);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          for (final key in [
            'm4SelectPeriod',
            'm4NetSales',
            'm3CostSnapshot',
            'm4GrossProfit',
            'm54ProfitWriteDown',
          ])
            DataColumn(label: Text(tr(context, key))),
        ],
        rows: [
          for (final bucket in page.buckets)
            DataRow(
              cells: [
                DataCell(
                  Text(
                    bucket.range.first == bucket.range.last
                        ? bucket.range.first.iso
                        : '${bucket.range.first.iso} – ${bucket.range.last.iso}',
                  ),
                ),
                DataCell(
                  Text(codec.formatSignedMinor(BigInt.from(bucket.salesMinor))),
                ),
                DataCell(
                  Text(
                    cost(
                      bucket.costMicros == null
                          ? null
                          : BigInt.from(bucket.costMicros!),
                    ),
                  ),
                ),
                DataCell(Text(cost(bucket.grossProfitMicros))),
                DataCell(
                  Text(
                    cost(
                      bucket.writeDownMicros == null
                          ? null
                          : BigInt.from(bucket.writeDownMicros!),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ProfitBars extends CustomPainter {
  const _ProfitBars(this.buckets, this.colors);
  final List<ReportProfitBucket> buckets;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final values = buckets
        .map((bucket) => bucket.grossProfitMicros?.toDouble())
        .toList();
    var high = 0.0, low = 0.0;
    for (final value in values.nonNulls) {
      high = math.max(high, value);
      low = math.min(low, value);
    }
    final span = high - low;
    final zero = span == 0
        ? size.height / 2
        : 4 + high / span * (size.height - 8);
    final paint = Paint()..color = colors.outline;
    canvas.drawLine(Offset(0, zero), Offset(size.width, zero), paint);
    final width = size.width / values.length;
    for (var index = 0; index < values.length; index++) {
      final x = (index + .5) * width;
      final value = values[index];
      if (value == null) {
        final arm = math.min(3.0, width / 4);
        paint.color = colors.outline;
        canvas.drawLine(
          Offset(x - arm, zero - arm),
          Offset(x + arm, zero + arm),
          paint,
        );
        canvas.drawLine(
          Offset(x - arm, zero + arm),
          Offset(x + arm, zero - arm),
          paint,
        );
      } else {
        final y = span == 0 ? zero : zero - value / span * (size.height - 8);
        paint.color = value < 0 ? colors.error : colors.primary;
        canvas.drawRect(
          Rect.fromLTRB(
            x - width * .34,
            math.min(y, zero) - (value == 0 ? 1 : 0),
            x + width * .34,
            math.max(y, zero),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ProfitBars oldDelegate) =>
      !identical(oldDelegate.buckets, buckets) || oldDelegate.colors != colors;
}
