import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../core/pagination/paged_controller.dart';
import '../../../core/presentation/route_input_scope.dart';
import '../../../l10n/localization.dart';
import '../../barcode/domain/barcode_camera.dart';
import '../../barcode/presentation/barcode_scanner_screen.dart';
import '../../inventory/application/inventory_service.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../inventory/domain/stock_input.dart';
import '../../inventory/presentation/receipt_product_picker.dart';
import '../../inventory/presentation/whole_quantity_formatter.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/managed_text_field.dart';
import '../domain/supplier_return_preparation.dart';
import 'supplier_finance_forms.dart';

part 'supplier_preparation_forms.dart';

const _inventory = ManagementCapability.inventory;

String _bucketLabel(SupplierReturnBucket bucket) => switch (bucket) {
  SupplierReturnBucket.batch => 'm54PrepBatch',
  SupplierReturnBucket.quarantine => 'm54PrepQuarantine',
  SupplierReturnBucket.observed => 'm54PrepObserved',
};

class SupplierPreparationScreen extends StatefulWidget {
  const SupplierPreparationScreen({super.key, required this.id});
  final EntityId id;

  @override
  State<SupplierPreparationScreen> createState() =>
      _SupplierPreparationScreenState();
}

class _SupplierPreparationScreenState extends State<SupplierPreparationScreen> {
  final _input = RouteInputScope();
  final _barcode = TextEditingController();
  SupplierReturnPreparation? _doc;
  List<Map<String, Object?>> _dispatches = [];
  EntityId? _next;
  int? _generation;
  bool _busy = false;
  String? _error;

  AppServices get _app => context.read<AppServices>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _input.attach(
      context.read<RouteObserver<ModalRoute<dynamic>>?>(),
      ModalRoute.of(context),
    );
    if (_generation != null) return;
    _generation = _app.database.generation;
    _run(_refresh);
  }

  void _requireCurrent() {
    if (!mounted ||
        _app.database.generation != _generation ||
        !_input.canReceive) {
      throw const AppError('m53ReturnChanged');
    }
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => _error = safeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final app = _app;
    final doc = await app.inventory.supplierReturnPreparation(widget.id);
    final page = await app.inventory.supplierPreparationDispatches(widget.id);
    if (!mounted) return;
    if (app.database.generation != _generation) {
      throw const AppError('m53ReturnChanged');
    }
    setState(() {
      _doc = doc;
      _dispatches = page.items;
      _next = page.nextCursor;
    });
  }

  Future<void> _select([InventoryProduct? scanned]) async {
    final service = _app.inventory;
    final revision = _doc!.revision;
    final picked = await Navigator.of(context).push<ReceiptProductSelection>(
      MaterialPageRoute(builder: (_) => ReceiptProductPicker(product: scanned)),
    );
    if (picked == null || !mounted) return;
    _requireCurrent();
    final product = await service.detail(picked.product);
    if (!mounted) return;
    _requireCurrent();
    final choice = await Navigator.of(context).push<_SourceChoice>(
      MaterialPageRoute(
        builder: (_) => _PreparationSourcePicker(
          product: product,
          quantity: picked.quantity,
        ),
      ),
    );
    if (!mounted || choice == null) return;
    _requireCurrent();
    final guard = _input.capture();
    if (choice.source case final source?) {
      final prior = _doc!.lines
          .where(
            (line) =>
                line.bucket == source.bucket && line.sourceId == source.id,
          )
          .firstOrNull;
      await service.reserveSupplierPreparationSource(
        widget.id,
        revision,
        source.bucket,
        source.id,
        picked.quantity + (prior?.remaining ?? 0),
        note: choice.note,
        requireIntent: guard,
      );
    } else {
      await service.observeSupplierPreparationStock(
        widget.id,
        revision,
        picked.product,
        picked.quantity,
        note: choice.note,
        requireIntent: guard,
      );
    }
    if (mounted) await _refresh();
  }

  Future<void> _scanText(String value) => _run(() async {
    if (value.trim().isEmpty) return;
    final guard = _input.capture();
    final product = await _app.inventory.lookupCode(value);
    guard();
    if (product == null) throw const AppError('productNotFound');
    if (_barcode.text == value) _barcode.clear();
    await _select(product);
  });

  Future<void> _scanCamera() => _run(() async {
    final service = _app.inventory;
    InventoryProduct? product;
    final scanned = await Navigator.of(context).push<InventoryProduct>(
      MaterialPageRoute(
        builder: (scanner) => BarcodeScannerScreen(
          inventory: true,
          lookup: (code, guard) async {
            final found = await service.lookupCode(code);
            guard();
            product = found;
            return found == null
                ? const BarcodeFeedback('productNotFound', unknown: true)
                : const BarcodeFeedback('m54PrepProductFound', success: true);
          },
          onAccepted: () => Navigator.pop(scanner, product),
        ),
      ),
    );
    if (mounted && scanned != null) {
      _requireCurrent();
      await _select(scanned);
    }
  });

  Future<void> _setQuantity(
    SupplierPreparationLine line,
    int revision,
    int quantity,
  ) async {
    _requireCurrent();
    await _app.inventory.reserveSupplierPreparationSource(
      widget.id,
      revision,
      line.bucket,
      line.sourceId,
      quantity,
      note: line.row['note'] as String,
      requireIntent: _input.capture(),
    );
    if (mounted) await _refresh();
  }

  Future<void> _edit(SupplierPreparationLine line) => _run(() async {
    final revision = _doc!.revision;
    final text = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _PreparationTextScreen(
          title: 'm53ReturnQuantity',
          label: line.name,
          initial: '${line.remaining}',
          quantity: true,
        ),
      ),
    );
    if (!mounted || text == null) return;
    await _setQuantity(line, revision, parseWholeQuantity(text));
  });

  Future<void> _dispatch() => _run(() async {
    final doc = _doc!;
    final selection = await Navigator.of(context).push<_DispatchChoice>(
      MaterialPageRoute(builder: (_) => _PreparationDispatchScreen(doc: doc)),
    );
    if (!mounted || selection == null) return;
    _requireCurrent();
    await _app.inventory.dispatchSupplierReturnPreparation(
      doc.id,
      doc.revision,
      selection.quantities,
      operationKey: const IdGenerator().next().value,
      reason: selection.reason,
      rejectRemaining: selection.rejectRemaining,
      creditClaim: selection.credit,
      requireIntent: _input.capture(),
    );
    if (mounted) await _refresh();
  });

  Future<void> _cancel() => _run(() async {
    final doc = _doc!;
    if (!await confirmSupplierFact(
      context,
      tr(context, 'm53ReturnCancelHelp'),
      capability: _inventory,
    )) {
      return;
    }
    _requireCurrent();
    await _app.inventory.cancelSupplierReturnPreparation(
      doc.id,
      doc.revision,
      requireIntent: _input.capture(),
    );
    if (mounted) await _refresh();
  });

  Future<void> _reverse(EntityId id) => _run(() async {
    final reason = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _PreparationTextScreen(
          title: 'm53ReturnUndo',
          label: tr(context, 'm54PrepReason'),
          requiredText: true,
        ),
      ),
    );
    if (!mounted || reason == null) return;
    _requireCurrent();
    await _app.inventory.reverseSupplierPreparationDispatch(
      id,
      operationKey: const IdGenerator().next().value,
      reason: reason,
      requireIntent: _input.capture(),
    );
    if (mounted) await _refresh();
  });

  @override
  void dispose() {
    _barcode.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final draft = doc?.status == 'draft';
    return ManagementGate(
      capability: _inventory,
      child: Scaffold(
        appBar: AppBar(title: Text(tr(context, 'm54PrepareReturn'))),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error case final error?) Text(tr(context, error)),
              if (doc == null && !_busy)
                TextButton(
                  onPressed: () => _run(_refresh),
                  child: Text(tr(context, 'm53SupplierFirst')),
                ),
              if (doc != null) ...[
                Text(doc.supplierName),
                Text(
                  tr(context, switch (doc.status) {
                    'closed' => 'm53ReturnStatusposted',
                    'cancelled' => 'm53ReturnStatuscancelled',
                    _ => 'm53ReturnStatusdraft',
                  }),
                ),
                if (draft) ...[
                  ManagedTextField(
                    key: const ValueKey('supplier-preparation-barcode'),
                    controller: _barcode,
                    enabled: !_busy,
                    retainFocusOnSubmit: true,
                    decoration: InputDecoration(
                      labelText: tr(context, 'm53ReceiptDraftCode'),
                    ),
                    onSubmitted: _scanText,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _scanText(_barcode.text),
                        child: Text(tr(context, 'm53ReceiptDraftAddCode')),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _scanCamera,
                        child: Text(tr(context, 'm53CameraScan')),
                      ),
                      OutlinedButton(
                        key: const ValueKey('supplier-preparation-search'),
                        onPressed: _busy ? null : () => _run(_select),
                        child: Text(tr(context, 'searchProducts')),
                      ),
                    ],
                  ),
                  Text(tr(context, 'm54PrepPhysicalHelp')),
                ],
                for (final line in doc.lines.where(
                  (line) => line.remaining > 0,
                ))
                  Card(
                    child: ListTile(
                      title: Text(line.name),
                      subtitle: Text(
                        [
                          '${line.remaining} ${line.unit} · ${tr(context, _bucketLabel(line.bucket))}',
                          tr(
                            context,
                            line.receiptItem == null
                                ? 'm54PrepUnknownOrigin'
                                : 'm54PrepReceiptOrigin',
                          ),
                          '${tr(context, switch (line.referenceBasis) {
                            'receipt' => 'm54PrepCostReceipt',
                            'return_hpp' => 'm54PrepCostReturn',
                            'average' => 'm54PrepCostAverage',
                            'reference' => 'm54PrepCostReference',
                            _ => 'm54PrepCostUnknown',
                          })}${line.referenceCostMicros == null ? '' : ' · ${moneyCostLabel(context, line.referenceCostMicros, currency: doc.currency)}'}',
                          if ((line.row['note'] as String).isNotEmpty)
                            line.row['note'] as String,
                        ].join('\n'),
                      ),
                      onTap: _busy || !draft ? null : () => _edit(line),
                      trailing: draft
                          ? IconButton(
                              tooltip: tr(context, 'delete'),
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                      () => _setQuantity(line, doc.revision, 0),
                                    ),
                            )
                          : null,
                    ),
                  ),
                if (draft) ...[
                  FilledButton(
                    key: const ValueKey('supplier-preparation-dispatch'),
                    onPressed:
                        _busy || doc.lines.every((line) => line.remaining == 0)
                        ? null
                        : _dispatch,
                    child: Text(tr(context, 'm54PrepDispatch')),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _cancel,
                    child: Text(tr(context, 'm53ReturnCancel')),
                  ),
                ],
                for (final fact in _dispatches)
                  Card(
                    child: ListTile(
                      title: Text(
                        '${tr(context, 'm54PrepDispatched')} · ${fact['quantity']}',
                      ),
                      subtitle: Text(
                        [
                          if (fact['reason'] != '') fact['reason'] as String,
                          if (fact['credit_claim_minor'] case final int claim)
                            '${tr(context, 'm54PrepCreditClaim')} · ${moneyLabel(context, claim, currency: doc.currency)}',
                          if (fact['reversed'] == 1)
                            tr(context, 'm53ReturnReversed'),
                        ].join('\n'),
                      ),
                      trailing: fact['reversed'] == 1
                          ? null
                          : IconButton(
                              tooltip: tr(context, 'm53ReturnUndo'),
                              icon: const Icon(Icons.undo),
                              onPressed: _busy
                                  ? null
                                  : () => _reverse(
                                      EntityId(fact['id'] as String),
                                    ),
                            ),
                    ),
                  ),
                if (_next != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            final page = await _app.inventory
                                .supplierPreparationDispatches(
                                  doc.id,
                                  after: _next,
                                );
                            if (!mounted) return;
                            _requireCurrent();
                            setState(() {
                              _dispatches = page.items;
                              _next = page.nextCursor;
                            });
                          }),
                    child: Text(tr(context, 'm3LoadMore')),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
