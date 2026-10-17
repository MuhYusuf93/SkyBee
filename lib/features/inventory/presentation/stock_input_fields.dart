import 'whole_quantity_formatter.dart';
import 'package:flutter/material.dart';
import '../../../l10n/localization.dart';
import '../domain/stock_input.dart';
import '../../management/presentation/managed_text_field.dart';

/// Form-local ownership, shared by initial stock, receipts and physical count.
/// This controller holds input only; conversion rules live in StockInput.
final class StockInputController {
  StockInputController({String count = '0', int? packSize, String? packLabel})
    : quantity = TextEditingController(text: count),
      size = TextEditingController(text: packSize?.toString() ?? ''),
      packLabel = packLabel ?? 'box';
  final TextEditingController quantity;
  final TextEditingController size;
  String packLabel;
  StockInputUnit unit = StockInputUnit.base;
  StockInput parse({bool positive = false}) => StockInput(
    parseWholeQuantity(quantity.text, positive: positive),
    unit: unit,
    packSize: unit == StockInputUnit.pack
        ? parseWholeQuantity(size.text, positive: true)
        : null,
    packLabel: unit == StockInputUnit.pack ? packLabel : null,
  );
  void dispose() {
    quantity.dispose();
    size.dispose();
  }
}

/// ValueListenableBuilder rebuilds previews, without rebuilding siblings during
/// locale/IME updates. Invalid edits are rejected whole, never digit-stripped.
class StockInputFields extends StatelessWidget {
  const StockInputFields({
    super.key,
    required this.controller,
    required this.onUnitChanged,
    required this.quantityLabel,
    this.enabled = true,
  });
  final StockInputController controller;
  final VoidCallback onUnitChanged;
  final String quantityLabel;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DropdownButtonFormField<StockInputUnit>(
        initialValue: controller.unit,
        isExpanded: true,
        decoration: InputDecoration(labelText: tr(context, 'm31InputUnit')),
        items: [
          for (final unit in StockInputUnit.values)
            DropdownMenuItem(
              value: unit,
              child: Text(
                tr(
                  context,
                  unit == StockInputUnit.base ? 'm31BaseUnit' : 'm31PackUnit',
                ),
              ),
            ),
        ],
        onChanged: !enabled
            ? null
            : (value) {
                if (value != null) {
                  controller.unit = value;
                  onUnitChanged();
                }
              },
      ),
      ManagedTextField(
        controller: controller.quantity,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: const [WholeQuantityFormatter()],
        decoration: InputDecoration(
          labelText: controller.unit == StockInputUnit.base
              ? quantityLabel
              : tr(context, 'm31PackCount'),
          helperText: tr(context, 'm31DigitsHelp'),
        ),
      ),
      if (controller.unit == StockInputUnit.pack) ...[
        ManagedTextField(
          controller: controller.size,
          enabled: enabled,
          keyboardType: TextInputType.number,
          inputFormatters: const [WholeQuantityFormatter()],
          decoration: InputDecoration(
            labelText: tr(context, 'm31PackSize'),
            helperText: tr(context, 'm31ReceiptOverride'),
          ),
        ),
        ListenableBuilder(
          listenable: Listenable.merge([controller.quantity, controller.size]),
          builder: (context, _) {
            String preview;
            try {
              final input = controller.parse();
              preview = AppLocalizations.of(context)!.m31ConversionPreview(
                input.count.toString(),
                input.packSize.toString(),
                input.quantityBase.toString(),
              );
            } on Object {
              preview = tr(context, 'm31PreviewInvalid');
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(preview),
            );
          },
        ),
      ],
    ],
  );
}
