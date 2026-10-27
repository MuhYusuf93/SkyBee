import 'package:flutter/material.dart';
import '../../../core/money/money.dart';
import '../../../l10n/localization.dart';
import '../domain/product_attributes.dart';

/// Compact metadata only. Internal notes are never passed to receipt encoders.
class ProductAttributesView extends StatelessWidget {
  const ProductAttributesView({
    super.key,
    required this.attributes,
    this.currency,
  });
  final ProductAttributes attributes;
  final CurrencyPolicy? currency;
  @override
  Widget build(BuildContext context) {
    final a = attributes;
    if (a.isEmpty) return const SizedBox.shrink();
    final language = Localizations.localeOf(context).languageCode;
    final unit = a.unit == 'l'
        ? tr(context, 'm51Liter')
        : a.unit == 'ons'
        ? tr(context, 'm53Ons')
        : a.unit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (a.sizeMilli != null)
          Text('${tr(context, 'm51Size')}: ${a.sizeText(language)} $unit'),
        if (a.shelf != null) Text('${tr(context, 'm51Shelf')}: ${a.shelf}'),
        if (a.note != null)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(tr(context, 'm51Note')),
            subtitle: Text(
              a.note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(a.note!),
              ),
            ],
          ),
      ],
    );
  }
}
