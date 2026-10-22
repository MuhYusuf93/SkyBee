import 'package:kasir_app/l10n/localized_notice.dart';
import 'package:kasir_app/features/settings/presentation/language_button.dart';
import 'package:kasir_app/l10n/localization.dart';
import '../../management/presentation/managed_text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/contact_validation.dart';
import '../../../core/presentation/contact_output_link.dart';
import '../../../core/pagination/paged_controller.dart';
import '../domain/inventory_models.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/protected_dialog.dart';

typedef MasterFilter = ({MasterKind kind, String prefix, bool archived});

/// Reused list and relationship picker, always keyset/bounded. Add quick is the
/// same protected service as the full master form, never a dummy supplier.
/// Headers scroll with lazy rows so keyboard/large text cannot starve the list
/// of vertical space, including while an editor dialog covers this route.
class MasterList extends StatelessWidget {
  const MasterList({super.key, required this.kind, this.picker = false});
  final MasterKind kind;
  final bool picker;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => PagedController<MasterRecord, MasterCursor, MasterFilter>(
      filter: (kind: kind, prefix: '', archived: false),
      load: (filter, after) => context.read<AppServices>().inventory.masterPage(
        filter.kind,
        filter.prefix,
        after,
        isDeleted: filter.archived,
        pageSize: picker ? 20 : 50,
      ),
    )..loadMore(),
    child: _MasterBody(kind: kind, picker: picker),
  );
}

class _MasterBody extends StatelessWidget {
  const _MasterBody({required this.kind, required this.picker});
  final MasterKind kind;
  final bool picker;
  Future<void> _edit(BuildContext context, {MasterRecord? record}) async {
    final name = TextEditingController(text: record?.name),
        contact = TextEditingController(text: record?.contact),
        email = TextEditingController(text: record?.email),
        website = TextEditingController(text: record?.website);
    final paging = context
        .read<PagedController<MasterRecord, MasterCursor, MasterFilter>>();
    String? error;
    final routeContext = context;
    bool busy = false;
    final services = context.read<AppServices>();
    final region = await services.settings.phoneRegion();
    String? invalid(String key) {
      if (kind != MasterKind.supplier) return null;
      try {
        switch (key) {
          case 'phone':
            ContactValidation.phone(contact.text, region: region);
          case 'email':
            ContactValidation.email(email.text);
          case 'website':
            ContactValidation.website(website.text);
        }
        return null;
      } catch (e) {
        return safeError(e);
      }
    }

    if (!context.mounted) {
      for (final c in [name, contact, email, website]) {
        c.dispose();
      }
      return;
    }
    await showManagedDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => ProtectedDialog(
          child: AlertDialog(
            title: Text(
              record == null
                  ? tr(
                      context,
                      kind == MasterKind.category
                          ? 'addCategory'
                          : 'addSupplier',
                    )
                  : tr(context, 'editRecord'),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ManagedTextField(
                    controller: name,
                    enabled: !busy,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: tr(context, 'name')),
                  ),
                  if (kind == MasterKind.supplier)
                    ManagedTextField(
                      controller: contact,
                      enabled: !busy,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: tr(context, 'contactNumberOptional'),
                        errorText: invalid('phone') == null
                            ? null
                            : tr(context, invalid('phone')!),
                      ),
                    ),
                  if (kind == MasterKind.supplier) ...[
                    ManagedTextField(
                      controller: email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: tr(context, 'm52Email'),
                        errorText: invalid('email') == null
                            ? null
                            : tr(context, invalid('email')!),
                      ),
                    ),
                    ManagedTextField(
                      controller: website,
                      enabled: !busy,
                      keyboardType: TextInputType.url,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: tr(context, 'm52Website'),
                        helperText: 'example.com → https://example.com',
                        errorText: invalid('website') == null
                            ? null
                            : tr(context, invalid('website')!),
                      ),
                    ),
                  ],
                  if (error != null) Text(message(context, error!)),
                ],
              ),
            ),
            actions: [
              const LanguageButton(),
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: Text(tr(context, 'cancel')),
              ),
              FilledButton(
                onPressed:
                    busy ||
                        name.text.trim().isEmpty ||
                        [
                          'phone',
                          'email',
                          'website',
                        ].any((key) => invalid(key) != null)
                    ? null
                    : () async {
                        setState(() => busy = true);
                        final enteredName = name.text;
                        final enteredContact = contact.text;
                        try {
                          final id = await services.inventory.saveMaster(
                            kind,
                            enteredName,
                            contact: enteredContact,
                            email: email.text,
                            website: website.text,
                            id: record?.id,
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (picker && routeContext.mounted) {
                            Navigator.pop(
                              routeContext,
                              MasterRecord(
                                id: id,
                                name: enteredName.trim(),
                                contact: enteredContact.trim(),
                              ),
                            );
                          } else {
                            await paging.reset(paging.filter);
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            setState(() => error = safeError(e));
                          }
                        } finally {
                          if (dialogContext.mounted) {
                            setState(() => busy = false);
                          }
                        }
                      },
                child: Text(tr(context, 'save')),
              ),
            ],
          ),
        ),
      ),
    );
    name.dispose();
    contact.dispose();
    email.dispose();
    website.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Consumer<PagedController<MasterRecord, MasterCursor, MasterFilter>>(
        builder: (context, state, _) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ManagedTextField(
                      decoration: InputDecoration(
                        labelText: tr(context, 'searchNamePrefix'),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (text) => state.reset((
                        kind: kind,
                        prefix: text,
                        archived: state.filter.archived,
                      )),
                    ),
                    if (!picker)
                      SwitchListTile(
                        title: Text(tr(context, 'showArchived')),
                        value: state.filter.archived,
                        onChanged: (value) => state.reset((
                          kind: kind,
                          prefix: state.filter.prefix,
                          archived: value,
                        )),
                      ),
                    FilledButton.icon(
                      onPressed: () => _edit(context),
                      icon: const Icon(Icons.add),
                      label: Text(
                        tr(
                          context,
                          kind == MasterKind.category
                              ? 'addCategory'
                              : 'addSupplier',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (state.isLoading)
              SliverToBoxAdapter(
                child: LinearProgressIndicator(
                  semanticsLabel: tr(context, 'loading'),
                ),
              ),
            if (state.error != null)
              SliverToBoxAdapter(child: Text(message(context, state.error!))),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index == state.items.length) {
                  return TextButton(
                    onPressed: state.isLoading ? null : state.loadMore,
                    child: Text(tr(context, 'loadMore')),
                  );
                }
                final record = state.items[index];
                return ListTile(
                  title: Text(record.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (record.contact != null)
                        ContactOutputLink.phone(
                          record.contact!,
                          managementProtected: true,
                        ),
                      if (record.email != null) Text(record.email!),
                      if (record.website != null)
                        ContactOutputLink.website(
                          record.website!,
                          managementProtected: true,
                        ),
                    ],
                  ),
                  onTap: picker
                      ? () => Navigator.pop(context, record)
                      : record.isDeleted
                      ? null
                      : () => _edit(context, record: record),
                  trailing: picker
                      ? null
                      : IconButton(
                          tooltip: record.isDeleted
                              ? tr(context, 'restore')
                              : tr(context, 'archive'),
                          icon: Icon(
                            record.isDeleted
                                ? Icons.restore
                                : Icons.archive_outlined,
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(
                                  record.isDeleted
                                      ? tr(context, 'restoreRecord')
                                      : tr(context, 'archiveRecord'),
                                ),
                                actions: [
                                  const LanguageButton(),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(tr(context, 'cancel')),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(tr(context, 'continueAction')),
                                  ),
                                ],
                              ),
                            );
                            if (confirm != true || !context.mounted) return;
                            try {
                              await context
                                  .read<AppServices>()
                                  .inventory
                                  .archiveMaster(
                                    kind,
                                    record.id,
                                    restore: record.isDeleted,
                                  );
                              await state.reset(state.filter);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: LocalizedNotice(
                                      messageKey: safeError(e),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                );
              }, childCount: state.items.length + (state.hasMore ? 1 : 0)),
            ),
            if (state.items.isEmpty && !state.isLoading && state.error == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(tr(context, 'noRecordsYet')),
                ),
              ),
          ],
        ),
      );
}

Future<MasterRecord?> pickMaster(BuildContext context, MasterKind kind) =>
    Navigator.push<MasterRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            actions: const [LanguageButton()],
            title: Text(
              kind == MasterKind.category
                  ? tr(context, 'selectCategory')
                  : tr(context, 'selectSupplier'),
            ),
          ),
          body: ManagementGate(child: MasterList(kind: kind, picker: true)),
        ),
      ),
    );
