import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../barcode/domain/barcode_camera.dart';
import '../../barcode/presentation/barcode_scanner_screen.dart';
import '../../inventory/presentation/whole_quantity_formatter.dart';
import '../../management/application/management_service.dart';
import '../../management/presentation/fresh_authentication.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../settings/presentation/language_button.dart';
import '../application/sale_returns_service.dart';
import '../domain/sale_refund_models.dart';
import '../domain/sale_return_models.dart';
import 'sale_refund_screen.dart';

/// The return draft is route-local and independent of the sales basket. Scanner
/// confirmation opens a source document and never posts any stock or money.
class SaleReturnsScreen extends StatefulWidget {
  const SaleReturnsScreen({super.key});
  @override
  State<SaleReturnsScreen> createState() => _SaleReturnsScreenState();
}

class _SaleReturnsScreenState extends State<SaleReturnsScreen> {
  final reference = TextEditingController(), reason = TextEditingController();
  final quantities = <EntityId, TextEditingController>{};
  final conditions = <EntityId, SaleReturnCondition>{};
  final pending = <PendingSaleRefund>[];
  SaleReturnSource? source;
  SaleReturnQuote? quote;
  SaleReturnReceipt? receipt;
  SaleRefundCursor? cursor;
  SaleReturnDayCursor? dayCursor;
  CalendarDate? day;
  final dayResults = <SaleReturnReference>[];
  String? error;
  String operation = const IdGenerator().next().value;
  int draft = 0;
  bool busy = false;
  bool refundRecorded = false;
  bool get dirty =>
      quantities.values.any((field) => field.text.isNotEmpty) ||
      reason.text.trim().isNotEmpty;

  @override
  void dispose() {
    reference.dispose();
    reason.dispose();
    for (final field in quantities.values) {
      field.dispose();
    }
    super.dispose();
  }

  void _clearDraft({bool releaseFields = false}) {
    final fields = quantities.values.toList();
    if (releaseFields) {
      quantities.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final field in fields) {
          field.dispose();
        }
      });
    } else {
      for (final field in fields) {
        field.clear();
      }
    }
    conditions.clear();
    reason.clear();
    quote = null;
    operation = const IdGenerator().next().value;
    draft++;
  }

  Future<void> lookup([String? selected]) async {
    final code = selected ?? reference.text.trim();
    if (busy || code.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final app = context.read<AppServices>();
    await _run(() async {
      final result = await app.saleReturns.lookup(code);
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        setState(() {
          source = result;
          reference.text = result.number;
          dayResults.clear();
          dayCursor = null;
          day = null;
        });
        await _loadPending(app, result.id);
      }
    });
  }

  Future<void> findDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: day == null ? now : DateTime.parse(day!.iso),
      firstDate: DateTime(1970),
      lastDate: DateTime(9999),
    );
    if (picked == null || !mounted) return;
    final date = CalendarDate(picked.toIso8601String().split('T').first);
    await _dayPage(date);
  }

  Future<void> _dayPage(CalendarDate date, {bool append = false}) async {
    final app = context.read<AppServices>();
    await _run(() async {
      final page = await app.saleReturns.byDay(
        date,
        after: append ? dayCursor : null,
      );
      if (!mounted) return;
      setState(() {
        day = date;
        if (!append) dayResults.clear();
        dayResults.addAll(page.items);
        dayCursor = page.nextCursor;
      });
    });
  }

  Future<void> scan() async {
    if (busy) return;
    final app = context.read<AppServices>();
    final result = await Navigator.push<SaleReturnSource>(
      context,
      MaterialPageRoute(
        builder: (scanner) => BarcodeScannerScreen(
          lookup: (code, requireIntent) async {
            final found = await app.saleReturns.lookup(code);
            requireIntent();
            if (scanner.mounted) Navigator.pop(scanner, found);
            return const BarcodeFeedback('m54ReturnSourceFound', success: true);
          },
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      source = result;
      reference.text = result.number;
    });
    await _run(() => _loadPending(app, result.id));
  }

  Future<void> _run(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _loadPending(
    AppServices app,
    EntityId sale, {
    bool append = false,
  }) async {
    final page = await app.saleRefunds.pending(
      sale,
      after: append ? cursor : null,
    );
    if (!mounted || source?.id != sale) return;
    setState(() {
      if (!append) pending.clear();
      pending.addAll(page.items);
      cursor = page.nextCursor;
    });
  }

  Future<void> preview() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final app = context.read<AppServices>();
    final sale = source!;
    await _run(() async {
      if (reason.text.trim().isEmpty || reason.text.trim().length > 500) {
        throw const AppError('m54ReturnReason');
      }
      final choices = <SaleReturnSelection>[];
      for (final item in sale.items) {
        final raw = quantities[item.id]?.text ?? '';
        if (raw.isEmpty) continue;
        final amount = int.tryParse(raw);
        if (amount == null || amount < 0 || amount > item.available) {
          throw const AppError('m54ReturnQuantity');
        }
        if (amount == 0) continue;
        final condition = conditions[item.id];
        if (condition == null) {
          throw const AppError('m54ReturnConditionRequired');
        }
        choices.add(SaleReturnSelection(item.id, amount, condition));
      }
      final result = await app.saleReturns.preview(sale.id, choices);
      if (mounted) setState(() => quote = result);
    });
  }

  Future<void> submit() async {
    final selected = quote;
    if (selected == null) return;
    final app = context.read<AppServices>();
    final sale = source!;
    await _run(() async {
      FreshActionProof? claim;
      var authenticated = false;
      try {
        if (selected.requiresOwner) {
          authenticated = await freshAuthentication(
            context,
            SaleReturnsService.ownerPurpose,
            pinOnly: true,
          );
          if (!authenticated || !mounted) return;
          claim = app.management.claimFresh(SaleReturnsService.ownerPurpose);
        }
        final result = await app.saleReturns.post(
          selected,
          operationKey: operation,
          reason: reason.text,
          ownerProof: claim,
        );
        if (!mounted) return;
        setState(() {
          receipt = result;
          _clearDraft();
        });
        final updated = await app.saleReturns.lookup(sale.number);
        if (mounted) setState(() => source = updated);
        await _loadPending(app, sale.id);
      } on AppError catch (e) {
        if (mounted &&
            (e.message == 'm54ReturnChanged' ||
                e.message == 'm54ReturnQuantity')) {
          final updated = await app.saleReturns.lookup(sale.number);
          if (mounted) {
            setState(() {
              source = updated;
              quote = null;
            });
          }
        }
        rethrow;
      } finally {
        if (authenticated) app.management.lock();
      }
    });
  }

  Future<void> refund(PendingSaleRefund item) async {
    final app = context.read<AppServices>();
    final sale = source!.id;
    final result = await Navigator.push<SaleRefundReceipt>(
      context,
      MaterialPageRoute(builder: (_) => SaleRefundScreen(refund: item)),
    );
    if (!mounted || result == null) return;
    setState(() => refundRecorded = true);
    await _run(() => _loadPending(app, sale));
  }

  String money(Money value) => moneyLabel(
    context,
    value.amountMinor,
    currency: CurrencyPolicy.forCode(value.currencyCode),
  );

  Widget line(SaleReturnItem item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.name, style: Theme.of(context).textTheme.titleMedium),
          Text(
            '${money(item.net)} · ${tr(context, 'm54ReturnSold')} ${item.sold} · ${tr(context, 'm54ReturnRemaining')} ${item.available}',
          ),
          if (item.warrantyUntil != null)
            Text(
              '${tr(context, 'm54WarrantyUntil')} ${item.warrantyUntil!.iso}',
            ),
          if (item.available > 0) ...[
            ManagedTextField(
              key: ValueKey('return-quantity-$draft-${item.id.value}'),
              controller: quantities.putIfAbsent(
                item.id,
                TextEditingController.new,
              ),
              enabled: !busy,
              keyboardType: TextInputType.number,
              inputFormatters: const [WholeQuantityFormatter()],
              decoration: InputDecoration(
                labelText: tr(context, 'm54ReturnQuantityLabel'),
              ),
              onChanged: (_) => setState(() => quote = null),
            ),
            DropdownButtonFormField<SaleReturnCondition>(
              key: ValueKey('return-condition-$draft-${item.id.value}'),
              initialValue: conditions[item.id],
              isExpanded: true,
              itemHeight: null,
              decoration: InputDecoration(
                labelText: tr(context, 'm54ReturnCondition'),
              ),
              items: [
                for (final value in SaleReturnCondition.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(
                      tr(
                        context,
                        value == SaleReturnCondition.good
                            ? 'm54ReturnGood'
                            : 'm54ReturnQuarantine',
                      ),
                    ),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (value) => setState(() {
                      conditions[item.id] = value!;
                      quote = null;
                    }),
            ),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final sale = source;
    final review = quote;
    final last = receipt;
    final clock = context.read<AppServices>().management.clock;
    return FormExitGuard(
      managementProtected: false,
      dirty: dirty,
      dirtyCheck: () => dirty,
      busy: busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'm54SaleReturnStock')),
          actions: const [LanguageButton()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(
                  tr(context, error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (sale == null) ...[
                ManagedTextField(
                  key: const ValueKey('sale-return-reference'),
                  controller: reference,
                  enabled: !busy,
                  autocorrect: false,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: tr(context, 'm54ReturnLookup'),
                  ),
                  onSubmitted: (_) => lookup(),
                ),
                FilledButton(
                  onPressed: busy ? null : lookup,
                  child: Text(tr(context, 'm54ReturnFind')),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : scan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(tr(context, 'm53CameraScan')),
                ),
                TextButton(
                  onPressed: busy ? null : findDay,
                  child: Text(tr(context, 'm54ReturnByDate')),
                ),
                if (day != null) Text(day!.iso),
                if (day != null && dayResults.isEmpty)
                  Text(tr(context, 'noHistoryYet')),
                for (final result in dayResults)
                  ListTile(
                    title: Text(result.number),
                    subtitle: Text(
                      '${clock.displayTime(result.createdAt, result.timeZone)} · ${money(result.total)}',
                    ),
                    onTap: busy ? null : () => lookup(result.number),
                  ),
                if (dayCursor != null)
                  TextButton(
                    onPressed: busy ? null : () => _dayPage(day!, append: true),
                    child: Text(tr(context, 'm3LoadMore')),
                  ),
              ] else ...[
                Text(
                  '${sale.number} · ${clock.displayTime(sale.createdAt, sale.timeZone)}',
                ),
                Text(
                  '${tr(context, 'm3RemainingDebt')} ${money(sale.outstanding)}',
                ),
                if (last != null) ...[
                  Text(
                    '${tr(context, 'm54ReturnSaved')} ${last.id.value.substring(0, 8)}',
                  ),
                  Text(
                    '${tr(context, 'm54ReturnDebtReduction')} ${money(last.debtReduction)}',
                  ),
                ],
                if (refundRecorded) Text(tr(context, 'm54RefundSettled')),
                for (final item in pending)
                  ListTile(
                    title: Text(
                      '${tr(context, 'm54RefundPending')} ${money(item.amount)}',
                    ),
                    subtitle: Text(
                      '${clock.displayTime(item.createdAt, sale.timeZone)} · ${item.reason}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: busy ? null : () => refund(item),
                  ),
                if (cursor != null)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            final app = context.read<AppServices>();
                            _run(
                              () => _loadPending(app, sale.id, append: true),
                            );
                          },
                    child: Text(tr(context, 'm3LoadMore')),
                  ),
                for (final item in sale.items) line(item),
                if (sale.items.any((item) => item.available > 0)) ...[
                  ManagedTextField(
                    controller: reason,
                    enabled: !busy,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: tr(context, 'm54ReturnReasonLabel'),
                    ),
                    onChanged: (_) => setState(() => quote = null),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : preview,
                    child: Text(tr(context, 'm54ReturnReview')),
                  ),
                  if (review != null) ...[
                    Text(
                      '${tr(context, 'm54ReturnAmount')} ${money(review.net)}',
                    ),
                    Text(
                      '${tr(context, 'm54ReturnDebtReduction')} ${money(review.debtReduction)}',
                    ),
                    Text(
                      '${tr(context, 'm54RefundPending')} ${money(review.refundDue)}',
                    ),
                    if (review.requiresOwner)
                      Text(tr(context, 'm54ReturnOwnerRequired')),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: Text(tr(context, 'm54ReturnSave')),
                    ),
                  ],
                ],
                TextButton(
                  onPressed: busy || dirty
                      ? null
                      : () => setState(() {
                          source = null;
                          receipt = null;
                          refundRecorded = false;
                          cursor = null;
                          pending.clear();
                          reference.clear();
                          _clearDraft(releaseFields: true);
                        }),
                  child: Text(tr(context, 'm54ReturnAnother')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
