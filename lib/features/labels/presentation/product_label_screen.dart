import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../management/presentation/management_gate.dart';
import '../../printer/domain/printer_profile.dart';
import '../../printer/presentation/printer_settings_screen.dart';
import '../../settings/presentation/language_button.dart';
import '../application/product_label_service.dart';
import '../application/qr_label_layout.dart';
import '../domain/product_label.dart';

/// Per-product label flow owns its temporary form and preview. Business facts,
/// authorization, profile CAS and durable output live in the feature services.
class ProductLabelScreen extends StatefulWidget {
  const ProductLabelScreen({super.key, required this.product});
  final EntityId product;
  @override
  State<ProductLabelScreen> createState() => _ProductLabelScreenState();
}

class _ProductLabelScreenState extends State<ProductLabelScreen> {
  final inputs = <String, TextEditingController>{
    for (final entry in {
      'widthMm': 40,
      'heightMm': 40,
      'gapMm': 2,
      'offsetXmm': 0,
      'offsetYmm': 0,
      'moduleDots': 4,
      'feed': 3,
      'copies': 1,
    }.entries)
      entry.key: TextEditingController(text: '${entry.value}'),
  };
  List<ProductLabelPrinter> printers = [];
  ProductLabelPrinter? selected;
  List<ProductLabelPrinter> get choices =>
      selected == null || printers.any((p) => p.id == selected!.id)
      ? printers
      : [...printers, selected!];
  ProductLabelSnapshot? snapshot;
  PrinterProtocol protocol = PrinterProtocol.escPosRaster;
  bool gap = false,
      acknowledged = false,
      price = false,
      busy = false,
      started = false,
      hasMore = false;
  String? error, status, job;
  String baseline = '', operation = const IdGenerator().next().value;
  ui.Image? preview;
  double? totalMm;
  String values() => jsonEncode([
    for (final c in inputs.values) c.text,
    protocol.name,
    gap,
    acknowledged,
    price,
    selected?.id,
  ]);
  bool get dirty => baseline.isNotEmpty && values() != baseline;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      load();
    }
  }

  @override
  void dispose() {
    for (final c in inputs.values) {
      c.dispose();
    }
    preview?.dispose();
    super.dispose();
  }

  ProductLabelProfile media() {
    if (inputs.entries
        .where((e) => e.key != 'copies')
        .any((e) => int.tryParse(e.value.text) == null)) {
      throw const FormatException('m53LabelProfileInvalid');
    }
    return ProductLabelProfile.fromJson({
      'format': 1,
      'protocol': protocol.name,
      'gap': gap,
      'gapConfirmed': acknowledged,
      'price': price,
      for (final e in inputs.entries.where((e) => e.key != 'copies'))
        e.key: int.tryParse(e.value.text),
    });
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = switch (e) {
            FormatException(message: final String key)
                when const {
                  'm53LabelProfileInvalid',
                  'm53LabelGapUnsupported',
                  'm53LabelWidthExceeded',
                  'm53LabelDoesNotFit',
                  'm53LabelPrinterMissing',
                  'm53LabelSnapshotInvalid',
                  'm53LabelIdentityInvalid',
                }.contains(key) =>
              key,
            _ => safeError(e),
          },
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void changed() {
    preview?.dispose();
    preview = null;
    totalMm = null;
    setState(() {});
  }

  void select(ProductLabelPrinter printer) {
    final m = printer.media;
    selected = printer;
    protocol = m.protocol;
    gap = m.gap;
    acknowledged = m.gapConfirmed;
    price = m.price;
    final json = m.toJson();
    for (final e in inputs.entries) {
      e.value.text = e.key == 'copies' ? '1' : '${json[e.key]}';
    }
    baseline = values();
    changed();
  }

  Future<void> load({bool preserveForm = false}) => run(() async {
    final app = context.read<AppServices>();
    final previous = preserveForm ? selected : null;
    final language = Localizations.localeOf(context).languageCode;
    final list = await app.labels.printers();
    final value = previous != null && snapshot != null
        ? snapshot!
        : await app.labels.snapshot(widget.product, language: language);
    ProductLabelPrinter? replacement;
    if (previous != null) {
      try {
        final fresh = await app.labels.printer(previous.id);
        // Keep the original label CAS and unsaved form while refreshing only
        // peripheral geometry. A concurrent label save must remain a conflict.
        replacement = ProductLabelPrinter(
          fresh.id,
          fresh.name,
          fresh.hardware,
          previous.media,
          previous.revision,
        );
      } on AppError catch (e) {
        if (e.message != 'm53LabelPrinterMissing') {
          rethrow;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      printers = list;
      snapshot = value;
      hasMore = list.length == 20;
      if (previous != null) {
        selected = replacement;
        if (replacement == null) error = 'm53LabelPrinterMissing';
      }
    });
    if (previous != null) {
      changed();
    } else if (list.isNotEmpty) {
      select(list.first);
    }
  });
  Future<void> more() => run(() async {
    final list = await context.read<AppServices>().labels.printers(
      after: printers.last.id,
    );
    if (mounted) {
      setState(() {
        printers = [...printers, ...list];
        hasMore = list.length == 20;
      });
    }
  });
  Future<void> render() => run(() async {
    final app = context.read<AppServices>(), p = selected;
    final grant = app.management.generation, store = app.database.generation;
    if (p == null) throw const FormatException('m53LabelPrinterMissing');
    final hardware = (await app.labels.printer(p.id)).hardware;
    if (!mounted) return;
    final value = await app.labels.snapshot(
      widget.product,
      language: Localizations.localeOf(context).languageCode,
    );
    final layout = QrLabelLayout(value, media(), hardware);
    final image = await layout.image();
    if (!mounted ||
        !app.management.isUnlocked ||
        grant != app.management.generation ||
        store != app.database.generation) {
      image.dispose();
      return;
    }
    preview?.dispose();
    setState(() {
      snapshot = value;
      preview = image;
      totalMm = layout.totalMediaMm;
    });
  });
  Future<void> save() => run(() async {
    final p = selected;
    if (p == null) throw const FormatException('m53LabelPrinterMissing');
    final app = context.read<AppServices>();
    await app.labels.saveProfile(p.id, media(), p.revision);
    final value = await app.labels.printer(p.id);
    if (mounted) {
      selected = value;
      baseline = values();
    }
  });
  Future<void> print() => run(() async {
    final app = context.read<AppServices>(), p = selected, s = snapshot;
    if (p == null || s == null) {
      throw const FormatException('m53LabelPrinterMissing');
    }
    job ??= await app.labels.prepare(
      widget.product,
      s.productRevision,
      p.id,
      media(),
      int.tryParse(inputs['copies']!.text) ?? 0,
      operationKey: operation,
      language: Localizations.localeOf(context).languageCode,
    );
    final result = await app.printing.send(job!);
    if (mounted) {
      setState(
        () => status = result == 'submitted'
            ? 'm5DataSent'
            : result == 'unknown'
            ? 'm5DeliveryUnknown'
            : 'm5NotSent',
      );
    }
  });
  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: FormExitGuard(
      capability: ManagementCapability.inventory,
      dirty: dirty,
      dirtyCheck: () => dirty,
      busy: busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'm53Labels')),
          actions: const [LanguageButton()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(tr(context, error!), key: const ValueKey('label-error')),
              if (snapshot != null) Text(snapshot!.name),
              Text(tr(context, 'm53LabelHelp')),
              if (printers.isEmpty) Text(tr(context, 'm53LabelPrinterMissing')),
              OutlinedButton(
                key: const ValueKey('label-printer-settings'),
                onPressed: busy || job != null
                    ? null
                    : () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) =>
                                const PrinterSettingsScreen(publicAccess: true),
                          ),
                        );
                        if (mounted) await load(preserveForm: true);
                      },
                child: Text(tr(context, 'm53LabelPrinterSettings')),
              ),
              if (printers.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey('label-printer-${selected?.id}'),
                  initialValue: selected?.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: tr(context, 'm53LabelPrinter'),
                  ),
                  items: [
                    for (final p in choices)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: busy || job != null
                      ? null
                      : (id) => select(choices.firstWhere((p) => p.id == id)),
                ),
              if (printers.isNotEmpty && hasMore)
                TextButton(
                  onPressed: busy ? null : more,
                  child: Text(tr(context, 'loadMore')),
                ),
              DropdownButtonFormField<PrinterProtocol>(
                initialValue: protocol,
                key: ValueKey('label-protocol-${selected?.id}'),
                decoration: InputDecoration(
                  labelText: tr(context, 'm53LabelProtocol'),
                ),
                isExpanded: true,
                items: [
                  for (final p in PrinterProtocol.values)
                    DropdownMenuItem(
                      value: p,
                      child: Text(
                        tr(context, switch (p) {
                          PrinterProtocol.escPosRaster => 'm5ProtocolRaster',
                          PrinterProtocol.escPosColumn => 'm5ProtocolColumn',
                          PrinterProtocol.tspl => 'm53LabelTspl',
                          PrinterProtocol.cpcl => 'm5ProtocolCpcl',
                        }),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: busy || job != null
                    ? null
                    : (p) {
                        protocol = p!;
                        changed();
                      },
              ),
              for (final e in inputs.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ManagedTextField(
                    key: ValueKey('label-${e.key}'),
                    controller: e.value,
                    enabled: !busy && job == null,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 3,
                    decoration: InputDecoration(
                      labelText: tr(context, 'm53Label${e.key}'),
                    ),
                    onChanged: (_) => changed(),
                  ),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr(context, 'm53LabelPrice')),
                value: price,
                onChanged: busy || job != null
                    ? null
                    : (v) {
                        price = v!;
                        changed();
                      },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr(context, 'm53LabelGap')),
                value: gap,
                onChanged: busy || job != null
                    ? null
                    : (v) {
                        gap = v!;
                        changed();
                      },
              ),
              if (gap)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(context, 'm53LabelGapAck')),
                  value: acknowledged,
                  onChanged: busy || job != null
                      ? null
                      : (v) {
                          acknowledged = v!;
                          changed();
                        },
                ),
              Text(tr(context, 'm53LabelMediaHelp')),
              OutlinedButton(
                key: const ValueKey('label-save'),
                onPressed: busy || selected == null || job != null
                    ? null
                    : save,
                child: Text(tr(context, 'm53LabelSaveProfile')),
              ),
              OutlinedButton(
                key: const ValueKey('label-preview'),
                onPressed: busy || selected == null || job != null
                    ? null
                    : render,
                child: Text(tr(context, 'm53LabelPreview')),
              ),
              if (preview != null) ...[
                Text(
                  '${tr(context, 'm53Labelcopies')}: ${inputs['copies']!.text}\n${inputs['widthMm']!.text} × ${inputs['heightMm']!.text} mm; ${tr(context, 'm53LabelTotalMedia')}: $totalMm mm',
                ),
                Center(
                  child: RawImage(
                    image: preview,
                    scale: 1,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ],
              FilledButton(
                key: const ValueKey('label-print'),
                onPressed: busy || selected == null || status != null
                    ? null
                    : print,
                child: Text(
                  tr(context, job == null ? 'm53LabelPrint' : 'm53LabelResume'),
                ),
              ),
              if (status != null) ...[
                Text(tr(context, status!)),
                Text(tr(context, 'm53LabelPaperWarning')),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () {
                          setState(() {
                            job = null;
                            status = null;
                            operation = const IdGenerator().next().value;
                          });
                        },
                  child: Text(tr(context, 'm53LabelNewJob')),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
