import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../inventory/application/inventory_service.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/management_session_provider.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../management/presentation/protected_dialog.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/supplier_return.dart';
import 'supplier_finance_forms.dart';
import 'supplier_credit_approval_screen.dart';
import 'supplier_credits_screen.dart';

/// A saved draft changes no stock. Each quantity edit is durable, while an
/// unsaved reason remains owned by this route across lock/unlock and dirty Back.
class SupplierReturnScreen extends StatefulWidget {
  const SupplierReturnScreen({super.key, required this.id});
  final EntityId id;
  @override
  State<SupplierReturnScreen> createState() => _SupplierReturnScreenState();
}

class _SupplierReturnScreenState extends State<SupplierReturnScreen> {
  SupplierReturnDraft? draft;
  SupplierReturnDocument? document;
  final reason = TextEditingController(), reasonFocus = FocusNode();
  final fields = SupplierFormFocus();
  List<Map<String, Object?>> sources = [];
  SupplierReturnSourceCursor? sourceNext;
  String baseline = '', error = '';
  bool busy = false, started = false;
  int generation = 0;
  bool get dirty => reason.text != baseline;
  void check() {
    if (context.read<AppServices>().database.generation != generation) {
      throw const AppError('m3DraftChanged');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      generation = context.read<AppServices>().database.generation;
      run(refresh);
    }
  }

  Future<void> refresh() async {
    check();
    final service = context.read<AppServices>().inventory;
    final value = await service.supplierReturnDraft(widget.id);
    final finalDoc = value.posted == null
        ? null
        : await service.supplierReturnDocument(value.posted!);
    final page = value.status == 'draft'
        ? await service.supplierReturnSources(value.receipt)
        : null;
    if (mounted) {
      check();
      setState(() {
        draft = value;
        document = finalDoc;
        sources = page?.items ?? [];
        sourceNext = page?.nextCursor;
        if (!dirty) {
          reason.text = value.status == 'draft' ? value.reason : '';
          baseline = reason.text;
        }
      });
    }
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      check();
      await work();
    } catch (e) {
      if (mounted) {
        setState(() => error = safeError(e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> validateReason() async {
    if (reason.text.trim().isNotEmpty && reason.text.trim().length <= 300) {
      return true;
    }
    setState(
      () => error = reason.text.trim().isEmpty
          ? 'stockRemovalReasonIsRequired'
          : 'm53SupplierInputInvalid',
    );
    await fields.show('reason');
    if (mounted) reasonFocus.requestFocus();
    return false;
  }

  Future<void> post() async {
    if (!await validateReason() || !mounted) return;
    if (!await confirmSupplierFact(
          context,
          tr(context, 'm53ReturnConfirmHelp'),
          capability: ManagementCapability.inventory,
        ) ||
        !mounted) {
      return;
    }
    final revision = draft!.revision, note = reason.text;
    await run(() async {
      await context.read<AppServices>().inventory.confirmSupplierReturn(
        widget.id,
        revision,
        reason: note,
        operationKey: 'supplier-return/${widget.id.value}',
      );
      if (mounted) {
        reason.clear();
        baseline = '';
      }
      await refresh();
    });
  }

  Future<void> undo() async {
    if (!await validateReason() || !mounted) return;
    if (!await confirmSupplierFact(
          context,
          tr(context, 'm53ReturnUndoHelp'),
          capability: ManagementCapability.inventory,
        ) ||
        !mounted) {
      return;
    }
    final note = reason.text, key = const IdGenerator().next().value;
    await run(() async {
      await context.read<AppServices>().inventory.reverseSupplierReturn(
        widget.id,
        reason: note,
        operationKey: key,
      );
      if (mounted) {
        reason.clear();
        baseline = '';
      }
      await refresh();
    });
  }

  Future<void> edit(SupplierReturnLine line) async {
    final text = TextEditingController(text: '${line.quantity}'),
        focus = FocusNode();
    var active = false, submitted = false;
    String? errorKey;
    try {
      await showManagedDialog<bool>(
        context: context,
        builder: (dialog) => StatefulBuilder(
          builder: (dialog, setDialog) => FormExitGuard(
            capability: ManagementCapability.inventory,
            dirty: !submitted && text.text != '${line.quantity}',
            dirtyCheck: () => !submitted && text.text != '${line.quantity}',
            busy: active,
            child: ProtectedDialog(
              capability: ManagementCapability.inventory,
              child: AlertDialog(
                scrollable: true,
                title: Text(tr(dialog, 'm53ReturnQuantity')),
                content: ManagedTextField(
                  key: const ValueKey('supplier-return-quantity'),
                  controller: text,
                  focusNode: focus,
                  enabled: !active,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialog(() {}),
                  decoration: InputDecoration(
                    labelText: line.name,
                    errorText: errorKey == null ? null : tr(dialog, errorKey!),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: active
                        ? null
                        : () => Navigator.pop(dialog, false),
                    child: Text(tr(dialog, 'cancel')),
                  ),
                  FilledButton(
                    key: const ValueKey('supplier-return-quantity-save'),
                    onPressed: active
                        ? null
                        : () async {
                            setDialog(() {
                              active = true;
                              errorKey = null;
                            });
                            try {
                              final quantity = int.tryParse(text.text.trim());
                              if (quantity == null || quantity <= 0) {
                                throw const AppError(
                                  'm53ReturnQuantityInvalid',
                                );
                              }
                              check();
                              final value = await context
                                  .read<AppServices>()
                                  .inventory
                                  .setSupplierReturnQuantity(
                                    widget.id,
                                    draft!.revision,
                                    line.id,
                                    quantity,
                                  );
                              if (dialog.mounted) {
                                submitted = true;
                                if (mounted) setState(() => draft = value);
                                Navigator.pop(dialog, true);
                              }
                            } catch (e) {
                              if (dialog.mounted) {
                                setDialog(() => errorKey = safeError(e));
                                focus.requestFocus();
                              }
                            } finally {
                              if (dialog.mounted) {
                                setDialog(() => active = false);
                              }
                            }
                          },
                    child: Text(tr(dialog, 'save')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (mounted) await run(refresh);
    } finally {
      text.dispose();
      focus.dispose();
    }
  }

  @override
  void dispose() {
    reason.dispose();
    reasonFocus.dispose();
    fields.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = draft, posted = document;
    final owner =
        context.watch<ManagementSessionProvider>().service.role ==
        ManagementRole.owner;
    return ManagementGate(
      capability: ManagementCapability.inventory,
      child: ListenableBuilder(
        listenable: reason,
        builder: (context, _) => FormExitGuard(
          capability: ManagementCapability.inventory,
          dirty: dirty,
          dirtyCheck: () => dirty,
          busy: busy,
          child: Scaffold(
            appBar: AppBar(
              title: Text(tr(context, 'm53SupplierReturn')),
              actions: const [LanguageButton()],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  SizedBox(
                    height: 4,
                    child: busy ? const LinearProgressIndicator() : null,
                  ),
                  SizedBox(
                    key: ValueKey(
                      busy
                          ? 'supplier-return-loading'
                          : 'supplier-return-ready',
                    ),
                    height: 0,
                  ),
                  Expanded(
                    child: ListView(
                      key: const ValueKey('supplier-return-list'),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (error.isNotEmpty)
                          Text(
                            tr(context, error),
                            key: const ValueKey('supplier-return-error'),
                          ),
                        if (d != null) ...[
                          Text(d.row['supplier_name'] as String),
                          Text(tr(context, 'm53ReturnStatus${d.status}')),
                          Text(tr(context, 'm53ReturnNoAutomaticCredit')),
                          if (d.status == 'draft' ||
                              posted != null && !posted.reversed)
                            fields.anchor(
                              'reason',
                              ManagedTextField(
                                key: const ValueKey('supplier-return-reason'),
                                controller: reason,
                                focusNode: reasonFocus,
                                enabled: !busy,
                                decoration: InputDecoration(
                                  labelText: tr(context, 'correctionReason'),
                                  errorText:
                                      error == 'stockRemovalReasonIsRequired'
                                      ? tr(context, error)
                                      : null,
                                ),
                              ),
                            ),
                          if (d.status == 'draft') ...[
                            TextButton(
                              onPressed: busy || !dirty
                                  ? null
                                  : () => run(() async {
                                      final value = await context
                                          .read<AppServices>()
                                          .inventory
                                          .saveSupplierReturnReason(
                                            widget.id,
                                            d.revision,
                                            reason.text,
                                          );
                                      if (mounted) {
                                        setState(() {
                                          draft = value;
                                          reason.text = value.reason;
                                          baseline = value.reason;
                                        });
                                      }
                                    }),
                              child: Text(tr(context, 'm53ReturnSaveReason')),
                            ),
                            for (final line in d.lines)
                              Card(
                                child: ListTile(
                                  key: ValueKey(
                                    'supplier-return-line-${line.id.value}',
                                  ),
                                  title: Text(line.name),
                                  subtitle: Text(
                                    '${line.quantity} · ${tr(context, line.tracked ? "m31BaseUnit" : "m53ReturnUntrackedHelp")}',
                                  ),
                                  onTap: busy ? null : () => edit(line),
                                  trailing: IconButton(
                                    tooltip: tr(context, 'delete'),
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: busy
                                        ? null
                                        : () => run(() async {
                                            await context
                                                .read<AppServices>()
                                                .inventory
                                                .removeSupplierReturnLine(
                                                  widget.id,
                                                  d.revision,
                                                  line.id,
                                                );
                                            await refresh();
                                          }),
                                  ),
                                ),
                              ),
                            FilledButton(
                              key: const ValueKey('supplier-return-confirm'),
                              onPressed: busy || d.lines.isEmpty ? null : post,
                              child: Text(tr(context, 'm53ReturnConfirm')),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => run(() async {
                                      await context
                                          .read<AppServices>()
                                          .inventory
                                          .reviewSupplierReturnDraft(
                                            widget.id,
                                            d.revision,
                                          );
                                      await refresh();
                                    }),
                              child: Text(tr(context, 'm53ReturnReview')),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      if (await confirmSupplierFact(
                                            context,
                                            tr(context, 'm53ReturnCancelHelp'),
                                            capability:
                                                ManagementCapability.inventory,
                                          ) &&
                                          mounted) {
                                        await run(() async {
                                          await context
                                              .read<AppServices>()
                                              .inventory
                                              .cancelSupplierReturnDraft(
                                                widget.id,
                                                d.revision,
                                                reason: reason.text,
                                              );
                                          if (mounted) {
                                            reason.clear();
                                            baseline = '';
                                          }
                                          await refresh();
                                        });
                                      }
                                    },
                              child: Text(tr(context, 'm53ReturnCancel')),
                            ),
                            Text(tr(context, 'm53ReturnSourceItems')),
                            for (final source in sources)
                              Card(
                                child: ListTile(
                                  title: Text(
                                    source['product_name_snapshot'] as String,
                                  ),
                                  subtitle: Text(
                                    '${tr(context, "m53ReturnEligible")}: ${source['eligible_quantity']} · ${tr(context, "m53ReturnPhysicalAvailable")}: ${source['tracked'] == 1 ? source['batch_remaining'] ?? "—" : tr(context, "m53ReturnUntrackedHelp")}',
                                  ),
                                  trailing: IconButton(
                                    tooltip: tr(context, 'add'),
                                    icon: const Icon(Icons.add),
                                    key: ValueKey(
                                      'supplier-return-add-${source['receipt_item_id']}',
                                    ),
                                    onPressed:
                                        busy ||
                                            (source['eligible_quantity']
                                                    as int) <=
                                                0 ||
                                            d.lines.any(
                                              (line) =>
                                                  line.item.value ==
                                                  source['receipt_item_id'],
                                            ) ||
                                            source['tracked'] == 1 &&
                                                (source['batch_remaining'] ==
                                                        null ||
                                                    (source['batch_remaining']
                                                            as int) <=
                                                        0)
                                        ? null
                                        : () => run(() async {
                                            await context
                                                .read<AppServices>()
                                                .inventory
                                                .addSupplierReturnLine(
                                                  widget.id,
                                                  d.revision,
                                                  EntityId(
                                                    source['receipt_item_id']
                                                        as String,
                                                  ),
                                                );
                                            await refresh();
                                          }),
                                  ),
                                ),
                              ),
                            if (sourceNext != null)
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => run(() async {
                                        final page = await context
                                            .read<AppServices>()
                                            .inventory
                                            .supplierReturnSources(
                                              d.receipt,
                                              after: sourceNext,
                                            );
                                        if (mounted) {
                                          setState(() {
                                            sources = page.items;
                                            sourceNext = page.nextCursor;
                                          });
                                        }
                                      }),
                                child: Text(tr(context, 'm53SupplierNext')),
                              ),
                          ],
                          if (posted != null) ...[
                            Text(
                              '${tr(context, "correctionReason")}: ${posted.row['reason']}',
                            ),
                            if (posted.reversed)
                              Text(
                                '${tr(context, "m53ReturnReversed")}: ${posted.row['reversal_reason']}',
                              ),
                            Text(
                              tr(
                                context,
                                posted.reversed
                                    ? 'm53ReturnReversed'
                                    : posted.row['active_credit_id'] != null
                                    ? 'm53CreditApprovedStatus'
                                    : 'm53ReturnPendingCredit',
                              ),
                            ),
                            Text(
                              '${tr(context, "m53ReturnInventoryValue")}: ${posted.valueComplete ? moneyCodec(context, currency: posted.currency).formatSignedCost(posted.removedValue) : tr(context, "m53CostIncomplete")}',
                            ),
                            for (final line in posted.lines)
                              ListTile(
                                title: Text(line.name),
                                subtitle: Text(
                                  '${line.quantity} · ${line.tracked ? moneyCostLabel(context, line.row['before_complete'] == 1 ? line.row['removed_value_micros'] as int : null, currency: posted.currency) : tr(context, "m53ReturnUntrackedHelp")}',
                                ),
                              ),
                            if (!posted.reversed)
                              TextButton(
                                key: const ValueKey('supplier-return-undo'),
                                onPressed: busy ? null : undo,
                                child: Text(tr(context, 'm53ReturnUndo')),
                              ),
                            if (!posted.reversed && owner)
                              TextButton(
                                key: const ValueKey('supplier-return-credit'),
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final existing =
                                            posted.row['active_credit_id'];
                                        if (existing == null) {
                                          await Navigator.of(
                                            context,
                                          ).push<EntityId>(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  SupplierCreditApprovalScreen(
                                                    returnId: posted.id,
                                                  ),
                                            ),
                                          );
                                        } else {
                                          await Navigator.of(
                                            context,
                                          ).push<void>(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  SupplierCreditScreen(
                                                    id: EntityId(
                                                      existing as String,
                                                    ),
                                                  ),
                                            ),
                                          );
                                        }
                                        if (mounted) await run(refresh);
                                      },
                                child: Text(
                                  tr(
                                    context,
                                    posted.row['active_credit_id'] == null
                                        ? 'm53CreditApprove'
                                        : 'm53SupplierCredits',
                                  ),
                                ),
                              ),
                          ],
                        ],
                        TextButton(
                          onPressed: busy ? null : () => run(refresh),
                          child: Text(tr(context, 'm5Refresh')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
