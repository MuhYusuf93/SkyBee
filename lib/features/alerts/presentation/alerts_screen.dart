import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../management/presentation/management_session_provider.dart';

/// Page-sized derived data and local form state only; conditions and notification
/// identity live in AlertService. Denied permission never hides in-app warnings.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Map<String, Object?>> rows = [];
  bool busy = false, enabled = false, loaded = false;
  String? status;
  final days = TextEditingController(text: '5');
  AppServices? app;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (app == null) {
      app = context.read<AppServices>();
      load();
    }
  }

  Future<void> action(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await work();
    } catch (_) {
      status = 'm5OperationFailed';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load({int after = 0}) => action(() async {
    if (!loaded) {
      final config = await app!.alerts.settings();
      enabled = config['notifications_enabled'] == 1;
      days.text = '${config['expiry_warning_days']}';
      loaded = true;
    }
    await app!.alerts.evaluate();
    final result = await app!.alerts.page(after: after);
    if (mounted) rows = result;
  });
  @override
  void dispose() {
    days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<ManagementSessionProvider>().unlocked &&
        !loaded &&
        !busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !loaded && !busy) load();
      });
    }
    return ManagementGate(
      child: Scaffold(
        appBar: AppBar(title: Text(tr(context, 'm5Alerts'))),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(tr(context, 'm5AlertsHelp')),
              if (busy)
                LinearProgressIndicator(semanticsLabel: tr(context, 'loading')),
              if (status != null) Text(tr(context, status!)),
              ManagedTextField(
                controller: days,
                enabled: !busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr(context, 'm5ExpiryDays'),
                ),
              ),
              SwitchListTile(
                title: Text(tr(context, 'm5Notifications')),
                value: enabled,
                onChanged: busy
                    ? null
                    : (value) => setState(() => enabled = value),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => action(() async {
                        // Save the user's preference before Android's permission UI locks the
                        // route. Denial leaves derived warnings available, without auto-unlock.
                        await app!.alerts.configure(
                          enabled: enabled,
                          days: int.parse(days.text),
                        );
                        final granted =
                            !enabled ||
                            await app!.notifications.requestPermission();
                        status = granted
                            ? 'm5SettingsSaved'
                            : 'm5PermissionDenied';
                        await app!.alerts.evaluate();
                      }),
                child: Text(tr(context, 'save')),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => load(),
                    child: Text(tr(context, 'm5FirstPage')),
                  ),
                  if (rows.length == 50)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => load(
                              after: rows.last['notification_id'] as int,
                            ),
                      child: Text(tr(context, 'm5NextPage')),
                    ),
                ],
              ),
              if (rows.isEmpty && !busy) Text(tr(context, 'm5NoAlerts')),
              for (final row in rows)
                Builder(
                  builder: (context) {
                    final body =
                        jsonDecode(row['body_json'] as String)
                            as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text(body['name'] as String),
                        subtitle: Text(
                          row['kind'] == 'expiry'
                              ? '${tr(context, 'm5Expiry')}: ${body['quantity']} · ${body['firstDate']}'
                              : '${tr(context, 'm5Saleable')}: ${body['saleable']} · ${tr(context, 'm5Minimum')}: ${body['minimum']}',
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
