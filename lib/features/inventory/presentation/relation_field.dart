import 'package:kasir_app/l10n/localization.dart';
import '../../management/presentation/managed_text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../domain/inventory_models.dart';
import 'master_list.dart';
import 'shelves_screen.dart';

/// Bounded dropdown: RawAutocomplete owns transient options, parent owns the
/// selected relation ID. No table is loaded into widget state.
class RelationField extends StatefulWidget {
  const RelationField({
    super.key,
    required this.kind,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final MasterKind kind;
  final MasterRecord? value;
  final ValueChanged<MasterRecord?> onChanged;
  final bool enabled;
  @override
  State<RelationField> createState() => _RelationFieldState();
}

class _RelationFieldState extends State<RelationField> {
  late final TextEditingController _controller;
  final _focus = FocusNode();
  int _generation = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.name);
  }

  @override
  void didUpdateWidget(RelationField old) {
    super.didUpdateWidget(old);
    if (widget.value != null && widget.value?.id != old.value?.id) {
      _controller.text = widget.value!.name;
    }
  }

  @override
  void dispose() {
    _generation++;
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RawAutocomplete<MasterRecord>(
        textEditingController: _controller,
        focusNode: _focus,
        displayStringForOption: (option) => option.name,
        optionsBuilder: (query) async {
          final generation = ++_generation;
          try {
            final page = await context.read<AppServices>().inventory.masterPage(
              widget.kind,
              query.text,
              null,
              pageSize: 20,
            );
            if (mounted && generation == _generation && _error != null) {
              setState(() => _error = null);
            }
            return page.items;
          } catch (error) {
            if (mounted && generation == _generation) {
              setState(() => _error = safeError(error));
            }
            return <MasterRecord>[];
          }
        },
        onSelected: (record) => widget.onChanged(record),
        optionsViewBuilder: (context, choose, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 200,
                maxWidth: (MediaQuery.sizeOf(context).width - 80)
                    .clamp(120, 320)
                    .toDouble(),
              ),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final record in options)
                    ListTile(
                      title: Text(record.name),
                      onTap: () => choose(record),
                    ),
                ],
              ),
            ),
          ),
        ),
        fieldViewBuilder: (context, controller, focus, onSubmit) =>
            ManagedTextField(
              controller: controller,
              focusNode: focus,
              enabled: widget.enabled,
              decoration: InputDecoration(
                labelText: tr(context, switch (widget.kind) {
                  MasterKind.category => 'categoryOptional',
                  MasterKind.supplier => 'supplierOptional',
                  MasterKind.shelf => 'm52Shelf',
                }),
                hintText: tr(context, 'typeANamePrefixThenSelect'),
                helperText: widget.value == null
                    ? (widget.kind == MasterKind.category
                          ? tr(context, 'uncategorized')
                          : widget.kind == MasterKind.supplier
                          ? tr(context, 'noSupplier')
                          : '—')
                    : null,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: tr(context, 'clearSelection'),
                  onPressed: widget.enabled
                      ? () {
                          controller.clear();
                          widget.onChanged(null);
                        }
                      : null,
                  icon: const Icon(Icons.clear),
                ),
              ),
              onChanged: (text) {
                if (widget.value != null && text != widget.value!.name) {
                  widget.onChanged(null);
                }
              },
              onSubmitted: (_) => onSubmit(),
            ),
      ),
      if (_error != null) Text(message(context, _error!)),
      TextButton.icon(
        onPressed: widget.enabled
            ? () async {
                final result = widget.kind == MasterKind.shelf
                    ? await Navigator.push<MasterRecord>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShelvesScreen(
                            prefill: _controller.text,
                            picker: true,
                          ),
                        ),
                      )
                    : await pickMaster(context, widget.kind);
                _generation++;
                if (result != null && mounted) widget.onChanged(result);
              }
            : null,
        icon: const Icon(Icons.add),
        label: Text(
          widget.kind == MasterKind.category
              ? tr(context, 'searchOrAddCategory')
              : widget.kind == MasterKind.supplier
              ? tr(context, 'searchOrAddSupplier')
              : tr(context, 'm52Shelves'),
        ),
      ),
    ],
  );
}
