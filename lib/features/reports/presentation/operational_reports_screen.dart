import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/domain/management_role.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../cash_drawer/presentation/cash_drawer_history_screen.dart';
import '../../cash_drawer/presentation/cash_drawer_policy_screen.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/operational_report.dart';
import 'financial_filters.dart';
import 'operational_report_labels.dart';
import 'report_export_screen.dart';
import 'report_master_picker.dart';

/// Route-owned filters and a single bounded page. SQL and export lifetimes are
/// service-owned; stale async completions cannot repopulate a locked screen.
class OperationalReportsScreen extends StatefulWidget {
  const OperationalReportsScreen({super.key});
  @override
  State<OperationalReportsScreen> createState() => _OperationalReportsState();
}

class _OperationalReportsState extends State<OperationalReportsScreen>
    with RouteAware {
  final search = TextEditingController();
  OperationalSection section = OperationalSection.potential;
  PotentialGrouping grouping = PotentialGrouping.product;
  InvoiceBalanceFilter balance = InvoiceBalanceFilter.all;
  CalendarDate? from, through;
  MasterRecord? supplier, category;
  OperationalSnapshot? snapshot;
  OperationalScope? loadedScope;
  StreamSubscription<int>? commits, grants;
  bool busy = true;
  String? error;
  int epoch = 0;
  RouteObserver<ModalRoute<dynamic>>? observer;
  ModalRoute<dynamic>? route;
  OperationalScope get scope => OperationalScope(
    section: section,
    grouping: grouping,
    balance: balance,
    search: search.text,
    supplierId: section == OperationalSection.variance ? null : supplier?.id,
    categoryId: section == OperationalSection.potential ? category?.id : null,
    from: from,
    through: through,
  );
  @override
  void initState() {
    super.initState();
    final app = context.read<AppServices>();
    // PIN verification itself commits while still locked. A background refresh
    // must not call requireAccess then revoke the authentication in flight.
    commits = app.database.commits.listen((_) {
      if ((route?.isCurrent ?? false) &&
          app.management.isUnlocked &&
          app.management.role == ManagementRole.owner) {
        unawaited(load());
      }
    });
    grants = app.management.sessionChanges.listen((_) {
      epoch++;
      if (mounted) {
        setState(() {
          snapshot = null;
          error = null;
        });
      }
      if ((route?.isCurrent ?? false) &&
          app.management.isUnlocked &&
          app.management.role == ManagementRole.owner) {
        unawaited(load());
      }
    });
    unawaited(load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context);
    if (current != route) {
      observer?.unsubscribe(this);
      route = current;
      observer = context.read<RouteObserver<ModalRoute<dynamic>>>();
      if (current != null) observer!.subscribe(this, current);
    }
  }

  @override
  void didPushNext() {
    epoch++;
  }

  @override
  void didPopNext() {
    final access = context.read<AppServices>().management;
    if (mounted && access.isUnlocked && access.role == ManagementRole.owner) {
      unawaited(load());
    }
  }

  Future<void> load({bool next = false}) async {
    final run = ++epoch, cursor = next ? snapshot?.next : null;
    final selected = scope;
    setState(() {
      busy = true;
      error = null;
      snapshot = null;
    });
    try {
      final result = await context.read<AppServices>().operationalReports.load(
        selected,
        after: cursor,
        cancelled: () => !mounted || run != epoch,
      );
      if (mounted && run == epoch) {
        setState(() {
          snapshot = result;
          loadedScope = selected;
        });
      }
    } on Object catch (e) {
      if (mounted && run == epoch) {
        setState(() {
          snapshot = null;
          error = safeError(e);
        });
      }
    } finally {
      if (mounted && run == epoch) setState(() => busy = false);
    }
  }

  Future<T?> choose<T>(List<T> values, String Function(T) key) =>
      showModalBottomSheet<T>(
        context: context,
        useSafeArea: true,
        builder: (sheet) => ListView(
          shrinkWrap: true,
          children: [
            for (final value in values)
              ListTile(
                title: Text(tr(sheet, key(value))),
                onTap: () => Navigator.pop(sheet, value),
              ),
          ],
        ),
      );

  @override
  void dispose() {
    epoch++;
    observer?.unsubscribe(this);
    unawaited(commits?.cancel() ?? Future<void>.value());
    unawaited(grants?.cancel() ?? Future<void>.value());
    search.dispose();
    super.dispose();
  }

  Widget amounts(Map<String, BigInt> values, String code) {
    final codec = moneyCodec(context, currency: CurrencyPolicy.forCode(code));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in values.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${tr(context, operationalReportKey('m53OpField', entry.key))}: ${entry.key.endsWith('_micros')
                  ? codec.formatSignedCost(entry.value)
                  : entry.key.endsWith('_minor')
                  ? codec.formatSignedMinor(entry.value)
                  : entry.value}',
            ),
          ),
      ],
    );
  }

  String detailValue(String key, Object? value, OperationalRow row) {
    if (value == null) return '';
    if ([
      'stock_tracking',
      'status',
      'source',
      'kind',
      'date_basis',
    ].contains(key)) {
      return tr(context, operationalReportKey('m53OpValue', value.toString()));
    }
    if (key == 'retail_price_minor') {
      return moneyCodec(
        context,
        currency: CurrencyPolicy.forCode(row.currency),
      ).formatSignedMinor(BigInt.parse(value.toString()));
    }
    if (['posted_at', 'baseline_at', 'recorded_at'].contains(key)) {
      final zone = row.details['snapshot_zone'] as String? ?? snapshot!.zone;
      return '${context.read<AppServices>().management.clock.displayTime(int.parse(value.toString()), zone)} · $zone';
    }
    return value.toString();
  }

  String rowName(OperationalRow row) {
    final name = row.details['name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    return tr(context, switch (row.details['grouping']) {
      'store' => 'm53OpGroupStore',
      'category' => 'm53OpNoCategory',
      'supplier' => 'm53OpNoSupplier',
      _ => 'm53OpUnassigned',
    });
  }

  Widget masterFilter(MasterKind kind, MasterRecord? selected) {
    final all = kind == MasterKind.category
        ? 'm53OpAllCategories'
        : 'm53OpAllSuppliers';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, kind == MasterKind.category ? 'categories' : 'suppliers'),
        ),
        OutlinedButton(
          key: ValueKey('operational-${kind.name}'),
          onPressed: busy
              ? null
              : () async {
                  final result = await Navigator.of(context).push<MasterRecord>(
                    MaterialPageRoute(
                      builder: (_) => ReportMasterPicker(kind: kind),
                    ),
                  );
                  if (result != null && mounted) {
                    setState(() {
                      if (kind == MasterKind.category) {
                        category = result;
                      } else {
                        supplier = result;
                      }
                    });
                    await load();
                  }
                },
          child: Text(
            selected == null
                ? tr(context, all)
                : '${selected.name} · ${selected.id.value.substring(0, 8)}',
          ),
        ),
        if (selected != null)
          TextButton(
            key: ValueKey('operational-${kind.name}-clear'),
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      if (kind == MasterKind.category) {
                        category = null;
                      } else {
                        supplier = null;
                      }
                    });
                    await load();
                  },
            child: Text(tr(context, all)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    final selected = scope;
    return ManagementGate(
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'm53OperationalReports')),
          actions: const [LanguageButton()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              OutlinedButton(
                key: const ValueKey('operational-section'),
                onPressed: busy
                    ? null
                    : () async {
                        final value = await choose(
                          OperationalSection.values,
                          (v) => operationalReportKey('m53OpSection', v.name),
                        );
                        if (value != null && mounted) {
                          setState(() {
                            section = value;
                            grouping = PotentialGrouping.product;
                            balance = InvoiceBalanceFilter.all;
                            from = through = null;
                          });
                          await load();
                        }
                      },
                child: Text(
                  tr(
                    context,
                    operationalReportKey('m53OpSection', section.name),
                  ),
                ),
              ),
              Text(
                tr(context, operationalReportKey('m53OpBasis', section.name)),
              ),
              ExpansionTile(
                title: Text(tr(context, 'm53OpAssumptions')),
                childrenPadding: const EdgeInsets.all(12),
                children: [
                  Text(
                    tr(
                      context,
                      operationalReportKey('m53OpHelp', section.name),
                    ),
                  ),
                ],
              ),
              if (section == OperationalSection.potential ||
                  section == OperationalSection.supplierInvoices)
                OutlinedButton(
                  key: const ValueKey('operational-group'),
                  onPressed: busy
                      ? null
                      : () async {
                          final value = await choose(
                            section == OperationalSection.potential
                                ? PotentialGrouping.values
                                : [
                                    PotentialGrouping.product,
                                    PotentialGrouping.supplier,
                                  ],
                            (v) =>
                                v == PotentialGrouping.product &&
                                    section ==
                                        OperationalSection.supplierInvoices
                                ? 'm53OpInvoiceLevel'
                                : operationalReportKey('m53OpGroup', v.name),
                          );
                          if (value != null && mounted) {
                            setState(() => grouping = value);
                            await load();
                          }
                        },
                  child: Text(
                    tr(
                      context,
                      grouping == PotentialGrouping.product &&
                              section == OperationalSection.supplierInvoices
                          ? 'm53OpInvoiceLevel'
                          : operationalReportKey('m53OpGroup', grouping.name),
                    ),
                  ),
                ),
              if (section == OperationalSection.supplierInvoices)
                OutlinedButton(
                  key: const ValueKey('operational-balance'),
                  onPressed: busy
                      ? null
                      : () async {
                          final value = await choose(
                            InvoiceBalanceFilter.values,
                            (v) => operationalReportKey('m53OpBalance', v.name),
                          );
                          if (value != null && mounted) {
                            setState(() => balance = value);
                            await load();
                          }
                        },
                  child: Text(
                    tr(
                      context,
                      operationalReportKey('m53OpBalance', balance.name),
                    ),
                  ),
                ),
              if (section != OperationalSection.variance)
                masterFilter(MasterKind.supplier, supplier),
              if (section == OperationalSection.potential)
                masterFilter(MasterKind.category, category),
              TextField(
                controller: search,
                enabled: !busy,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: tr(context, 'm53OpSearch'),
                ),
                onSubmitted: (_) => load(),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => load(),
                child: Text(tr(context, 'm53OpApply')),
              ),
              if (selected.usesPeriod) ...[
                Text(
                  from == null
                      ? tr(context, 'm53OpAllDates')
                      : '${from!.iso} – ${through!.iso}',
                ),
                OutlinedButton(
                  onPressed: busy || data == null
                      ? null
                      : () async {
                          final app = context.read<AppServices>();
                          final start = app.management.clock.dayStart(
                                from ??
                                    CalendarDate(
                                      '${data.day.substring(0, 8)}01',
                                    ),
                                data.zone,
                              ),
                              end = app.management.clock.dayStart(
                                through ?? CalendarDate(data.day),
                                data.zone,
                                nextDay: true,
                              );
                          final dates = await chooseFinancialDates(
                            context,
                            zone: data.zone,
                            start: start,
                            end: end,
                          );
                          if (dates != null && mounted) {
                            setState(() {
                              from = dates.$1;
                              through = dates.$2;
                            });
                            await load();
                          }
                        },
                  child: Text(tr(context, 'm4SelectPeriod')),
                ),
                if (from != null)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() => from = through = null);
                            await load();
                          },
                    child: Text(tr(context, 'm53OpAllDates')),
                  ),
              ],
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(
                  tr(context, error!),
                  key: const ValueKey('operational-error'),
                ),
              if (data != null) ...[
                if (loadedScope!.search.trim().isNotEmpty)
                  Text(
                    '${tr(context, 'm53OpAppliedSearch')}: ${loadedScope!.search.trim()}',
                  ),
                Text(
                  '${tr(context, 'm53OpCaptured')}: ${context.read<AppServices>().management.clock.displayTime(data.capturedAt, data.zone)} · ${data.zone}',
                ),
                OutlinedButton.icon(
                  key: const ValueKey('operational-export'),
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ReportExportScreen(operational: loadedScope!),
                          ),
                        ),
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(tr(context, 'm51Export')),
                ),
                Text(
                  tr(context, 'm53OpWholeScope'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final currency in data.totals.entries) ...[
                  Text(currency.key.split(':').first),
                  amounts(currency.value, currency.key.split(':').first),
                ],
                if (data.rows.isEmpty)
                  Text(
                    tr(
                      context,
                      section == OperationalSection.variance
                          ? 'm53OpNoComparison'
                          : 'm53OpEmpty',
                    ),
                  ),
                for (final row in data.rows)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rowName(row),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SelectableText(
                            section == OperationalSection.supplierPayments ||
                                    section ==
                                        OperationalSection.supplierRefunds
                                ? row.id
                                : row.group,
                          ),
                          for (final detail in row.details.entries)
                            if (detail.value != null &&
                                detail.key != 'group_name' &&
                                detail.key != 'name' &&
                                detail.key != 'grouping' &&
                                detail.key != 'baseline_epoch')
                              Text(
                                '${tr(context, operationalReportKey('m53OpDetail', detail.key))}: ${detailValue(detail.key, detail.value, row)}',
                              ),
                          amounts(row.amounts, row.currency),
                        ],
                      ),
                    ),
                  ),
                if (data.next != null)
                  FilledButton(
                    onPressed: busy ? null : () => load(next: true),
                    child: Text(tr(context, 'm53OpNextPage')),
                  ),
                TextButton(
                  onPressed: busy ? null : () => load(),
                  child: Text(tr(context, 'm53OpFirstPage')),
                ),
              ],
              const Divider(),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CashDrawerHistoryScreen(owner: true),
                  ),
                ),
                child: Text(tr(context, 'm53OpCashAudit')),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CashDrawerPolicyScreen(),
                  ),
                ),
                child: Text(tr(context, 'm53OpCashPolicy')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
