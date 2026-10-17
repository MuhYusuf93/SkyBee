import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/pagination/paged_controller.dart';
import '../../../l10n/localization.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../management/presentation/protected_dialog.dart';
import '../../management/presentation/managed_text_field.dart';

/// The route owns the picked customer ID; identical names remain distinct.
/// Only a bounded keyset picker is opened, never an all-customers dropdown.
Future<(CustomerRecord?,)?> chooseFinancialCustomer(BuildContext context) =>
    showManagedDialog<(CustomerRecord?,)>(
      context: context,
      builder: (_) => const _CustomerPicker(),
    );

class _CustomerPicker extends StatefulWidget {
  const _CustomerPicker();
  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  late final PagedController<CustomerRecord, CustomerCursor, String> pager;
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    final service = context.read<AppServices>().receivables;
    pager =
        PagedController(
            filter: '',
            load: (q, c) =>
                service.customers(query: q, after: c, activeDebts: false),
          )
          ..addListener(changed)
          ..loadMore();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    debounce?.cancel();
    pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProtectedDialog(
    child: AlertDialog(
      title: Text(tr(context, 'm4CustomerFilter')),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          children: [
            ManagedTextField(
              decoration: InputDecoration(
                labelText: tr(context, 'm3CustomerName'),
              ),
              onChanged: (q) {
                debounce?.cancel();
                debounce = Timer(
                  const Duration(milliseconds: 200),
                  () => pager.reset(q),
                );
              },
            ),
            if (pager.isLoading) const LinearProgressIndicator(),
            if (pager.error != null) Text(tr(context, pager.error!)),
            Expanded(
              child: ListView(
                children: [
                  for (final c in pager.items)
                    ListTile(
                      title: Text(c.name),
                      subtitle: Text(
                        '${c.phone ?? tr(context, 'm3NoPhone')} · ${c.id.value.substring(0, 8)}',
                      ),
                      onTap: () => Navigator.pop(context, (c,)),
                    ),
                  if (pager.hasMore)
                    TextButton(
                      onPressed: pager.isLoading ? null : pager.loadMore,
                      child: Text(tr(context, 'm3LoadMore')),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, (null,)),
          child: Text(tr(context, 'm4AllCustomers')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'cancel')),
        ),
      ],
    ),
  );
}

Future<(CalendarDate, CalendarDate)?> chooseFinancialDates(
  BuildContext context, {
  required String zone,
  required UtcInstant start,
  required UtcInstant end,
}) async {
  final clock = context.read<AppServices>().management.clock;
  final from = DateTime.parse(clock.dateAt(start.milliseconds, zone).iso);
  final through = DateTime.parse(clock.dateAt(end.milliseconds - 1, zone).iso);
  final result = await showDateRangePicker(
    context: context,
    firstDate: DateTime(1900),
    lastDate: DateTime(clock.now.year + 20, 12, 31),
    initialDateRange: DateTimeRange(start: from, end: through),
  );
  if (result == null) return null;
  return (
    CalendarDate(result.start.toIso8601String().substring(0, 10)),
    CalendarDate(result.end.toIso8601String().substring(0, 10)),
  );
}
