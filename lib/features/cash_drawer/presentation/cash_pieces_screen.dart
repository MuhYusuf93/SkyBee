import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../management/presentation/management_gate.dart';
import '../domain/cash_pieces.dart';

/// Editing pieces has no SQL or cash effect. The calling financial form applies
/// a validated result to its durable draft/atomic commit only after Save.
final class CashPieceForm extends ChangeNotifier {
  CashPieceForm(this.currency, {CashPieces? initial, this.expected}) {
    if (initial != null) {
      Money(0, currency.code, currency.scale).compatible(initial.total);
    }
    if (expected != null) {
      Money(0, currency.code, currency.scale).compatible(expected!);
    }
    for (final denomination in CashDenominations.forCurrency(currency)) {
      fields[denomination] = TextEditingController(
        text: '${initial?.counts[denomination] ?? 0}',
      )..addListener(_changed);
    }
    _baseline = rawKey;
  }
  final CurrencyPolicy currency;
  final Money? expected;
  final Map<int, TextEditingController> fields = {};
  late final String _baseline;
  String? error;
  String get rawKey =>
      fields.entries.map((e) => '${e.key}:${e.value.text}').join('|');
  bool get dirty => rawKey != _baseline;
  CashPieces get pieces => CashPieces(currency, {
    for (final entry in fields.entries)
      entry.key: entry.value.text.isEmpty ? 0 : int.parse(entry.value.text),
  });
  int? get total {
    try {
      return pieces.total.amountMinor;
    } catch (_) {
      return null;
    }
  }

  void _changed() {
    error = null;
    notifyListeners();
  }

  void step(int denomination, int change) {
    final field = fields[denomination]!;
    final count = int.tryParse(field.text) ?? 0;
    if (count + change < 0 || count + change > CashPieces.maxCount) {
      error = 'm53CashCountInvalid';
      notifyListeners();
      return;
    }
    field.text = '${count + change}';
    field.selection = TextSelection.collapsed(offset: field.text.length);
  }

  void clear() {
    for (final field in fields.values) {
      field.text = '0';
    }
  }

  CashPieces? validate() {
    try {
      final result = pieces;
      if (expected != null &&
          result.total.amountMinor != expected!.amountMinor) {
        throw const AppError('m53CashCompositionMismatch');
      }
      return result;
    } catch (e) {
      error = e is AppError ? e.message : 'm53CashCountInvalid';
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }
}

class CashPiecesScreen extends StatelessWidget {
  const CashPiecesScreen({
    super.key,
    required this.currency,
    required this.titleKey,
    this.initial,
    this.expected,
    this.managementProtected = false,
  });
  final CurrencyPolicy currency;
  final String titleKey;
  final CashPieces? initial;
  final Money? expected;
  final bool managementProtected;
  @override
  Widget build(BuildContext context) {
    final body = ChangeNotifierProvider(
      create: (_) =>
          CashPieceForm(currency, initial: initial, expected: expected),
      child: _CashPiecesBody(titleKey, managementProtected),
    );
    return managementProtected ? ManagementGate(child: body) : body;
  }
}

class _CashPiecesBody extends StatelessWidget {
  const _CashPiecesBody(this.titleKey, this.managementProtected);
  final String titleKey;
  final bool managementProtected;
  @override
  Widget build(BuildContext context) {
    final form = context.watch<CashPieceForm>(),
        denominations = form.fields.keys.toList().reversed.toList();
    return FormExitGuard(
      dirty: form.dirty,
      dirtyCheck: () => form.dirty,
      managementProtected: managementProtected,
      child: Scaffold(
        appBar: AppBar(title: Text(tr(context, titleKey))),
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(context, 'm53CashDeclarationHelp')),
                          if (form.expected != null)
                            Text(
                              '${tr(context, 'm53CashRequiredTotal')}: ${moneyLabel(context, form.expected!.amountMinor, currency: form.currency)}',
                            ),
                          TextButton(
                            onPressed: form.clear,
                            child: Text(tr(context, 'm53CashClearCounts')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: denominations.length,
                    itemBuilder: (context, index) {
                      final denomination = denominations[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              moneyLabel(
                                context,
                                denomination,
                                currency: form.currency,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  key: ValueKey('pieces-minus-$denomination'),
                                  tooltip: tr(context, 'm53RemoveDenomination'),
                                  onPressed:
                                      (int.tryParse(
                                                form.fields[denomination]!.text,
                                              ) ??
                                              0) ==
                                          0
                                      ? null
                                      : () => form.step(denomination, -1),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Expanded(
                                  child: ManagedTextField(
                                    key: ValueKey('pieces-count-$denomination'),
                                    controller: form.fields[denomination],
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(7),
                                    ],
                                    decoration: InputDecoration(
                                      labelText: tr(
                                        context,
                                        'm53CashPieceCount',
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  key: ValueKey('pieces-plus-$denomination'),
                                  tooltip: tr(context, 'm53CashAddPiece'),
                                  onPressed: () => form.step(denomination, 1),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${tr(context, 'total')}: ${form.total == null ? tr(context, 'm53CashCountInvalid') : moneyLabel(context, form.total!, currency: form.currency)}',
                  ),
                  if (form.error != null) Text(tr(context, form.error!)),
                  FilledButton(
                    key: const ValueKey('pieces-save'),
                    onPressed: () {
                      final result = form.validate();
                      if (result == null) return;
                      // Complete only this editor route. A lock that covers it must
                      // never be popped by a delayed generic Navigator.pop.
                      final route = ModalRoute.of(context);
                      if (route != null && route.isActive) {
                        Navigator.of(context).removeRoute(route, result);
                      }
                    },
                    child: Text(tr(context, 'save')),
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
