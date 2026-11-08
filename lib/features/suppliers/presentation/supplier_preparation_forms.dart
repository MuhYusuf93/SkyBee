part of 'supplier_preparation_screen.dart';

typedef _SourceChoice = ({SupplierPreparationSource? source, String note});
typedef _DispatchChoice = ({
  Map<EntityId, int> quantities,
  String reason,
  bool rejectRemaining,
  Money? credit,
});

class _PreparationSourcePicker extends StatefulWidget {
  const _PreparationSourcePicker({
    required this.product,
    required this.quantity,
  });
  final InventoryProduct product;
  final int quantity;

  @override
  State<_PreparationSourcePicker> createState() =>
      _PreparationSourcePickerState();
}

class _PreparationSourcePickerState extends State<_PreparationSourcePicker> {
  final _note = TextEditingController();
  late SupplierReturnBucket _bucket = widget.product.stockTracked
      ? SupplierReturnBucket.batch
      : SupplierReturnBucket.quarantine;
  late final _paging =
      PagedController<
        SupplierPreparationSource,
        SupplierPreparationSourceCursor,
        SupplierReturnBucket
      >(
        filter: _bucket,
        load: (bucket, after) =>
            context.read<AppServices>().inventory.supplierPreparationSources(
              widget.product.id,
              bucket,
              after: after,
            ),
      );

  @override
  void initState() {
    super.initState();
    _paging.loadMore();
  }

  @override
  void dispose() {
    _paging.dispose();
    _note.dispose();
    super.dispose();
  }

  void _choose(SupplierPreparationSource? source) =>
      Navigator.pop(context, (source: source, note: _note.text));

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: _inventory,
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, 'm54PrepChooseSource'))),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _paging,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${widget.product.name} · ${widget.quantity} ${widget.product.baseUnit}',
              ),
              DropdownButtonFormField<SupplierReturnBucket>(
                key: const ValueKey('supplier-preparation-source-bucket'),
                initialValue: _bucket,
                isExpanded: true,
                items: [
                  for (final bucket in SupplierReturnBucket.values)
                    if (bucket != SupplierReturnBucket.observed ||
                        !widget.product.stockTracked)
                      DropdownMenuItem(
                        value: bucket,
                        child: Text(tr(context, _bucketLabel(bucket))),
                      ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _bucket = value);
                  _paging.reset(value);
                },
              ),
              ManagedTextField(
                controller: _note,
                maxLength: 300,
                decoration: InputDecoration(
                  labelText: tr(context, 'm54PrepReason'),
                ),
              ),
              if (_paging.isLoading) const LinearProgressIndicator(),
              if (_paging.error case final error?) Text(tr(context, error)),
              if (!_paging.isLoading && _paging.items.isEmpty)
                Text(tr(context, 'm53SupplierEmpty')),
              for (final source in _paging.items)
                Card(
                  child: ListTile(
                    key: ValueKey(
                      'supplier-preparation-source-${source.id.value}',
                    ),
                    title: Text(
                      '${tr(context, 'm53ReturnPhysicalAvailable')} · ${source.available}',
                    ),
                    subtitle: Text(
                      [
                        tr(
                          context,
                          source.receiptItem == null
                              ? 'm54PrepUnknownOrigin'
                              : 'm54PrepReceiptOrigin',
                        ),
                        ?source.originSupplier,
                        MaterialLocalizations.of(context).formatShortDate(
                          DateTime.fromMillisecondsSinceEpoch(
                            source.recordedAt,
                          ),
                        ),
                        ?source.label,
                      ].join(' · '),
                    ),
                    onTap: source.available < widget.quantity
                        ? null
                        : () => _choose(source),
                  ),
                ),
              if (_paging.hasMore && !_paging.isLoading)
                TextButton(
                  onPressed: _paging.loadMore,
                  child: Text(tr(context, 'm3LoadMore')),
                ),
              if (_bucket == SupplierReturnBucket.observed &&
                  !widget.product.stockTracked) ...[
                Text(tr(context, 'm54PrepObservationHelp')),
                FilledButton(
                  key: const ValueKey('supplier-preparation-observe'),
                  onPressed: () => _choose(null),
                  child: Text(tr(context, 'm54PrepObserve')),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _PreparationDispatchScreen extends StatefulWidget {
  const _PreparationDispatchScreen({required this.doc});
  final SupplierReturnPreparation doc;

  @override
  State<_PreparationDispatchScreen> createState() =>
      _PreparationDispatchScreenState();
}

class _PreparationDispatchScreenState
    extends State<_PreparationDispatchScreen> {
  final _reason = TextEditingController();
  final _credit = MoneyEditingController();
  late final _lines = widget.doc.lines
      .where((line) => line.remaining > 0)
      .toList();
  late final _counts = {
    for (final line in _lines) line.id: TextEditingController(),
  };
  bool _rejectRemaining = false;
  bool _confirming = false;
  String? _error;

  Future<void> _finish() async {
    if (_confirming) return;
    try {
      final quantities = <EntityId, int>{};
      for (final line in _lines) {
        final raw = _counts[line.id]!.text.trim();
        final count = raw.isEmpty ? 0 : parseWholeQuantity(raw);
        if (count > line.remaining) {
          throw const AppError('m53ReturnQuantityInvalid');
        }
        if (count > 0) quantities[line.id] = count;
      }
      if (quantities.isEmpty) throw const AppError('m53ReturnEmpty');
      final credit = _credit.text.trim().isEmpty
          ? null
          : _credit.parseMoney(finish: true);
      if (credit?.amountMinor == 0) {
        throw const AppError('m53SupplierInputInvalid');
      }
      setState(() {
        _confirming = true;
        _error = null;
      });
      final accepted = await confirmSupplierFact(
        context,
        [
          for (final line in _lines)
            if (quantities[line.id] case final int quantity)
              '${line.name} · $quantity ${line.unit}',
          tr(
            context,
            _rejectRemaining
                ? 'm54PrepRejectRemaining'
                : 'm54PrepRetainRemaining',
          ),
        ].join('\n'),
        capability: _inventory,
      );
      if (!mounted || !accepted) return;
      Navigator.pop(context, (
        quantities: quantities,
        reason: _reason.text,
        rejectRemaining: _rejectRemaining,
        credit: credit,
      ));
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? 'm53SupplierInputInvalid'
              : safeError(e),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _counts.values) {
      controller.dispose();
    }
    _reason.dispose();
    _credit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: _inventory,
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, 'm54PrepDispatch'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.doc.supplierName),
            Text(tr(context, 'm54PrepDispatchHelp')),
            TextButton(
              onPressed: _confirming
                  ? null
                  : () {
                      for (final line in _lines) {
                        _counts[line.id]!.text = '${line.remaining}';
                      }
                    },
              child: Text(tr(context, 'm54PrepAcceptAll')),
            ),
            if (_error case final error?) Text(tr(context, error)),
            for (final line in _lines)
              ManagedTextField(
                key: ValueKey('supplier-preparation-accepted-${line.id.value}'),
                controller: _counts[line.id],
                enabled: !_confirming,
                keyboardType: TextInputType.number,
                inputFormatters: const [WholeQuantityFormatter()],
                decoration: InputDecoration(
                  labelText: '${line.name} · ${line.remaining} ${line.unit}',
                ),
              ),
            SwitchListTile(
              title: Text(tr(context, 'm54PrepRejectRemaining')),
              value: _rejectRemaining,
              onChanged: _confirming
                  ? null
                  : (value) => setState(() => _rejectRemaining = value),
            ),
            MoneyField(
              key: const ValueKey('supplier-preparation-credit-claim'),
              controller: _credit,
              currency: widget.doc.currency,
              label: tr(context, 'm54PrepCreditClaim'),
              enabled: !_confirming,
            ),
            Text(tr(context, 'm53ReturnNoAutomaticCredit')),
            ManagedTextField(
              controller: _reason,
              maxLength: 300,
              enabled: !_confirming,
              decoration: InputDecoration(
                labelText: tr(context, 'm54PrepReason'),
              ),
            ),
            FilledButton(
              key: const ValueKey('supplier-preparation-dispatch-save'),
              onPressed: _confirming ? null : _finish,
              child: Text(tr(context, 'm54PrepDispatch')),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PreparationTextScreen extends StatefulWidget {
  const _PreparationTextScreen({
    required this.title,
    required this.label,
    this.initial = '',
    this.quantity = false,
    this.requiredText = false,
  });
  final String title, label, initial;
  final bool quantity, requiredText;

  @override
  State<_PreparationTextScreen> createState() => _PreparationTextScreenState();
}

class _PreparationTextScreenState extends State<_PreparationTextScreen> {
  late final _text = TextEditingController(text: widget.initial);
  String? _error;

  void _finish() {
    final value = _text.text.trim();
    try {
      if (widget.quantity) parseWholeQuantity(value);
      if (widget.requiredText && value.isEmpty) {
        throw const AppError('correctionReasonIsRequired');
      }
      Navigator.pop(context, value);
    } catch (e) {
      setState(() => _error = safeError(e));
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: _inventory,
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, widget.title))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ManagedTextField(
              controller: _text,
              maxLength: widget.quantity ? null : 300,
              keyboardType: widget.quantity ? TextInputType.number : null,
              inputFormatters: widget.quantity
                  ? const [WholeQuantityFormatter()]
                  : null,
              decoration: InputDecoration(
                labelText: widget.label,
                errorText: _error == null ? null : tr(context, _error!),
              ),
            ),
            FilledButton(onPressed: _finish, child: Text(tr(context, 'save'))),
          ],
        ),
      ),
    ),
  );
}
