import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/localization.dart';
import 'locale_provider.dart';

/// Public language switch is also available inside protected forms/dialogs.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: tr(context, 'language'),
    onSelected: (value) async {
      try {
        await context.read<LocaleProvider?>()?.selectLanguage(value);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(context, 'operationFailed'))),
          );
        }
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem(
        value: 'id',
        child: Text(tr(context, 'indonesianLanguage')),
      ),
      PopupMenuItem(value: 'en', child: Text(tr(context, 'englishLanguage'))),
    ],
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(Localizations.localeOf(context).languageCode.toUpperCase()),
    ),
  );
}
