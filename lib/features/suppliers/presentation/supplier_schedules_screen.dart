import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../alerts/presentation/alerts_screen.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/management_session_provider.dart';
import '../../management/presentation/protected_dialog.dart';
import '../../settings/presentation/language_button.dart';
import '../application/supplier_service.dart';
import '../domain/supplier_visit.dart';
import 'supplier_finance_forms.dart';
import 'supplier_invoice_screen.dart';

/// Notification entry is protected before any operational or owner data loads.
class SupplierSchedulesScreen extends StatefulWidget {
  const SupplierSchedulesScreen({super.key, this.supplier});
  final EntityId? supplier;
  @override
  State<SupplierSchedulesScreen> createState() =>
      _SupplierSchedulesScreenState();
}

class _SupplierSchedulesScreenState extends State<SupplierSchedulesScreen> {
  bool busy = false, started = false;
  bool deliveryUnavailable = false;
  String? error, status = 'planned';
  CalendarDate? today;
  CalendarDate? nextDay;
  SupplierVisitCalendar? calendar;
  List<SupplierVisit> rows = [];
  SupplierVisitCursor? next;
  Future<void> load({bool more = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final s = context.read<AppServices>().suppliers;
      final page = await s.visits(
            supplier: widget.supplier,
            status: status,
            after: more ? next : null,
          ),
          day = await s.today(),
          nextDate = await s.nextVisitDay(supplier: widget.supplier),
          cal = await s.visitCalendar(),
          unavailable = await s.reminderUnavailable(supplier: widget.supplier);
      if (mounted) {
        setState(() {
          rows = page.items;
          next = page.nextCursor;
          today = day;
          nextDay = nextDate;
          calendar = cal;
          deliveryUnavailable = unavailable;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<ManagementSessionProvider>();
    if (!session.unlocked) return;
    if (!started) {
      started = true;
      load();
    }
  }

  Future<void> edit(SupplierVisit? visit) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SupplierVisitScreen(
          supplier: visit?.supplier ?? widget.supplier!,
          id: visit?.id,
        ),
      ),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final owner =
        context.watch<ManagementSessionProvider>().service.role ==
        ManagementRole.owner;
    return ManagementGate(
      capability: ManagementCapability.inventory,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'm53SupplierSchedules')),
          actions: const [LanguageButton()],
        ),
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 4,
                child: busy ? const LinearProgressIndicator() : null,
              ),
              SizedBox(
                height: 0,
                key: ValueKey(
                  busy
                      ? 'supplier-schedules-loading'
                      : 'supplier-schedules-ready',
                ),
              ),
              Expanded(
                child: ListView(
                  key: const ValueKey('supplier-schedules-list'),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(tr(context, 'm53SupplierReminderHelp')),
                    Text(
                      '${tr(context, 'm53VisitNextDate')}: ${nextDay?.iso ?? tr(context, 'm53VisitNoFuture')}',
                      key: const ValueKey('supplier-next-visit'),
                    ),
                    if (deliveryUnavailable)
                      Text(tr(context, 'm53ReminderUnavailable')),
                    if (error != null)
                      Text(
                        tr(context, error!),
                        key: const ValueKey('supplier-schedules-error'),
                      ),
                    if (owner)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AlertsScreen(),
                                ),
                              ),
                        child: Text(
                          tr(context, 'm53ReminderPermissionSettings'),
                        ),
                      ),
                    if (owner)
                      TextButton(
                        key: const ValueKey('supplier-due-reminders-open'),
                        onPressed: busy
                            ? null
                            : () => Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SupplierDueRemindersScreen(
                                    supplier: widget.supplier,
                                  ),
                                ),
                              ),
                        child: Text(tr(context, 'm53DueReminderList')),
                      ),
                    if (widget.supplier != null)
                      FilledButton(
                        key: const ValueKey('supplier-visit-add'),
                        onPressed: busy ? null : () => edit(null),
                        child: Text(tr(context, 'm53VisitAdd')),
                      ),
                    DropdownButtonFormField<String>(
                      key: ValueKey('supplier-visit-filter-$status'),
                      initialValue: status ?? 'all',
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr(context, 'm53VisitFilter'),
                      ),
                      items: [
                        for (final value in [
                          'planned',
                          'completed',
                          'cancelled',
                          'all',
                        ])
                          DropdownMenuItem(
                            value: value,
                            child: Text(tr(context, 'm53VisitStatus$value')),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) {
                              setState(
                                () => status = value == 'all' ? null : value,
                              );
                              load();
                            },
                    ),
                    if (!busy && rows.isEmpty)
                      Text(tr(context, 'm53VisitEmpty')),
                    for (final visit in rows)
                      Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${visit.row['supplier_name']} · ${visit.date.iso}${visit.input.timeMinutes == null ? '' : ' · ${visitTime(visit.input.timeMinutes!)}'}',
                            ),
                            Text(
                              tr(
                                context,
                                'm53VisitStatus${visit.input.status}',
                              ),
                            ),
                            if (visit.input.status == 'planned' &&
                                calendar?.needsAttention(visit.date) == true)
                              Text(tr(context, 'm53VisitAttention')),
                            if (visit.row['note'] != null)
                              Text(visit.row['note'] as String),
                            TextButton(
                              key: ValueKey('supplier-visit-${visit.id.value}'),
                              onPressed: busy ? null : () => edit(visit),
                              child: Text(tr(context, 'm53VisitReview')),
                            ),
                          ],
                        ),
                      ),
                    if (next != null)
                      TextButton(
                        key: const ValueKey('supplier-visits-next'),
                        onPressed: busy ? null : () => load(more: true),
                        child: Text(tr(context, 'm53SupplierNext')),
                      ),
                    TextButton(
                      onPressed: busy ? null : load,
                      child: Text(tr(context, 'm53SupplierFirst')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String visitTime(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

class SupplierVisitScreen extends StatefulWidget {
  const SupplierVisitScreen({super.key, required this.supplier, this.id});
  final EntityId supplier;
  final EntityId? id;
  @override
  State<SupplierVisitScreen> createState() => _SupplierVisitScreenState();
}

class _SupplierVisitScreenState extends State<SupplierVisitScreen> {
  final note = TextEditingController(), fields = SupplierFormFocus();
  CalendarDate? date, today;
  SupplierVisitCalendar? calendar;
  int? minutes;
  int revision = 0, generation = 0;
  String status = 'planned',
      baseline = '',
      operationKey = const IdGenerator().next().value;
  String? error;
  bool reminder = true, busy = false, started = false;
  SupplierVisitInput get input => SupplierVisitInput(
    date: date!,
    timeMinutes: minutes,
    note: note.text,
    status: status,
    reminder: reminder,
  );
  bool get dirty => date != null && jsonEncode(input.fingerprint) != baseline;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<ManagementSessionProvider>();
    if (!session.unlocked) return;
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

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final s = context.read<AppServices>().suppliers,
          day = await s.today(),
          v = widget.id == null ? null : await s.visit(widget.id!),
          cal = await s.visitCalendar();
      if (mounted) {
        check();
        setState(() {
          today = day;
          calendar = cal;
          date = v?.date ?? day;
          minutes = v?.input.timeMinutes;
          note.text = v?.input.note ?? '';
          status = v?.input.status ?? 'planned';
          reminder = v?.input.reminder ?? true;
          revision = v?.revision ?? 0;
          baseline = jsonEncode(input.fingerprint);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (note.text.trim().length > 1000) {
      setState(() => error = 'm53VisitInputInvalid');
      await fields.show('note');
      return;
    }
    final value = input;
    if (!await confirmSupplierFact(
          context,
          '${date!.iso}${minutes == null ? '' : ' · ${visitTime(minutes!)}'}\n${tr(context, 'm53VisitStatus$status')}',
          capability: ManagementCapability.inventory,
        ) ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      check();
      await context.read<AppServices>().suppliers.saveVisit(
        widget.supplier,
        value,
        id: widget.id,
        expectedRevision: revision,
        operationKey: operationKey,
      );
      if (mounted) {
        setState(() => baseline = jsonEncode(input.fingerprint));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    note.dispose();
    fields.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: ListenableBuilder(
      listenable: note,
      builder: (context, _) => FormExitGuard(
        capability: ManagementCapability.inventory,
        dirty: dirty,
        dirtyCheck: () => dirty,
        busy: busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'm53VisitReview')),
            actions: const [LanguageButton()],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              key: const ValueKey('supplier-visit-form'),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 0,
                    key: ValueKey(
                      busy ? 'supplier-visit-loading' : 'supplier-visit-ready',
                    ),
                  ),
                  if (busy) const LinearProgressIndicator(),
                  if (error != null)
                    Text(
                      tr(context, error!),
                      key: const ValueKey('supplier-visit-error'),
                    ),
                  if (error != null && date == null)
                    TextButton(
                      onPressed: busy ? null : load,
                      child: Text(tr(context, 'm5Refresh')),
                    ),
                  Text(tr(context, 'm53VisitNoPosting')),
                  if (date != null) ...[
                    ListTile(
                      key: const ValueKey('supplier-visit-date'),
                      title: Text(tr(context, 'm53VisitDate')),
                      subtitle: Text(date!.iso),
                      onTap: busy
                          ? null
                          : () async {
                              final day = await pickSupplierDate(
                                context,
                                date!,
                              );
                              if (day != null && mounted) {
                                setState(() => date = day);
                              }
                            },
                    ),
                    if (calendar?.needsAttention(date!) == true)
                      Text(tr(context, 'm53VisitAttention')),
                    ListTile(
                      key: const ValueKey('supplier-visit-time'),
                      title: Text(tr(context, 'm53VisitTime')),
                      subtitle: Text(
                        minutes == null
                            ? tr(context, 'm53VisitNoTime')
                            : visitTime(minutes!),
                      ),
                      onTap: busy
                          ? null
                          : () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: (minutes ?? 540) ~/ 60,
                                  minute: (minutes ?? 540) % 60,
                                ),
                                builder: (context, child) => ProtectedDialog(
                                  capability: ManagementCapability.inventory,
                                  child: child!,
                                ),
                              );
                              if (time != null && mounted) {
                                setState(
                                  () => minutes = time.hour * 60 + time.minute,
                                );
                              }
                            },
                    ),
                    if (minutes != null)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() => minutes = null),
                        child: Text(tr(context, 'm53VisitClearTime')),
                      ),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('supplier-visit-status'),
                      initialValue: status,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr(context, 'm53VisitFilter'),
                      ),
                      items: [
                        for (final value in [
                          'planned',
                          'completed',
                          'cancelled',
                        ])
                          DropdownMenuItem(
                            value: value,
                            child: Text(tr(context, 'm53VisitStatus$value')),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() => status = value!),
                    ),
                    SwitchListTile(
                      key: const ValueKey('supplier-visit-reminder'),
                      title: Text(tr(context, 'm53VisitReminder')),
                      value: reminder,
                      onChanged: busy
                          ? null
                          : (v) => setState(() => reminder = v),
                    ),
                    fields.anchor(
                      'note',
                      ManagedTextField(
                        key: const ValueKey('supplier-visit-note'),
                        controller: note,
                        focusNode: fields.node('note'),
                        enabled: !busy,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: tr(context, 'm53VisitNote'),
                        ),
                      ),
                    ),
                    Text(tr(context, 'm53SupplierReminderHelp')),
                    FilledButton(
                      key: const ValueKey('supplier-visit-save'),
                      onPressed: busy || !dirty && widget.id != null
                          ? null
                          : save,
                      child: Text(tr(context, 'save')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SupplierDueRemindersScreen extends StatefulWidget {
  const SupplierDueRemindersScreen({super.key, this.supplier});
  final EntityId? supplier;
  @override
  State<SupplierDueRemindersScreen> createState() =>
      _SupplierDueRemindersScreenState();
}

class _SupplierDueRemindersScreenState
    extends State<SupplierDueRemindersScreen> {
  List<Map<String, Object?>> rows = [];
  SupplierVisitCursor? next;
  bool busy = false, started = false;
  String? error;
  SupplierVisitCalendar? calendar;
  Future<void> load({bool more = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final service = context.read<AppServices>().suppliers;
      final cal = await service.visitCalendar();
      final page = await service.dueReminderInvoices(
        supplier: widget.supplier,
        after: more ? next : null,
      );
      if (mounted) {
        setState(() {
          rows = page.items;
          next = page.nextCursor;
          error = null;
          calendar = cal;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<ManagementSessionProvider>();
    if (!session.unlocked || session.service.role != ManagementRole.owner) {
      return;
    }
    if (!started) {
      started = true;
      load();
    }
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'm53DueReminderList')),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 4,
              child: busy ? const LinearProgressIndicator() : null,
            ),
            SizedBox(
              height: 0,
              key: ValueKey(
                busy ? 'supplier-due-loading' : 'supplier-due-ready',
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('supplier-due-list'),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(tr(context, 'm53DueAttentionHelp')),
                  if (error != null) Text(tr(context, error!)),
                  if (!busy && rows.isEmpty)
                    Text(tr(context, 'm53DueReminderEmpty')),
                  for (final row in rows)
                    Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${row['effective_due']} · ${row['supplier_name_snapshot']}',
                          ),
                          Text(row['invoice_number'] as String? ?? ''),
                          if (calendar != null)
                            Text(
                              tr(
                                context,
                                (row['effective_due'] as String).compareTo(
                                          calendar!.today.iso,
                                        ) <
                                        0
                                    ? 'm53SupplierOverdue'
                                    : row['effective_due'] ==
                                          calendar!.today.iso
                                    ? 'm53SupplierDueToday'
                                    : 'm53SupplierNotDue',
                              ),
                            ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    await Navigator.push<void>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SupplierInvoiceScreen(
                                          id: EntityId(row['id'] as String),
                                        ),
                                      ),
                                    );
                                    if (mounted) await load();
                                  },
                            child: Text(tr(context, 'm53SupplierInvoices')),
                          ),
                        ],
                      ),
                    ),
                  if (next != null)
                    TextButton(
                      onPressed: busy ? null : () => load(more: true),
                      child: Text(tr(context, 'm53SupplierNext')),
                    ),
                  TextButton(
                    onPressed: busy ? null : load,
                    child: Text(tr(context, 'm53SupplierFirst')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
