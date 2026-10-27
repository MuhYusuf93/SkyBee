import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../l10n/localization.dart';
import '../../cashier/domain/tender_draft.dart';
import '../../management/presentation/management_gate.dart';
import 'cash_drawer_history_screen.dart';

class CashSaleAuditScreen extends StatefulWidget {
  const CashSaleAuditScreen({super.key, required this.id});
  final EntityId id;
  @override
  State<CashSaleAuditScreen> createState() => _CashSaleAuditScreenState();
}

class _CashSaleAuditScreenState extends State<CashSaleAuditScreen> {
  Map<String, Object?>? value;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await context.read<AppServices>().cashDrawerHistory.sale(
        widget.id,
      );
      if (mounted) setState(() => value = result);
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = value,
        currency = row == null
            ? null
            : CurrencyPolicy.forCode(row['currency_code'] as String);
    final snapshot = row?['details_json'] == null
        ? null
        : TenderSnapshot.decode(currency!, row!['details_json'] as String);
    return ManagementGate(
      child: Scaffold(
        appBar: AppBar(title: Text(tr(context, 'm53CashSaleAudit'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error != null) Text(tr(context, error!)),
            Text(tr(context, 'm53CashDeclarationHelp')),
            if (row == null && !busy)
              Text(tr(context, 'm53CashDetailsUnknown')),
            if (row != null) ...[
              for (final e in const {
                'received_minor': 'm51Tender',
                'applied_minor': 'm53CashApplied',
                'change_minor': 'm53CashChangeCounts',
              }.entries)
                Text(
                  '${tr(context, e.value)}: ${moneyLabel(context, row[e.key] as int, currency: currency)}',
                ),
              if (snapshot != null) ...[
                for (final e in snapshot.counts.entries)
                  Text(
                    '${moneyLabel(context, e.key, currency: currency)} ×${e.value}',
                  ),
                if (snapshot.unclassifiedMinor > 0)
                  Text(
                    '${tr(context, 'm53CashUnclassified')}: ${moneyLabel(context, snapshot.unclassifiedMinor, currency: currency)}',
                  ),
              ] else
                Text(tr(context, 'm53CashDetailsUnknown')),
              Text(tr(context, 'm53CashChangeCounts')),
              CashPiecesSummary(
                json: row['change_counts_json'] as String?,
                currency: currency!,
              ),
              if (row['session_id'] case final String session)
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => CashDrawerDetailScreen(
                        id: EntityId(session),
                        owner: true,
                      ),
                    ),
                  ),
                  child: Text(tr(context, 'm53CashHistory')),
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
