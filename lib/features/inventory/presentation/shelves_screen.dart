import '../../management/domain/management_role.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/pagination/paged_controller.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../management/presentation/protected_dialog.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/inventory_models.dart';

/// Inline repeated quick-add plus bounded stable-ID list. Returning to a product
/// leaves that route's draft/controllers intact; selection is an explicit tap.
class ShelvesScreen extends StatefulWidget {
  const ShelvesScreen({super.key, this.prefill = '', this.picker = false});
  final String prefill;
  final bool picker;
  @override
  State<ShelvesScreen> createState() => _ShelvesScreenState();
}

class _ShelvesScreenState extends State<ShelvesScreen> {
  late final name = TextEditingController(text: widget.prefill);
  final focus = FocusNode();
  PagedController<MasterRecord, MasterCursor, String>? paging;
  bool busy = false;
  String? error;
  late String baseline = widget.prefill;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    paging ??= PagedController(
      filter: '',
      load: (prefix, cursor) => context
          .read<AppServices>()
          .inventory
          .masterPage(MasterKind.shelf, prefix, cursor),
    )..loadMore();
  }

  @override
  void dispose() {
    name.dispose();
    focus.dispose();
    paging?.dispose();
    super.dispose();
  }

  Future<void> add() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await context.read<AppServices>().inventory.saveMaster(
        MasterKind.shelf,
        name.text,
      );
      if (!mounted) return;
      name.clear();
      baseline = '';
      await paging!.reset(paging!.filter);
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        focus.requestFocus();
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit(MasterRecord record) async {
    final text = TextEditingController(text: record.name);
    String? failure;
    bool saving = false;
    final service = context.read<AppServices>().inventory;
    await showManagedDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (_, update) => ProtectedDialog(
          capability: ManagementCapability.inventory,
          child: AlertDialog(
            title: Text(tr(dialog, 'editRecord')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ManagedTextField(
                  controller: text,
                  enabled: !saving,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: tr(dialog, 'm52ShelfName'),
                  ),
                ),
                if (failure != null) Text(message(dialog, failure!)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialog),
                child: Text(tr(dialog, 'cancel')),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        update(() => saving = true);
                        try {
                          await service.saveMaster(
                            MasterKind.shelf,
                            text.text,
                            id: record.id,
                          );
                          if (dialog.mounted) Navigator.pop(dialog);
                        } catch (e) {
                          if (dialog.mounted) {
                            update(() => failure = safeError(e));
                          }
                        } finally {
                          if (dialog.mounted) update(() => saving = false);
                        }
                      },
                child: Text(tr(dialog, 'save')),
              ),
            ],
          ),
        ),
      ),
    );
    text.dispose();
    if (mounted) await paging!.reset(paging!.filter);
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: ListenableBuilder(
      listenable: Listenable.merge([name, paging!]),
      builder: (context, _) => FormExitGuard(
        capability: ManagementCapability.inventory,
        dirty: name.text != baseline,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'm52Shelves')),
            actions: const [LanguageButton()],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ManagedTextField(
                        controller: name,
                        focusNode: focus,
                        enabled: !busy,
                        maxLength: 80,
                        onSubmitted: (_) => add(),
                        decoration: InputDecoration(
                          labelText: tr(context, 'm52ShelfName'),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: tr(context, 'add'),
                      onPressed: busy || name.text.trim().isEmpty ? null : add,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                if (error != null) Text(message(context, error!)),
                ManagedTextField(
                  onChanged: (text) => paging!.reset(text),
                  decoration: InputDecoration(
                    labelText: tr(context, 'searchNamePrefix'),
                  ),
                ),
                if (busy || paging!.isLoading) const LinearProgressIndicator(),
                if (paging!.error != null)
                  Text(message(context, paging!.error!)),
                for (final row in paging!.items)
                  ListTile(
                    title: Text(row.name),
                    onTap: busy
                        ? null
                        : widget.picker
                        ? () => Navigator.pop(context, row)
                        : () => edit(row),
                    trailing: IconButton(
                      tooltip: tr(context, 'editRecord'),
                      icon: const Icon(Icons.edit),
                      onPressed: busy ? null : () => edit(row),
                    ),
                  ),
                if (paging!.hasMore)
                  TextButton(
                    onPressed: paging!.isLoading ? null : paging!.loadMore,
                    child: Text(tr(context, 'loadMore')),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
