import 'package:flutter/material.dart';
import '../../../core/domain/value_types.dart';
import '../../../l10n/localization.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/protected_dialog.dart';

/// These short forms render all fields, so validation can reveal and focus the
/// first invalid input even with a keyboard, large text or a privacy gate.
final class SupplierFormFocus {
  bool _disposed = false;
  final _keys = <String, GlobalKey>{};
  final _focus = <String, FocusNode>{};
  FocusNode node(String name) => _focus.putIfAbsent(name, FocusNode.new);
  Widget anchor(String name, Widget child) =>
      KeyedSubtree(key: _keys.putIfAbsent(name, GlobalKey.new), child: child);
  Future<void> show(String name) async {
    final field = _keys[name]?.currentContext;
    if (field != null) {
      await Scrollable.ensureVisible(
        field,
        duration: const Duration(milliseconds: 200),
        alignment: .15,
      );
    }
    if (!_disposed) _focus[name]?.requestFocus();
  }

  void dispose() {
    _disposed = true;
    for (final node in _focus.values) {
      node.dispose();
    }
  }
}

/// Invoice and visit calendars allow today and authorized historical dates.
/// They deliberately do not reuse the expiry picker's minimum-tomorrow rule.
Future<CalendarDate?> pickSupplierDate(
  BuildContext context,
  CalendarDate value, {
  ManagementCapability capability = ManagementCapability.inventory,
}) async {
  final selected = await showDatePicker(
    context: context,
    initialDate: DateTime.parse(value.iso),
    firstDate: DateTime(1900),
    lastDate: DateTime(2199),
    builder: (context, child) =>
        ProtectedDialog(capability: capability, child: child!),
  );
  return selected == null
      ? null
      : CalendarDate(selected.toIso8601String().substring(0, 10));
}

Future<bool> confirmSupplierFact(
  BuildContext context,
  String message, {
  ManagementCapability capability = ManagementCapability.owner,
}) async =>
    await showManagedDialog<bool>(
      context: context,
      builder: (dialog) => ProtectedDialog(
        capability: capability,
        child: AlertDialog(
          scrollable: true,
          title: Text(tr(context, 'm52Review')),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(tr(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(tr(context, 'm5Confirm')),
            ),
          ],
        ),
      ),
    ) ??
    false;
