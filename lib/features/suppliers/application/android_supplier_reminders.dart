import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'supplier_reminder_service.dart';
import 'package:flutter/widgets.dart' show Locale;
import '../../../l10n/app_localizations.dart';

/// Shares the app's initialized notification plugin and WorkManager dispatcher.
/// No exact-alarm permission or second background entrypoint is introduced.
final class AndroidSupplierReminders implements SupplierReminderSink {
  AndroidSupplierReminders(
    this.plugin, {
    Workmanager? worker,
    DateTime Function()? now,
  }) : worker = worker ?? Workmanager(),
       now = now ?? DateTime.now;
  final FlutterLocalNotificationsPlugin plugin;
  final Workmanager worker;
  final DateTime Function() now;
  static const task = 'kasir-supplier-reminder-v1',
      tag = 'kasir-supplier-reminders-v1';
  @override
  Future<bool> get permitted async =>
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled() ??
      false;
  @override
  Future<void> schedule(
    String name,
    DateTime target,
    Map<String, String> input,
  ) async {
    final delay = target.difference(now().toUtc());
    await worker.registerOneOffTask(
      name,
      task,
      initialDelay: delay.isNegative ? Duration.zero : delay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      tag: tag,
      inputData: input,
    );
  }

  @override
  Future<void> cancelWork(String name) => worker.cancelByUniqueName(name);
  @override
  Future<void> resetWork() => worker.cancelByTag(tag);
  @override
  Future<void> cancelNotification(int id) => plugin.cancel(id: id);
  @override
  Future<void> show(
    int id, {
    required bool due,
    required String supplier,
    required bool english,
  }) {
    final l = lookupAppLocalizations(Locale(english ? 'en' : 'id'));
    return plugin.show(
      id: id,
      title: due ? l.m53ReminderDueTitle : l.m53ReminderVisitTitle,
      body: l.m53ReminderPrivateBody(
        supplier.length > 80 ? supplier.substring(0, 80) : supplier,
      ),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'supplier_reminders',
          l.m53SupplierSchedules,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          visibility: NotificationVisibility.private,
          onlyAlertOnce: true,
        ),
      ),
      payload: 'supplier-reminders',
    );
  }
}
