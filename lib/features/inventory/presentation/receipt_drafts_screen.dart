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
import '../../management/domain/management_role.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../management/presentation/protected_dialog.dart';
import '../../settings/presentation/language_button.dart';
import '../application/inventory_service.dart';
import '../domain/inventory_models.dart';
import '../domain/receipt_draft.dart';
import 'product_form.dart';
import 'receipt_line_editor.dart';
import 'relation_field.dart';

/// One bounded page of durable drafts. Leaving a document retains its saved
/// lines; only the transient typed code needs the ordinary unsaved-input guard.
class ReceiptDraftsScreen extends StatefulWidget {
  const ReceiptDraftsScreen({super.key});
  @override
  State<ReceiptDraftsScreen> createState() => _ReceiptDraftsScreenState();
}

class _ReceiptDraftsScreenState extends State<ReceiptDraftsScreen> {
  List<Map<String, Object?>> rows = [];
  ReceiptDraftCursor? next;
  String? error;
  bool busy = false, started = false;
  String status = 'draft';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      load();
    }
  }

  Future<void> load({ReceiptDraftCursor? after}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final page = await context.read<AppServices>().inventory.receiptDrafts(
        after: after,
        status: status,
      );
      if (mounted) {
        setState(() {
          rows = page.items;
          next = page.nextCursor;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(EntityId id) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => ReceiptDraftScreen(id: id)));
    if (mounted) await load();
  }

  Future<void> create() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final doc = await context
          .read<AppServices>()
          .inventory
          .createReceiptDraft();
      if (mounted) {
        setState(() => busy = false);
        await open(doc.id);
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'm53ReceiptDrafts')),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: ListView(
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error != null) Text(tr(context, error!)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<String>(
                initialValue: status,
                isExpanded: true,
                itemHeight: null,
                items: [
                  for (final value in ['draft', 'posted', 'cancelled'])
                    DropdownMenuItem(
                      value: value,
                      child: Text(
                        tr(
                          context,
                          value == 'draft'
                              ? 'm53ReceiptDraft'
                              : value == 'posted'
                              ? 'm53ReceiptStatusPosted'
                              : 'm53ReceiptStatusCancelled',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        if (value != null) {
                          status = value;
                          load();
                        }
                      },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                key: const ValueKey('receipt-draft-create'),
                onPressed: busy ? null : create,
                icon: const Icon(Icons.add),
                label: Text(tr(context, 'm53ReceiptDraftNew')),
              ),
            ),
            for (final row in rows)
              ListTile(
                title: Text(
                  '${tr(context, 'm53ReceiptDraft')} ${row['id'].toString().substring(0, 8)}',
                ),
                subtitle: Text(
                  tr(
                    context,
                    status == 'draft'
                        ? 'm53ReceiptDraft'
                        : status == 'posted'
                        ? 'm53ReceiptStatusPosted'
                        : 'm53ReceiptStatusCancelled',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: busy ? null : () => open(EntityId(row['id'] as String)),
              ),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: busy ? null : () => load(),
                  child: Text(tr(context, 'm5Refresh')),
                ),
                if (next != null)
                  TextButton(
                    onPressed: busy ? null : () => load(after: next),
                    child: Text(tr(context, 'loadMore')),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class ReceiptDraftScreen extends StatefulWidget {
  const ReceiptDraftScreen({super.key, required this.id});
  final EntityId id;
  @override
  State<ReceiptDraftScreen> createState() => _ReceiptDraftScreenState();
}

class _ReceiptDraftScreenState extends State<ReceiptDraftScreen>
    with WidgetsBindingObserver {
  final code = TextEditingController(), reason = TextEditingController();
  late final inputs = Listenable.merge([code, reason]);
  final reverseKey = const IdGenerator().next().value;
  ReceiptDraft? doc;
  String? error;
  bool busy = false, started = false;
  int generation = 0;
  MasterRecord? get supplier => doc?.supplierId == null
      ? null
      : MasterRecord(
          id: doc!.supplierId!,
          name:
              doc!.row['supplier_name'] as String? ??
              tr(context, 'supplierOptional'),
        );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      generation = context.read<AppServices>().database.generation;
      load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) load();
  }

  Future<void> run(Future<ReceiptDraft> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await work();
      if (!mounted) return;
      if (context.read<AppServices>().database.generation != generation) {
        throw const AppError('m3DraftChanged');
      }
      setState(() => doc = value);
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() =>
      run(() => context.read<AppServices>().inventory.receiptDraft(widget.id));
  Future<bool> ask(String title, String message) async =>
      await showManagedDialog<bool>(
        context: context,
        builder: (_) => ProtectedDialog(
          capability: ManagementCapability.inventory,
          child: AlertDialog(
            scrollable: true,
            title: Text(tr(context, title)),
            content: Text(tr(context, message)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr(context, 'cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr(context, 'm5Confirm')),
              ),
            ],
          ),
        ),
      ) ??
      false;
  Future<void> register(String text) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ProductForm(initialBarcode: text, forReceiptDraft: true),
      ),
    );
    if (!mounted) return;
    final product = await context.read<AppServices>().inventory.lookupCode(
      text,
    );
    if (product != null && doc != null) {
      await run(
        () => context.read<AppServices>().inventory.addReceiptDraftProduct(
          doc!.id,
          doc!.revision,
          product.id,
        ),
      );
    }
  }

  Future<void> scan(String text) async {
    if (busy || doc == null || doc!.status != 'draft') return;
    final app = context.read<AppServices>();
    await run(
      () => app.inventory.scanReceiptDraft(doc!.id, doc!.revision, text),
    );
    if (!mounted) return;
    if (error == 'productNotFound') {
      if (await ask('productNotFound', 'm53ReceiptRegisterUnknown') &&
          mounted) {
        await register(text);
      }
    } else if (error == 'm53ReceiptChooseLine') {
      final product = await app.inventory.lookupCode(text);
      if (product != null &&
          mounted &&
          await ask('m53ReceiptChooseLine', 'm53ReceiptSeparateLine') &&
          mounted) {
        await run(
          () => app.inventory.addReceiptDraftProduct(
            doc!.id,
            doc!.revision,
            product.id,
            separateLine: true,
          ),
        );
      }
    } else if (error == null) {
      code.clear();
    }
  }

  Future<void> camera() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          inventory: true,
          lookup: (text) async {
            final app = context.read<AppServices>();
            final product = await app.inventory.lookupCode(text);
            if (product == null) {
              return const BarcodeFeedback('productNotFound', unknown: true);
            }
            await scan(text);
            return BarcodeFeedback(
              error ?? 'm53ReceiptDraftScanAdded',
              success: error == null,
            );
          },
          registerUnknown: register,
        ),
      ),
    );
  }

  Future<void> edit(ReceiptDraftLine line) async {
    if (busy || doc == null) return;
    final app = context.read<AppServices>(), revision = doc!.revision;
    try {
      final product = await app.inventory.detail(line.productId);
      if (!mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ReceiptLineEditor(
            product: product,
            initialLine: line,
            draftSupplier: supplier,
            supplierLocked: true,
            onSave: (value) async {
              await app.inventory.updateReceiptDraftLine(
                widget.id,
                revision,
                line.id,
                input: value.stock,
                cost: value.cost,
                confirmedFree: value.confirmedFree,
                expiry: value.expiry,
              );
            },
          ),
        ),
      );
      if (mounted) await load();
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    }
  }

  Future<void> confirm() async {
    if (busy || doc == null) return;
    if (!await ask('m53ReceiptDraftConfirm', 'm53ReceiptDraftConfirmHelp') ||
        !mounted) {
      return;
    }
    final app = context.read<AppServices>(), revision = doc!.revision;
    await run(() async {
      await app.inventory.confirmReceiptDraft(widget.id, revision);
      return app.inventory.receiptDraft(widget.id);
    });
    if (mounted && doc?.status == 'posted') code.clear();
  }

  Future<void> reverse() async {
    if (busy || doc == null || doc!.reversed) return;
    if (reason.text.trim().isEmpty) {
      setState(() => error = 'correctionReasonIsRequired');
      return;
    }
    if (!await ask('m53ReceiptDraftReverse', 'm53ReceiptDraftReverseHelp') ||
        !mounted) {
      return;
    }
    final app = context.read<AppServices>(),
        note = reason.text.trim(),
        receipt = doc!.receiptId!;
    await run(() async {
      await app.inventory.reverseReceipt(
        receipt,
        operationKey: reverseKey,
        reason: note,
        entireDocument: true,
      );
      return app.inventory.receiptDraft(widget.id);
    });
    if (doc?.reversed == true) reason.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    code.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: ListenableBuilder(
      listenable: inputs,
      builder: (context, _) => FormExitGuard(
        dirty: code.text.isNotEmpty || reason.text.isNotEmpty,
        dirtyCheck: () => code.text.isNotEmpty || reason.text.isNotEmpty,
        busy: busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'm53ReceiptDraft')),
            actions: const [LanguageButton()],
          ),
          body: SafeArea(
            child: ListView(
              key: ValueKey('receipt-document-${doc?.status ?? 'loading'}'),
              padding: const EdgeInsets.all(16),
              children: [
                if (busy) const LinearProgressIndicator(),
                Text(
                  tr(
                    context,
                    doc?.status == 'cancelled'
                        ? 'm53ReceiptDraftCancelled'
                        : doc?.reversed == true
                        ? 'm53ReceiptDraftReversed'
                        : doc?.status == 'posted'
                        ? 'm53ReceiptDraftPosted'
                        : 'm53ReceiptDraftSaved',
                  ),
                ),
                if (doc?.status == 'draft')
                  ExpansionTile(
                    title: Text(tr(context, 'm53ReceiptDraftHelp')),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(tr(context, 'm53ReceiptDraftNoStockYet')),
                      ),
                    ],
                  ),
                if (doc?.status == 'cancelled')
                  Text(tr(context, 'm53ReceiptDraftCancelled')),
                if (error != null) Text(tr(context, error!)),
                if (doc?.status == 'draft') ...[
                  RelationField(
                    key: ValueKey(doc!.supplierId),
                    kind: MasterKind.supplier,
                    value: supplier,
                    enabled: !busy,
                    onChanged: (s) => run(
                      () => context
                          .read<AppServices>()
                          .inventory
                          .setReceiptDraftSupplier(
                            widget.id,
                            doc!.revision,
                            s?.id,
                          ),
                    ),
                  ),
                  ManagedTextField(
                    key: const ValueKey('receipt-draft-code'),
                    controller: code,
                    enabled: !busy,
                    onSubmitted: scan,
                    decoration: InputDecoration(
                      labelText: tr(context, 'm53ReceiptDraftCode'),
                    ),
                  ),
                  Wrap(
                    spacing: 12,
                    children: [
                      FilledButton(
                        onPressed: busy ? null : () => scan(code.text),
                        child: Text(tr(context, 'm53ReceiptDraftAddCode')),
                      ),
                      IconButton(
                        onPressed: busy ? null : camera,
                        tooltip: tr(context, 'm53CameraScan'),
                        icon: const Icon(Icons.qr_code_scanner),
                      ),
                    ],
                  ),
                ],
                if (doc?.status == 'posted' && doc?.reversed != true) ...[
                  ManagedTextField(
                    controller: reason,
                    enabled: !busy,
                    decoration: InputDecoration(
                      labelText: tr(context, 'correctionReason'),
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : reverse,
                    child: Text(tr(context, 'm53ReceiptDraftReverse')),
                  ),
                ],
                for (final line in doc?.lines ?? <ReceiptDraftLine>[])
                  Card(
                    child: ListTile(
                      title: Text(line.name),
                      subtitle: Text(
                        '${line.input.count} ${line.input.unit.name == "base" ? tr(context, "m31BaseUnit") : tr(context, "m31PackUnit")} → ${line.input.quantityBase}\n'
                        '${line.totalMicros == null ? tr(context, "m53CostIncomplete") : moneyCostLabel(context, line.totalMicros, currency: doc!.currency)}${line.expiry == null ? '' : ' · ${line.expiry!.iso}'}',
                      ),
                      onTap: busy || doc?.status != 'draft'
                          ? null
                          : () => edit(line),
                      trailing: doc?.status != 'draft'
                          ? null
                          : IconButton(
                              tooltip: tr(context, 'delete'),
                              icon: const Icon(Icons.delete_outline),
                              onPressed: busy
                                  ? null
                                  : () => run(
                                      () => context
                                          .read<AppServices>()
                                          .inventory
                                          .removeReceiptDraftLine(
                                            widget.id,
                                            doc!.revision,
                                            line.id,
                                          ),
                                    ),
                            ),
                    ),
                  ),
                if (doc != null)
                  Text(
                    '${tr(context, "total")}: ${doc!.totalMicros == null ? tr(context, "m53CostIncomplete") : moneyCodec(context, currency: doc!.currency).formatSignedCost(doc!.totalMicros!)}',
                  ),
                if (doc?.status == 'draft') ...[
                  FilledButton(
                    key: const ValueKey('receipt-draft-confirm'),
                    onPressed: busy || doc!.lines.isEmpty ? null : confirm,
                    child: Text(tr(context, 'm53ReceiptDraftConfirm')),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (await ask(
                                  'm52Review',
                                  'm53ReceiptDraftReviewHelp',
                                ) &&
                                mounted) {
                              await run(
                                () => context
                                    .read<AppServices>()
                                    .inventory
                                    .reviewReceiptDraft(
                                      widget.id,
                                      doc!.revision,
                                    ),
                              );
                            }
                          },
                    child: Text(tr(context, 'm53ReceiptDraftReview')),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final service = context
                                .read<AppServices>()
                                .inventory;
                            if (await ask(
                                  'cancel',
                                  'm53ReceiptDraftCancelHelp',
                                ) &&
                                mounted) {
                              await run(() async {
                                await service.cancelReceiptDraft(
                                  widget.id,
                                  doc!.revision,
                                );
                                return service.receiptDraft(widget.id);
                              });
                            }
                          },
                    child: Text(tr(context, 'm53ReceiptDraftCancel')),
                  ),
                ],
                TextButton(
                  onPressed: busy ? null : load,
                  child: Text(tr(context, 'm5Refresh')),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
