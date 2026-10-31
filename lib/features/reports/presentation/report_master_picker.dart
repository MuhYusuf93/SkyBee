import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/pagination/paged_controller.dart';
import '../../../l10n/localization.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/domain/management_role.dart';
import '../../settings/presentation/language_button.dart';

typedef _MasterFilter = ({String prefix, bool archived});

/// Reports may select archived suppliers with outstanding debt. This read-only
/// route reuses the inventory service's bounded keyset API, without exposing the
/// product form's optional-relation semantics or master editing actions.
class ReportMasterPicker extends StatefulWidget {
  const ReportMasterPicker({super.key, required this.kind});
  final MasterKind kind;
  @override
  State<ReportMasterPicker> createState() => _ReportMasterPickerState();
}

class _ReportMasterPickerState extends State<ReportMasterPicker> {
  late final PagedController<MasterRecord, MasterCursor, _MasterFilter> pager;
  Timer? debounce;
  final search = TextEditingController();
  @override
  void initState() {
    super.initState();
    final service = context.read<AppServices>().inventory;
    pager =
        PagedController(
            filter: (prefix: '', archived: false),
            maxCachedPages: 2,
            load: (f, after) => service.masterPage(
              widget.kind,
              f.prefix,
              after,
              isDeleted: f.archived,
              pageSize: 20,
            ),
          )
          ..addListener(changed)
          ..loadMore();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          tr(
            context,
            widget.kind == MasterKind.category
                ? 'selectCategory'
                : 'selectSupplier',
          ),
        ),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: search,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: tr(context, 'searchNamePrefix'),
              ),
              onChanged: (value) {
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 200), () {
                  final access = context.read<AppServices>().management;
                  if (mounted &&
                      access.isUnlocked &&
                      access.role == ManagementRole.owner) {
                    unawaited(
                      pager.reset((
                        prefix: value,
                        archived: pager.filter.archived,
                      )),
                    );
                  }
                });
              },
            ),
            SwitchListTile(
              key: const ValueKey('report-master-archived'),
              title: Text(tr(context, 'showArchived')),
              value: pager.filter.archived,
              onChanged: (value) {
                debounce?.cancel();
                unawaited(pager.reset((prefix: search.text, archived: value)));
              },
            ),
            if (pager.isLoading) const LinearProgressIndicator(),
            if (pager.error != null) Text(tr(context, pager.error!)),
            for (final record in pager.items)
              ListTile(
                title: Text(record.name),
                subtitle: Text(record.id.value),
                onTap: () => Navigator.of(context).pop(record),
              ),
            if (pager.hasMore)
              TextButton(
                onPressed: pager.isLoading ? null : pager.loadMore,
                child: Text(tr(context, 'loadMore')),
              ),
          ],
        ),
      ),
    ),
  );
}
