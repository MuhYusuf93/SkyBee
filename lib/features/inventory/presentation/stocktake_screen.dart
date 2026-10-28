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
import '../domain/stock_input.dart';
import '../domain/stocktake_draft.dart';
import 'product_form.dart';
import 'stocktake_editors.dart';

/// Each route owns one bounded page or document, not the entire warehouse.
class StocktakesScreen extends StatefulWidget {
  const StocktakesScreen({super.key});
  @override
  State<StocktakesScreen> createState() => _StocktakesScreenState();
}

class _StocktakesScreenState extends State<StocktakesScreen> {
  List<Map<String, Object?>> rows = [];
  StocktakeCursor? next;
  bool started = false, busy = false;
  String status = 'draft';
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      load();
    }
  }

  Future<void> load({StocktakeCursor? after}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final page = await context.read<AppServices>().inventory.stocktakes(
        status: status,
        after: after,
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
    ).push<void>(MaterialPageRoute(builder: (_) => StocktakeScreen(id: id)));
    if (mounted) await load();
  }

  Future<void> create() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final doc = await context.read<AppServices>().inventory.createStocktake();
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
        title: Text(tr(context, 'm53Stocktakes')),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error != null) Text(tr(context, error!)),
            DropdownButtonFormField<String>(
              initialValue: status,
              isExpanded: true,
              items: [
                for (final s in ['draft', 'posted', 'cancelled'])
                  DropdownMenuItem(
                    value: s,
                    child: Text(tr(context, stocktakeStatus(s))),
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
            FilledButton.icon(
              key: const ValueKey('stocktake-create'),
              onPressed: busy ? null : create,
              icon: const Icon(Icons.add),
              label: Text(tr(context, 'm53StocktakeNew')),
            ),
            for (final row in rows)
              ListTile(
                title: Text(
                  '${tr(context, 'm53Stocktake')} ${row['id'].toString().substring(0, 8)}',
                ),
                subtitle: Text(
                  '${tr(context, stocktakeStatus(row['status'] as String))} · ${DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int).toLocal()}',
                ),
                onTap: busy ? null : () => open(EntityId(row['id'] as String)),
              ),
            Wrap(
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

String stocktakeStatus(String status) => status == 'posted'
    ? 'm53StocktakePosted'
    : status == 'cancelled'
    ? 'm53ReceiptStatusCancelled'
    : 'm53StocktakeDraft';

/// Product-detail entry uses the same durable baseline/CAS flow as scan counts.
/// Merely including a product leaves NULL; it never pre-fills physical stock.
Future<void> openProductStocktake(
  BuildContext context,
  EntityId product,
) async {
  final app = context.read<AppServices>();
  final generation = app.database.generation;
  try {
    var draft = await app.inventory.createStocktake();
    if (app.database.generation != generation) {
      throw const AppError('m3DraftChanged');
    }
    draft = await app.inventory.includeStocktakeProduct(
      draft.id,
      draft.revision,
      product,
    );
    if (context.mounted && app.database.generation == generation) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => StocktakeScreen(id: draft.id)),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr(context, safeError(e)))));
    }
  }
}

class StocktakeScreen extends StatefulWidget {
  const StocktakeScreen({super.key, required this.id});
  final EntityId id;
  @override
  State<StocktakeScreen> createState() => _StocktakeScreenState();
}

class _StocktakeScreenState extends State<StocktakeScreen> {
  StocktakeDraft? doc;
  final code = TextEditingController(),
      reason = TextEditingController(),
      reasonFocus = FocusNode();
  final reasonKey = GlobalKey();
  final scroll = ScrollController();
  final lineKeys = <EntityId, GlobalKey>{};
  Map<EntityId, String> issues = {};
  late final inputs = Listenable.merge([code, reason]);
  bool started = false, busy = false;
  int generation = 0;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      generation = context.read<AppServices>().database.generation;
      load();
    }
  }

  void checkGeneration() {
    if (context.read<AppServices>().database.generation != generation) {
      throw const AppError('m3DraftChanged');
    }
  }

  Future<bool> run(Future<StocktakeDraft> Function() work) async {
    if (busy) return false;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      checkGeneration();
      final value = await work();
      if (!mounted) return false;
      checkGeneration();
      setState(() {
        doc = value;
        issues = {};
      });
      return true;
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() =>
      run(() => context.read<AppServices>().inventory.stocktake(widget.id));
  Future<bool> ask(
    String title,
    String message, {
    bool summary = false,
  }) async =>
      await showManagedDialog<bool>(
        context: context,
        builder: (dialog) => ProtectedDialog(
          capability: ManagementCapability.inventory,
          child: AlertDialog(
            scrollable: true,
            title: Text(tr(dialog, title)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr(dialog, message)),
                if (summary)
                  for (final line in doc!.lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '${line.name}\n${stocktakeLineLabel(dialog, line, currency: doc!.currency)}',
                      ),
                    ),
                TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: Text(tr(dialog, 'cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: Text(tr(dialog, 'm5Confirm')),
                ),
              ],
            ),
          ),
        ),
      ) ??
      false;
  Future<void> scan({String? literal, bool includeOnly = false}) async {
    if (busy || doc == null) return;
    final text = literal ?? code.text;
    final service = context.read<AppServices>().inventory;
    StocktakeScanResult? result;
    final ok = await run(() async {
      if (includeOnly) {
        final p = await service.lookupCode(text);
        if (p == null) throw const AppError('productNotFound');
        return service.includeStocktakeProduct(doc!.id, doc!.revision, p.id);
      }
      result = await service.scanStocktake(doc!.id, doc!.revision, text);
      return result!.draft;
    });
    if (!mounted) return;
    if (ok) {
      code.clear();
      if (result?.needsBatchChoice == true) {
        setState(() => error = 'm53StocktakeBatchChoice');
        await line(doc!.lines.singleWhere((l) => l.id == result!.lineId));
      }
    } else if (error == 'productNotFound' &&
        await ask('productNotFound', 'm53StocktakeRegister') &&
        mounted) {
      await register(text);
    }
  }

  Future<void> register(String literal) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ProductForm(initialBarcode: literal, forReceiptDraft: true),
      ),
    );
    if (mounted) await load();
  }

  Future<void> camera() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          inventory: true,
          lookup: (literal) async {
            final product = await context
                .read<AppServices>()
                .inventory
                .lookupCode(literal);
            if (product == null) {
              return const BarcodeFeedback('productNotFound', unknown: true);
            }
            await scan(literal: literal);
            return BarcodeFeedback(
              error ?? 'm53StocktakeScanAdded',
              success: error == null,
            );
          },
          registerUnknown: register,
        ),
      ),
    );
  }

  Future<void> line(StocktakeLine line) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            StocktakeLineScreen(draftId: widget.id, lineId: line.id),
      ),
    );
    if (mounted) await load();
  }

  Future<void> confirm() async {
    if (doc == null || busy) return;
    if (reason.text.trim().isEmpty) {
      setState(() => error = 'stockCountReasonIsRequired');
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && reasonKey.currentContext != null) {
        await Scrollable.ensureVisible(
          reasonKey.currentContext!,
          alignment: .15,
        );
        if (mounted) reasonFocus.requestFocus();
      }
      return;
    }
    final service = context.read<AppServices>().inventory;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => busy = true);
    try {
      checkGeneration();
      final review = await service.reviewStocktake(doc!.id);
      if (!mounted) return;
      checkGeneration();
      setState(() => issues = review);
      if (review.isNotEmpty) {
        setState(() => error = review.values.first);
        await WidgetsBinding.instance.endOfFrame;
        final key = lineKeys[review.keys.first];
        if (scroll.hasClients) scroll.jumpTo(0);
        for (
          var i = 0;
          mounted &&
              key?.currentContext == null &&
              scroll.hasClients &&
              i < 100;
          i++
        ) {
          scroll.jumpTo(
            (scroll.offset + 300).clamp(0, scroll.position.maxScrollExtent),
          );
          await WidgetsBinding.instance.endOfFrame;
        }
        if (mounted && key?.currentContext != null) {
          await Scrollable.ensureVisible(key!.currentContext!, alignment: .15);
        }
        return;
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
      return;
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (!await ask(
          'm53StocktakeFinalize',
          'm53StocktakeFinalizeHelp',
          summary: true,
        ) ||
        !mounted) {
      return;
    }
    if (await run(
      () => context.read<AppServices>().inventory.confirmStocktake(
        doc!.id,
        doc!.revision,
        reason: reason.text,
      ),
    )) {
      code.clear();
      reason.clear();
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    code.dispose();
    reason.dispose();
    reasonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: ListenableBuilder(
      listenable: inputs,
      builder: (context, _) => FormExitGuard(
        capability: ManagementCapability.inventory,
        dirty: code.text.isNotEmpty || reason.text.isNotEmpty,
        dirtyCheck: () => code.text.isNotEmpty || reason.text.isNotEmpty,
        busy: busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'm53Stocktake')),
            actions: const [LanguageButton()],
          ),
          body: SafeArea(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              children: [
                if (busy) const LinearProgressIndicator(),
                if (doc != null)
                  Text(tr(context, stocktakeStatus(doc!.status))),
                if (error != null)
                  Text(
                    tr(context, error!),
                    key: const ValueKey('stocktake-error'),
                  ),
                ExpansionTile(
                  title: Text(tr(context, 'm53StocktakeHelp')),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(tr(context, 'm53StocktakeHelpBody')),
                    ),
                  ],
                ),
                if (doc?.status == 'draft') ...[
                  ManagedTextField(
                    controller: code,
                    enabled: !busy,
                    decoration: InputDecoration(
                      labelText: tr(context, 'm53ReceiptDraftCode'),
                    ),
                    onSubmitted: (_) => scan(),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        key: const ValueKey('stocktake-scan'),
                        onPressed: busy ? null : () => scan(),
                        child: Text(tr(context, 'm53StocktakeScan')),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => scan(includeOnly: true),
                        child: Text(tr(context, 'm53StocktakeInclude')),
                      ),
                      IconButton(
                        tooltip: tr(context, 'm53CameraScan'),
                        onPressed: busy ? null : camera,
                        icon: const Icon(Icons.qr_code_scanner),
                      ),
                      TextButton(
                        key: const ValueKey('stocktake-undo'),
                        onPressed: busy
                            ? null
                            : () => run(
                                () => context
                                    .read<AppServices>()
                                    .inventory
                                    .undoStocktake(doc!.id, doc!.revision),
                              ),
                        child: Text(tr(context, 'm53StocktakeUndo')),
                      ),
                    ],
                  ),
                ],
                if (doc != null && doc!.lines.isEmpty)
                  Text(tr(context, 'm53StocktakeEmpty')),
                if (doc != null)
                  for (final l in doc!.lines)
                    Container(
                      key: lineKeys.putIfAbsent(l.id, () => GlobalKey()),
                      child: ListTile(
                        key: ValueKey('stocktake-line-${l.productId.value}'),
                        title: Text(l.name),
                        subtitle: Text(
                          '${stocktakeLineLabel(context, l, currency: doc!.currency)}${issues[l.id] == null ? '' : '\n${tr(context, 'm53StocktakeReviewLine')}'}',
                        ),
                        onTap: busy ? null : () => line(l),
                      ),
                    ),
                if (doc?.status == 'posted') ...[
                  Text(
                    '${tr(context, 'correctionReason')}: ${doc!.row['reason']}',
                  ),
                  Text(
                    '${tr(context, doc!.row['actor_role'] == 'owner' ? 'm53OwnerRole' : 'm53WarehouseRole')} · ${DateTime.fromMillisecondsSinceEpoch(doc!.row['posted_at'] as int).toLocal()}',
                  ),
                ],
                if (doc?.status == 'draft') ...[
                  ManagedTextField(
                    key: reasonKey,
                    controller: reason,
                    focusNode: reasonFocus,
                    enabled: !busy,
                    maxLength: 300,
                    decoration: InputDecoration(
                      labelText: tr(context, 'correctionReason'),
                      errorText: error == 'stockCountReasonIsRequired'
                          ? tr(context, error!)
                          : null,
                    ),
                  ),
                  FilledButton(
                    key: const ValueKey('stocktake-finalize'),
                    onPressed: busy || !doc!.allCounted ? null : confirm,
                    child: Text(tr(context, 'm53StocktakeFinalize')),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (await ask(
                                  'm53StocktakeCancel',
                                  'm53StocktakeCancelHelp',
                                ) &&
                                mounted) {
                              if (await run(() async {
                                final service = context
                                    .read<AppServices>()
                                    .inventory;
                                await service.cancelStocktake(
                                  doc!.id,
                                  doc!.revision,
                                );
                                return service.stocktake(doc!.id);
                              })) {
                                code.clear();
                                reason.clear();
                              }
                            }
                          },
                    child: Text(tr(context, 'm53StocktakeCancel')),
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

String stocktakeLineLabel(
  BuildContext context,
  StocktakeLine line, {
  CurrencyPolicy? currency,
}) =>
    '${tr(context, 'm53StocktakeSystem')}: ${line.baselineQuantity} ${line.baseUnit}\n'
    '${tr(context, 'm53StocktakePhysical')}: ${line.counted?.toString() ?? '${tr(context, 'm53StocktakeUncounted')} (${line.partialCount}; ${line.pendingBatches})'}\n'
    '${tr(context, 'm53StocktakeDifference')}: ${line.delta?.toString() ?? '—'}'
    '${currency == null ? '' : '\n${tr(context, 'm53StocktakeValueDifference')}: ${line.estimatedValueDelta == null ? tr(context, 'm53CostIncomplete') : '${line.estimatedValueDelta! < 0 ? '−' : '+'}${moneyCostLabel(context, line.estimatedValueDelta!.abs(), currency: currency)}'}'}';

class StocktakeLineScreen extends StatefulWidget {
  const StocktakeLineScreen({
    super.key,
    required this.draftId,
    required this.lineId,
  });
  final EntityId draftId, lineId;
  @override
  State<StocktakeLineScreen> createState() => _StocktakeLineScreenState();
}

class _StocktakeLineScreenState extends State<StocktakeLineScreen> {
  StocktakeDraft? doc;
  List<StocktakeObservation> rows = [];
  StocktakeObservationCursor? next;
  String? error;
  bool busy = false, started = false;
  int generation = 0;
  StocktakeLine? get line =>
      doc?.lines.where((l) => l.id == widget.lineId).firstOrNull;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      generation = context.read<AppServices>().database.generation;
      load();
    }
  }

  void check() {
    if (context.read<AppServices>().database.generation != generation) {
      throw const AppError('m3DraftChanged');
    }
  }

  Future<void> load({
    StocktakeObservationCursor? after,
    Future<StocktakeDraft> Function()? write,
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      check();
      final service = context.read<AppServices>().inventory;
      final d = write == null
          ? await service.stocktake(widget.draftId)
          : await write();
      final p = await service.stocktakeObservations(
        widget.lineId,
        after: after,
      );
      if (mounted) {
        check();
        setState(() {
          doc = d;
          rows = p.items;
          next = p.nextCursor;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit(StocktakeObservation observation) async {
    if (busy || doc?.status != 'draft') return;
    final app = context.read<AppServices>(), revision = doc!.revision;
    try {
      check();
      final p = await app.inventory.detail(line!.productId);
      if (!mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => StocktakeCountEditor(
            product: p,
            observation: observation,
            onSave: (input, expiry) async {
              check();
              await app.inventory.setStocktakeCount(
                widget.draftId,
                revision,
                observation.id,
                input,
                expiry: observation.newBatch ? expiry : null,
                clearExpiry: observation.newBatch && expiry == null,
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

  Future<void> value() async {
    final app = context.read<AppServices>(), revision = doc!.revision;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StocktakeValueEditor(
          line: line!,
          currency: doc!.currency,
          onSave: (total, free) async {
            check();
            await app.inventory.setStocktakeEmptyValue(
              widget.draftId,
              revision,
              line!.id,
              total,
              confirmedFree: free,
            );
          },
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> recount() async {
    final confirmed = await showManagedDialog<bool>(
      context: context,
      builder: (dialog) => ProtectedDialog(
        capability: ManagementCapability.inventory,
        child: AlertDialog(
          scrollable: true,
          title: Text(tr(dialog, 'm53StocktakeRecount')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr(dialog, 'm53StocktakeRecountHelp')),
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(tr(dialog, 'cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(tr(dialog, 'm5Confirm')),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await load(
        write: () => context.read<AppServices>().inventory.recountStocktakeLine(
          widget.draftId,
          doc!.revision,
          widget.lineId,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'm53StocktakeBatches')),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error != null) Text(tr(context, error!)),
            if (line != null) ...[
              Text(line!.name),
              Text(stocktakeLineLabel(context, line!, currency: doc!.currency)),
            ],
            Text(tr(context, 'm53StocktakeBatchHelp')),
            for (final row in rows)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${tr(context, 'm53StocktakeExpiry')}: ${row.expiry?.iso ?? '—'}',
                      ),
                      Text(
                        '${tr(context, 'm53StocktakeSystem')}: ${row.baselineQuantity}',
                      ),
                      Text(
                        '${tr(context, 'm53StocktakePhysical')}: ${row.counted?.toString() ?? tr(context, 'm53StocktakeUncounted')}',
                      ),
                      if (row.input?.unit == StockInputUnit.pack)
                        Text(
                          '${row.input!.count} × ${row.input!.packSize} ${row.input!.packLabel}',
                        ),
                      if (doc?.status == 'draft')
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              key: ValueKey('stocktake-edit-${row.id.value}'),
                              onPressed: busy ? null : () => edit(row),
                              child: Text(tr(context, 'm53StocktakeEdit')),
                            ),
                            TextButton(
                              key: ValueKey('stocktake-plus-${row.id.value}'),
                              onPressed: busy
                                  ? null
                                  : () => load(
                                      write: () => context
                                          .read<AppServices>()
                                          .inventory
                                          .setStocktakeCount(
                                            widget.draftId,
                                            doc!.revision,
                                            row.id,
                                            StockInput(
                                              checkedNonNegative(
                                                BigInt.from(row.counted ?? 0) +
                                                    BigInt.one,
                                              ),
                                            ),
                                          ),
                                    ),
                              child: Text(tr(context, 'm53StocktakePlus')),
                            ),
                            TextButton(
                              onPressed:
                                  busy ||
                                      row.counted == null ||
                                      row.counted == 0
                                  ? null
                                  : () => load(
                                      write: () => context
                                          .read<AppServices>()
                                          .inventory
                                          .setStocktakeCount(
                                            widget.draftId,
                                            doc!.revision,
                                            row.id,
                                            StockInput(row.counted! - 1),
                                          ),
                                    ),
                              child: Text(tr(context, 'm53StocktakeMinus')),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => load(
                                      write: () => context
                                          .read<AppServices>()
                                          .inventory
                                          .setStocktakeCount(
                                            widget.draftId,
                                            doc!.revision,
                                            row.id,
                                            null,
                                          ),
                                    ),
                              child: Text(tr(context, 'm53StocktakeReset')),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => load(
                                      write: () => context
                                          .read<AppServices>()
                                          .inventory
                                          .setStocktakeCount(
                                            widget.draftId,
                                            doc!.revision,
                                            row.id,
                                            StockInput(0),
                                          ),
                                    ),
                              key: ValueKey('stocktake-zero-${row.id.value}'),
                              child: Text(tr(context, 'm53StocktakeZero')),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            Wrap(
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
            if (doc?.status == 'draft' && line != null) ...[
              TextButton(
                onPressed: busy
                    ? null
                    : () => load(
                        write: () => context
                            .read<AppServices>()
                            .inventory
                            .addStocktakeBatch(
                              widget.draftId,
                              doc!.revision,
                              widget.lineId,
                            ),
                      ),
                child: Text(tr(context, 'm53StocktakeNewBatch')),
              ),
              if (line!.baselineQuantity == 0 &&
                  line!.counted != null &&
                  line!.counted! > 0) ...[
                Text(
                  '${tr(context, 'm53StocktakeValue')}: ${moneyCostLabel(context, line!.row['empty_pool_total_micros'] as int?, currency: doc!.currency)}',
                ),
                TextButton(
                  onPressed: busy ? null : value,
                  child: Text(tr(context, 'm53StocktakeValue')),
                ),
              ],
              TextButton(
                onPressed: busy ? null : recount,
                child: Text(tr(context, 'm53StocktakeRecount')),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          check();
                          await context
                              .read<AppServices>()
                              .inventory
                              .removeStocktakeLine(
                                widget.draftId,
                                doc!.revision,
                                widget.lineId,
                              );
                          if (mounted) Navigator.of(this.context).pop();
                        } catch (e) {
                          if (mounted) setState(() => error = safeError(e));
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                child: Text(tr(context, 'm53StocktakeRemove')),
              ),
            ],
            if (doc?.status == 'posted' && line != null)
              Text(
                '${tr(context, 'm53StocktakeValueDifference')}: ${line!.valueDelta == null ? tr(context, 'm53CostIncomplete') : moneyCostLabel(context, line!.valueDelta!.abs(), currency: doc!.currency)} ${line!.valueDelta == null
                    ? ''
                    : line!.valueDelta! < 0
                    ? '(−)'
                    : '(+)'}',
              ),
          ],
        ),
      ),
    ),
  );
}
