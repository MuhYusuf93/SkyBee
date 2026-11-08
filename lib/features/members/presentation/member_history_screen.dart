import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import '../../reports/presentation/financial_filters.dart';
import '../../sale_history/presentation/sale_detail_screen.dart';
import '../../settings/presentation/language_button.dart';
import '../application/member_service.dart';
import '../domain/member_history.dart';

class MemberHistoryScreen extends StatelessWidget {
  const MemberHistoryScreen({super.key, required this.memberId});

  final EntityId memberId;

  @override
  Widget build(BuildContext context) =>
      ManagementGate(child: _HistoryBody(memberId: memberId));
}

class _HistoryBody extends StatefulWidget {
  const _HistoryBody({required this.memberId});

  final EntityId memberId;

  @override
  State<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<_HistoryBody> {
  MemberHistoryPage? _page;
  CalendarDate? _from, _through;
  MemberHistoryCursor? _after;
  final _previous = <MemberHistoryCursor?>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _after = null;
      _previous.clear();
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<AppServices>().members.ownerHistory(
        widget.memberId,
        from: _from,
        through: _through,
        after: _after,
      );
      if (mounted) {
        setState(() {
          _page = page;
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (!mounted) return;
      if (_after != null &&
          error is AppError &&
          error.message == 'm3DraftChanged') {
        await _load(reset: true);
        return;
      }
      setState(() {
        _loading = false;
        _error = safeError(error);
      });
    }
  }

  Future<void> _chooseDates(MemberHistoryPage page) async {
    final dates = await chooseFinancialDates(
      context,
      zone: page.zone,
      start: UtcInstant.fromMilliseconds(page.start),
      end: UtcInstant.fromMilliseconds(page.end),
    );
    if (mounted && dates != null) {
      _from = dates.$1;
      _through = dates.$2;
      await _load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final clock = context.read<AppServices>().management.clock;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'm54MemberHistory')),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_loading)
                      LinearProgressIndicator(
                        semanticsLabel: tr(context, 'loading'),
                      ),
                    if (_error != null) ...[
                      Text(tr(context, _error!)),
                      TextButton(
                        onPressed: () => _load(reset: true),
                        child: Text(tr(context, 'tryAgain')),
                      ),
                    ],
                    if (page != null) ...[
                      Text(
                        page.member.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(page.member.phone ?? tr(context, 'm3NoPhone')),
                      if (page.member.address.isNotEmpty)
                        Text(page.member.address),
                      if (_from != null)
                        Text('${_from!.iso} – ${_through!.iso}'),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _loading
                                ? null
                                : () => _chooseDates(page),
                            child: Text(tr(context, 'm4SelectPeriod')),
                          ),
                          OutlinedButton(
                            onPressed: _loading || _from == null
                                ? null
                                : () {
                                    _from = _through = null;
                                    _load(reset: true);
                                  },
                            child: Text(tr(context, 'm4AllTime')),
                          ),
                        ],
                      ),
                      if (_error == null) ...[
                        Text(
                          '${tr(context, 'm54MemberNetPurchases')} ${moneyLabel(context, page.purchases, currency: page.currency)}',
                        ),
                        Text(
                          '${tr(context, 'm53MemberVisits')} ${page.purchaseCount}',
                        ),
                        Text(
                          '${tr(context, 'm54MemberCurrentDebt')} ${moneyLabel(context, page.outstanding, currency: page.currency)}',
                        ),
                        if (page.events.items.isEmpty && !_loading)
                          Text(tr(context, 'noHistoryYet')),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            if (page != null && _error == null)
              SliverList.builder(
                itemCount: page.events.items.length,
                itemBuilder: (context, index) {
                  final event = page.events.items[index];
                  return ListTile(
                    key: ValueKey(
                      'member-event-${event.kind.name}-${event.id.value}',
                    ),
                    title: Text(
                      tr(context, switch (event.kind) {
                        MemberHistoryKind.sale => 'm54MemberSale',
                        MemberHistoryKind.saleReversal =>
                          'm54MemberSaleReversal',
                        MemberHistoryKind.saleReturn => 'm54MemberSaleReturn',
                        MemberHistoryKind.repayment => 'm54MemberRepayment',
                        MemberHistoryKind.repaymentReversal =>
                          'm54MemberRepaymentReversal',
                        MemberHistoryKind.refund => 'm54MemberRefund',
                      }),
                    ),
                    subtitle: Text(
                      '${clock.displayTime(event.createdAt, page.zone)}\n'
                      '${moneyLabel(context, event.amountMinor, currency: page.currency)}'
                      '${event.reversed ? ' · ${tr(context, 'm4Cancelled')}' : ''}',
                    ),
                    onTap: event.saleId == null || _loading
                        ? null
                        : () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SaleDetailScreen(id: event.saleId!),
                              ),
                            );
                            if (mounted) await _load(reset: true);
                          },
                  );
                },
              ),
            if (page != null && _error == null)
              SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: tr(context, 'm53SetupBack'),
                      onPressed: _loading || _previous.isEmpty
                          ? null
                          : () {
                              _after = _previous.removeLast();
                              _load();
                            },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: tr(context, 'm4ReloadStart'),
                      onPressed: _loading ? null : () => _load(reset: true),
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: tr(context, 'loadMore'),
                      onPressed: _loading || !page.events.hasMore
                          ? null
                          : () {
                              _previous.add(_after);
                              _after = page.events.nextCursor;
                              _load();
                            },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
