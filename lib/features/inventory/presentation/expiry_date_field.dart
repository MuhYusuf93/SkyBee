import '../../management/domain/management_role.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../l10n/localization.dart';
import '../domain/product_entry_rules.dart';
import '../../management/presentation/protected_dialog.dart';

/// Optional calendar input. Cancellation preserves the exact prior value;
/// submit validation lives in the service as well, so midnight cannot bypass it.
class ExpiryDateField extends StatelessWidget {
  const ExpiryDateField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.errorText,
    this.physicalObservation = false,
  });
  final TextEditingController controller;
  final bool enabled;

  /// A physical count records what exists, including expired stock. The normal
  /// receiving rule remains tomorrow; this mode never invents a new expiry.
  final bool physicalObservation;
  final String? errorText;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => InputDecorator(
      decoration: InputDecoration(
        labelText: tr(context, 'expiryDateYyyyMmDdOptional'),
        errorText: errorText,
        border: const OutlineInputBorder(),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(controller.text.isEmpty ? '—' : controller.text),
          ),
          IconButton(
            tooltip: tr(context, 'clearSelection'),
            onPressed: !enabled || controller.text.isEmpty
                ? null
                : controller.clear,
            icon: const Icon(Icons.clear),
          ),
          IconButton(
            tooltip: tr(
              context,
              physicalObservation ? 'm53StocktakeExpiry' : 'm52DateTomorrow',
            ),
            onPressed: !enabled
                ? null
                : () async {
                    final access = context.read<AppServices>().management;
                    final generation = access.generation;
                    final today = access.clock.now.toLocal();
                    final first = physicalObservation
                        ? DateTime(1)
                        : firstNewExpiry(access.clock.now);
                    final last = DateTime(today.year + 100, 12, 31);
                    final old = DateTime.tryParse(controller.text);
                    final initial =
                        old == null || old.isBefore(first) || old.isAfter(last)
                        ? (physicalObservation
                              ? DateTime(today.year, today.month, today.day)
                              : first)
                        : old;
                    final date = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: first,
                      lastDate: last,
                      builder: (context, child) => ProtectedDialog(
                        capability: ManagementCapability.inventory,
                        child: child!,
                      ),
                    );
                    if (date != null &&
                        context.mounted &&
                        access.isUnlocked &&
                        generation == access.generation) {
                      controller.text =
                          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    }
                  },
            icon: const Icon(Icons.calendar_month),
          ),
        ],
      ),
    ),
  );
}
