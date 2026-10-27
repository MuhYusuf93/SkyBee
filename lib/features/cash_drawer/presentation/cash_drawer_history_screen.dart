import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/fresh_authentication.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../management/presentation/management_gate.dart';
import '../domain/cash_drawer_history.dart';
import '../domain/cash_drawer_models.dart';
import '../domain/cash_pieces.dart';

Widget _scope(bool owner, Widget child) =>
    owner ? ManagementGate(child: child) : child;

/// Rendering one cash vector stays bounded by the denomination catalogue.
class CashPiecesSummary extends StatelessWidget {
  const CashPiecesSummary({
    super.key,
    required this.json,
    required this.currency,
  });
  final String? json;
  final CurrencyPolicy currency;
  @override
  Widget build(BuildContext context) {
    if (json == null) return Text(tr(context, 'm53CashDetailsUnknown'));
    final pieces = CashPieces.decode(currency, json!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(moneyLabel(context, pieces.total.amountMinor, currency: currency)),
        for (final e in pieces.counts.entries)
          Text('${moneyLabel(context, e.key, currency: currency)} ×${e.value}'),
      ],
    );
  }
}

class CashDrawerHistoryScreen extends StatefulWidget {
  const CashDrawerHistoryScreen({super.key, this.owner = false});
  final bool owner;
  @override
  State<CashDrawerHistoryScreen> createState() =>
      _CashDrawerHistoryScreenState();
}

class _CashDrawerHistoryScreenState extends State<CashDrawerHistoryScreen> {
  List<CashDrawerSession> items = [];
  CashSessionCursor? cursor;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final page = await context.read<AppServices>().cashDrawerHistory.sessions(
        owner: widget.owner,
        after: more ? cursor : null,
      );
      if (!mounted) return;
      setState(() {
        final all = [...(more ? items : <CashDrawerSession>[]), ...page.items];
        items = all.skip((all.length - 75).clamp(0, all.length)).toList();
        cursor = page.next;
      });
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _scope(
    widget.owner,
    Scaffold(
      appBar: AppBar(title: Text(tr(context, 'm53CashHistory'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (busy) const LinearProgressIndicator(),
          if (!widget.owner) Text(tr(context, 'm53CashPublicHistoryHelp')),
          if (error != null) Text(tr(context, error!)),
          for (final item in items)
            ListTile(
              title: Text(
                '${item.day} · #${item.row['session_number']} · ${item.currency.code}',
              ),
              subtitle: Text(
                tr(
                  context,
                  item.closed
                      ? 'm53CashSessionClosed'
                      : item.balance.known
                      ? 'm53CashExpected'
                      : 'm53CashLowerBound',
                ),
              ),
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CashDrawerDetailScreen(
                      id: item.id,
                      owner: widget.owner,
                    ),
                  ),
                );
                if (mounted) await load();
              },
            ),
          if (cursor != null)
            OutlinedButton(
              onPressed: busy ? null : () => load(more: true),
              child: Text(tr(context, 'm3LoadMore')),
            ),
          TextButton(
            onPressed: busy ? null : load,
            child: Text(tr(context, 'tryAgain')),
          ),
        ],
      ),
    ),
  );
}

class CashDrawerDetailScreen extends StatefulWidget {
  const CashDrawerDetailScreen({
    super.key,
    required this.id,
    this.owner = false,
  });
  final EntityId id;
  final bool owner;
  @override
  State<CashDrawerDetailScreen> createState() => _CashDrawerDetailScreenState();
}

class _CashDrawerDetailScreenState extends State<CashDrawerDetailScreen> {
  CashSessionDetail? detail;
  List<Map<String, Object?>> events = [];
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await context.read<AppServices>().cashDrawerHistory.detail(
        widget.id,
        owner: widget.owner,
        after: more ? detail?.next : null,
      );
      if (!mounted) return;
      setState(() {
        final all = [
          ...(more ? events : <Map<String, Object?>>[]),
          ...value.events,
        ];
        events = all.skip((all.length - 75).clamp(0, all.length)).toList();
        detail = value;
      });
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = detail, currency = value?.session.currency;
    Widget pieces(String? json) =>
        CashPiecesSummary(json: json, currency: currency!);
    return _scope(
      widget.owner,
      Scaffold(
        appBar: AppBar(title: Text(tr(context, 'm53CashHistory'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error != null) Text(tr(context, error!)),
            if (value != null) ...[
              Text(
                '${value.session.day} · ${value.session.timeZone} · #${value.session.row['session_number']}',
              ),
              Text(tr(context, 'm53CashDeclarationHelp')),
              Text(tr(context, 'm53CashOpeningCounts')),
              pieces(value.session.row['opening_counts_json'] as String?),
              Text(value.session.row['reason'] as String),
              Text(
                tr(
                  context,
                  value.session.balance.known
                      ? 'm53CashExpected'
                      : 'm53CashLowerBound',
                ),
              ),
              pieces(value.session.balance.pieces.encode()),
              if (value.closure case final closure?) ...[
                Text(tr(context, 'm53CashClosingCounts')),
                pieces(closure['observed_counts_json'] as String?),
                Text(tr(context, 'm53CashDifference')),
                Text(
                  closure['difference_minor'] == null
                      ? tr(context, 'm53CashDetailsUnknown')
                      : moneyCodec(
                          context,
                          currency: currency,
                        ).formatSignedMinor(
                          BigInt.from(closure['difference_minor'] as int),
                        ),
                ),
                Text(closure['reason'] as String),
                Text(
                  context.read<AppServices>().management.clock.displayTime(
                    closure['created_at'] as int,
                    value.session.timeZone,
                  ),
                ),
                Text(tr(context, 'm53CashDifferenceHelp')),
              ],
              if (widget.owner && !value.session.closed)
                OutlinedButton(
                  key: const ValueKey('drawer-owner-close'),
                  onPressed: busy
                      ? null
                      : () async {
                          await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => _OwnerCloseScreen(value.session),
                            ),
                          );
                          if (mounted) await load();
                        },
                  child: Text(tr(context, 'm53CashOwnerException')),
                ),
              for (final event in events)
                ExpansionTile(
                  title: Text(
                    '#${event['sequence']} · ${tr(context, _sourceKey(event['source_kind'] as String))}',
                  ),
                  subtitle: Text(
                    context.read<AppServices>().management.clock.displayTime(
                      event['created_at'] as int,
                      value.session.timeZone,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.all(12),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tr(context, 'm53CashReference')}: ${event['source_id']}',
                    ),
                    Text(tr(context, 'm53CashCashIn')),
                    pieces(event['in_counts_json'] as String),
                    Text(tr(context, 'm53CashCashOut')),
                    pieces(event['out_counts_json'] as String),
                    if (event['observed_counts_json'] != null) ...[
                      Text(tr(context, 'm53CashExpected')),
                      pieces(event['before_counts_json'] as String?),
                      Text(tr(context, 'm53CashObservedCounts')),
                      pieces(event['observed_counts_json'] as String),
                      Text(
                        '${tr(context, 'm53CashDifference')}: ${event['difference_minor'] == null ? tr(context, 'm53CashDetailsUnknown') : moneyCodec(context, currency: currency).formatSignedMinor(BigInt.from(event['difference_minor'] as int))}',
                      ),
                    ],
                    Text(event['reason'] as String),
                  ],
                ),
              if (value.next != null)
                OutlinedButton(
                  onPressed: busy ? null : () => load(more: true),
                  child: Text(tr(context, 'm3LoadMore')),
                ),
            ],
            TextButton(
              onPressed: busy ? null : load,
              child: Text(tr(context, 'tryAgain')),
            ),
          ],
        ),
      ),
    );
  }
}

String _sourceKey(String source) => switch (source) {
  'checkout' => 'm3ReceiptNumber',
  'receivable' => 'm3RepaymentAmount',
  'refund' => 'm53CashRefundPieces',
  'journal_in' => 'm53CashCashIn',
  'journal_out' => 'm53CashCashOut',
  'handover' => 'm53CashHandover',
  'reconcile' => 'm53CashRecount',
  _ => 'm53CashReference',
};

class _OwnerCloseScreen extends StatefulWidget {
  const _OwnerCloseScreen(this.session);
  final CashDrawerSession session;
  @override
  State<_OwnerCloseScreen> createState() => _OwnerCloseScreenState();
}

class _OwnerCloseScreenState extends State<_OwnerCloseScreen> {
  final reason = TextEditingController(),
      key = const IdGenerator().next().value;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final service = context.read<AppServices>().cashDrawer;
      if (!await freshAuthentication(context, 'security', pinOnly: true) ||
          !mounted) {
        return;
      }
      await service.close(
        session: widget.session.id,
        revision: widget.session.balance.revision,
        operationKey: key,
        observed: null,
        reason: reason.text,
        ownerException: true,
      );
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: ListenableBuilder(
      listenable: reason,
      builder: (context, _) => FormExitGuard(
        dirty: reason.text.isNotEmpty,
        dirtyCheck: () => reason.text.isNotEmpty,
        busy: busy,
        child: Scaffold(
          appBar: AppBar(title: Text(tr(context, 'm53CashOwnerException'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(widget.session.day),
              Text(tr(context, 'm53CashOwnerExceptionHelp')),
              ManagedTextField(
                controller: reason,
                maxLength: 1000,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: tr(context, 'm53CashReason'),
                ),
              ),
              if (error != null) Text(tr(context, error!)),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(tr(context, 'save')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
