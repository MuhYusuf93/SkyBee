import '../../../core/presentation/form_exit_guard.dart';
import 'low_price_settings_screen.dart';
import 'feature_settings_screen.dart';
import '../../../app/app_version.dart';
import 'package:kasir_app/l10n/localized_notice.dart';
import 'package:kasir_app/features/settings/presentation/language_button.dart';
import 'package:kasir_app/l10n/localization.dart';
import '../../management/presentation/managed_text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/pin_screen.dart';
import '../../management/presentation/security_settings_screen.dart';
import '../../management/presentation/task_pattern_screen.dart';
import 'settings_provider.dart';
import 'currency_selector.dart';
import '../../printer/presentation/printer_settings_screen.dart';
import '../../backup/presentation/backup_settings_screen.dart';
import '../../alerts/presentation/alerts_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => ManagementGate(
    child: ChangeNotifierProvider(
      create: (_) =>
          SettingsProvider(context.read<AppServices>().settings)..load(),
      child: const _SettingsForm(),
    ),
  );
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm();
  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  final _name = TextEditingController(),
      _zone = TextEditingController(),
      _address = TextEditingController(),
      _contact = TextEditingController(),
      _footer = TextEditingController(),
      _phoneRegion = TextEditingController(text: 'ID');
  List<String>? baseline;
  List<String> snapshot() => [
    _name.text,
    _zone.text,
    _address.text,
    _contact.text,
    _footer.text,
    _phoneRegion.text,
  ];
  bool _loaded = false;
  @override
  void dispose() {
    for (final c in [_name, _zone, _address, _contact, _footer, _phoneRegion]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<SettingsProvider>(
    builder: (context, state, _) {
      if (state.values != null && !_loaded) {
        final values = state.values!;
        _name.text = values['name'] as String? ?? '';
        _zone.text = values['time_zone'] as String;
        _address.text = values['address'] as String? ?? '';
        _contact.text = values['contact_number'] as String? ?? '';
        _footer.text = values['receipt_footer'] as String? ?? '';
        _phoneRegion.text = values['phone_region'] as String? ?? 'ID';
        _loaded = true;
        baseline = snapshot();
      }
      return ListenableBuilder(
        listenable: Listenable.merge([
          _name,
          _zone,
          _address,
          _contact,
          _footer,
          _phoneRegion,
        ]),
        builder: (context, _) => FormExitGuard(
          dirty:
              baseline != null &&
              snapshot().join('\u0000') != baseline!.join('\u0000'),
          child: Scaffold(
            appBar: AppBar(
              actions: const [LanguageButton()],
              title: Text(tr(context, 'storeSettings')),
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ListTile(
                    title: Text(tr(context, 'm51Security')),
                    leading: const Icon(Icons.security),
                    onTap: state.busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const SecuritySettingsScreen(),
                            ),
                          ),
                  ),
                  if (state.busy)
                    LinearProgressIndicator(
                      semanticsLabel: tr(context, 'loading'),
                    ),
                  const CurrencySelector(),
                  for (final destination in [
                    (const TaskPatternScreen(), 'm53TaskPattern'),
                    (const FeatureSettingsScreen(), 'm53Features'),
                    (const LowPriceSettingsScreen(), 'm52LowPriceSettings'),
                    (const PrinterSettingsScreen(), 'm5Printer'),
                    (const AlertsScreen(), 'm5Alerts'),
                    (const BackupSettingsScreen(), 'm5Backup'),
                  ])
                    ListTile(
                      title: Text(tr(context, destination.$2)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => destination.$1),
                      ),
                    ),
                  Text(tr(context, 'currencyScaleHelp')),
                  const SizedBox(height: 16),
                  for (final field in [
                    (_name, tr(context, 'storeName')),
                    (_address, tr(context, 'addressOptional')),
                    (_contact, tr(context, 'whatsappOrPhoneOptional')),
                    (_footer, tr(context, 'receiptFooterOptional')),
                    (_zone, tr(context, 'storeTimeZoneEGAsiaJakarta')),
                    (_phoneRegion, tr(context, 'm52PhoneRegion')),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ManagedTextField(
                        controller: field.$1,
                        enabled: !state.busy,
                        decoration: InputDecoration(
                          labelText: field.$2,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  if (state.error != null) Text(message(context, state.error!)),
                  FilledButton(
                    onPressed: state.busy || !_loaded
                        ? null
                        : () async {
                            if (await state.save(
                                  _name.text,
                                  _zone.text,
                                  _address.text,
                                  _contact.text,
                                  _footer.text,
                                  _phoneRegion.text,
                                ) &&
                                context.mounted) {
                              setState(() => baseline = snapshot());
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: LocalizedNotice(
                                    messageKey: 'settingsSaved',
                                  ),
                                ),
                              );
                            }
                          },
                    child: Text(tr(context, 'saveSettings')),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'kasir_app',
                      applicationVersion: appVersion,
                    ),
                    child: Text(tr(context, 'm5OpenSourceLicenses')),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const PinScreen(rotate: true),
                      ),
                    ),
                    child: Text(tr(context, 'changePinOrRenewRecoveryCode')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
