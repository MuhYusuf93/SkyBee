import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../l10n/localization.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/fresh_authentication.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/management_session_provider.dart';
import '../../management/presentation/protected_dialog.dart';
import '../application/archive_purge_service.dart';

typedef VisibleArchive = ({EntityId id, String name});

bool archiveIdsMatch(
  List<VisibleArchive> visible,
  Iterable<EntityId> current,
) => listEquals(visible.map((row) => row.id).toList(), current.toList());

/// Selection is isolated to a snapshot of the records already loaded on the
/// originating archive screen. It never implicitly queries an entire filter.
class ArchiveSelectionButton extends StatelessWidget {
  const ArchiveSelectionButton({
    super.key,
    required this.service,
    required this.kind,
    required this.rows,
    required this.scopeIsCurrent,
    required this.reload,
  });

  final ArchivePurgeService service;
  final ArchivePurgeKind kind;
  final List<VisibleArchive> rows;
  final bool Function() scopeIsCurrent;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    final owner = context.select<ManagementSessionProvider, bool>(
      (state) => state.unlocked && state.service.role == ManagementRole.owner,
    );
    if (!owner) return const SizedBox.shrink();
    return OutlinedButton.icon(
      key: const ValueKey('archive-selection'),
      icon: const Icon(Icons.checklist),
      label: Text(tr(context, 'm54ArchiveSelect')),
      onPressed: rows.isEmpty
          ? null
          : () async {
              final deleted = await Navigator.of(context).push<int>(
                MaterialPageRoute(
                  builder: (_) => ManagementGate(
                    child: _ArchiveSelectionScreen(
                      service: service,
                      kind: kind,
                      rows: List.unmodifiable(rows),
                      scopeIsCurrent: scopeIsCurrent,
                    ),
                  ),
                ),
              );
              if (deleted == null || !context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${tr(context, 'm54ArchiveDeleted')} $deleted'),
                ),
              );
              await reload();
            },
    );
  }
}

class _ArchiveSelectionScreen extends StatefulWidget {
  const _ArchiveSelectionScreen({
    required this.service,
    required this.kind,
    required this.rows,
    required this.scopeIsCurrent,
  });

  final ArchivePurgeService service;
  final ArchivePurgeKind kind;
  final List<VisibleArchive> rows;
  final bool Function() scopeIsCurrent;

  @override
  State<_ArchiveSelectionScreen> createState() =>
      _ArchiveSelectionScreenState();
}

class _ArchiveSelectionScreenState extends State<_ArchiveSelectionScreen> {
  final selected = <EntityId>{};
  bool busy = false;
  String? error;

  void _requireScope() {
    if (!mounted || !widget.scopeIsCurrent()) {
      throw const AppError('m54ArchiveScopeChanged');
    }
  }

  Future<void> _review() async {
    if (busy || selected.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    final service = widget.service;
    try {
      _requireScope();
      final plan = await service.preview(widget.kind, [
        for (final row in widget.rows)
          if (selected.contains(row.id)) row.id,
      ]);
      if (!mounted) return;
      _requireScope();
      final confirmed = await showManagedDialog<bool>(
        context: context,
        builder: (_) => ProtectedDialog(
          child: _PurgeReview(
            plan: plan,
            names: {for (final row in widget.rows) row.id: row.name},
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
      _requireScope();
      if (!await freshAuthentication(
        context,
        ArchivePurgeService.ownerPurpose,
        pinOnly: true,
      )) {
        return;
      }
      try {
        _requireScope();
        final proof = service.access.claimFresh(
          ArchivePurgeService.ownerPurpose,
        );
        final deleted = await service.purge(
          plan,
          proof,
          requireIntent: _requireScope,
        );
        if (mounted) Navigator.of(context).pop(deleted);
      } finally {
        service.access.clearFresh(ArchivePurgeService.ownerPurpose);
      }
    } on Object catch (failure) {
      if (mounted) setState(() => error = safeError(failure));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = selected.length == widget.rows.length;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'm54ArchiveSelect'))),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  CheckboxListTile(
                    key: const ValueKey('archive-select-loaded'),
                    tristate: true,
                    value: all ? true : (selected.isEmpty ? false : null),
                    onChanged: busy
                        ? null
                        : (_) {
                            setState(() {
                              selected.clear();
                              if (!all) {
                                selected.addAll(
                                  widget.rows.map((row) => row.id),
                                );
                              }
                            });
                          },
                    title: Text(tr(context, 'm54ArchiveSelectLoaded')),
                    subtitle: Text(
                      '${tr(context, 'm54ArchiveSelected')} ${selected.length}/${widget.rows.length}',
                    ),
                  ),
                  if (busy)
                    LinearProgressIndicator(
                      semanticsLabel: tr(context, 'loading'),
                    ),
                  if (error != null) Text(tr(context, error!)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton(
                      onPressed: busy || selected.isEmpty ? null : _review,
                      child: Text(tr(context, 'm54ArchiveReview')),
                    ),
                  ),
                ],
              ),
            ),
            SliverList.builder(
              itemCount: widget.rows.length,
              itemBuilder: (context, index) {
                final row = widget.rows[index];
                return CheckboxListTile(
                  key: ValueKey('archive-check-${row.id.value}'),
                  title: Text(row.name),
                  value: selected.contains(row.id),
                  onChanged: busy
                      ? null
                      : (value) {
                          setState(() {
                            if (value == true) {
                              selected.add(row.id);
                            } else {
                              selected.remove(row.id);
                            }
                          });
                        },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PurgeReview extends StatelessWidget {
  const _PurgeReview({required this.plan, required this.names});

  final ArchivePurgePlan plan;
  final Map<EntityId, String> names;

  @override
  Widget build(BuildContext context) {
    final eligible = plan.eligible.toList();
    return AlertDialog(
      scrollable: true,
      title: Text(tr(context, 'm54ArchiveDeleteForever')),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tr(context, 'm54ArchiveIrreversible')),
          const SizedBox(height: 12),
          Text('${tr(context, 'm54ArchiveEligible')} ${eligible.length}'),
          for (final entry in eligible) Text(entry.name!),
          const SizedBox(height: 12),
          Text(
            '${tr(context, 'm54ArchiveProtected')} ${plan.entries.length - eligible.length}',
          ),
          for (final entry in plan.entries)
            if (entry.blocker case final blocker?) ...[
              Text(entry.name ?? names[entry.id]!),
              Text(
                tr(context, switch (blocker) {
                  ArchivePurgeBlocker.changed => 'm54ArchiveScopeChanged',
                  ArchivePurgeBlocker.stockOrValue => 'm54ArchiveStockOrValue',
                  ArchivePurgeBlocker.reference => 'm54ArchiveReference',
                }),
              ),
            ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr(context, 'cancel')),
        ),
        FilledButton(
          onPressed: eligible.isEmpty
              ? null
              : () => Navigator.pop(context, true),
          child: Text(tr(context, 'm54ArchiveDeleteForever')),
        ),
      ],
    );
  }
}
