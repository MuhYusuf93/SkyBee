import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:kasir_app/features/alerts/application/android_stock_notifications.dart';
import 'package:kasir_app/features/backup/application/backup_scheduler.dart';
import 'package:kasir_app/features/suppliers/application/android_supplier_reminders.dart';
import 'package:kasir_app/features/suppliers/application/supplier_service.dart';

/// Explicit native registration/notification probes, never proof of natural
/// overnight H-1 timing, physical lockscreen rendering or a user tapping it.
void supplierReminderPlatformProbe() {
  void isolated() {
    if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
        !const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
      throw StateError('Isolated paused Android required');
    }
  }

  test(
    'M53 native supplier WorkManager future job registers replaces and cancels own unique work',
    () async {
      isolated();
      final worker = Workmanager(), plugin = FlutterLocalNotificationsPlugin();
      await worker.initialize(m5BackgroundDispatcher);
      final sink = AndroidSupplierReminders(plugin, worker: worker);
      final hash = SupplierService.fingerprint([
        'public-native-probe',
        DateTime.now().microsecondsSinceEpoch,
      ]);
      final name = 'kasir-supplier-$hash';
      expect(await worker.isScheduledByUniqueName(name), isFalse);
      try {
        final target = DateTime.now().toUtc().add(const Duration(days: 3));
        await sink.schedule(name, target, {
          'key': 'visit/00000000-0000-4000-8000-000000000001',
          'fingerprint': hash,
        });
        expect(await worker.isScheduledByUniqueName(name), isTrue);
        await sink.schedule(name, target, {
          'key': 'visit/00000000-0000-4000-8000-000000000001',
          'fingerprint': hash,
        });
        expect(await worker.isScheduledByUniqueName(name), isTrue);
        await sink.cancelWork(name);
        final watch = Stopwatch()..start();
        while (await worker.isScheduledByUniqueName(name) &&
            watch.elapsed < const Duration(seconds: 5)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(await worker.isScheduledByUniqueName(name), isFalse);
      } finally {
        await sink.cancelWork(name);
      }
    },
  );
  test(
    'M53 native supplier notification is private generic and cancels its own ID',
    () async {
      isolated();
      final plugin = FlutterLocalNotificationsPlugin();
      await AndroidStockNotifications(plugin).initialize(() {});
      final sink = AndroidSupplierReminders(plugin);
      if (!await sink.permitted) {
        markTestSkipped(
          'Test-package notification permission disabled; no permission/settings changed',
        );
        return;
      }
      final original = (await plugin.getActiveNotifications())
          .map((n) => n.id)
          .toSet();
      var id = 1777000000 + DateTime.now().microsecondsSinceEpoch % 1000000;
      while (original.contains(id)) {
        id = 1777000000 + (id + 1) % 1000000;
      }
      const native = MethodChannel('kasir_app/notification_probe');
      try {
        await sink.show(
          id,
          due: true,
          supplier: 'PUBLIC SUPPLIER',
          english: false,
        );
        final note = (await plugin.getActiveNotifications()).singleWhere(
          (n) => n.id == id,
        );
        expect(note.title, 'Tagihan supplier jatuh tempo besok');
        expect(note.body, 'PUBLIC SUPPLIER · Buka melalui akses Kelola.');
        final metadata = await native.invokeMapMethod<Object?, Object?>(
          'metadata',
          {'id': id},
        );
        expect(metadata?['exists'], isTrue);
        expect(metadata?['privateVisibility'], isTrue);
        await sink.cancelNotification(id);
        final watch = Stopwatch()..start();
        while ((await plugin.getActiveNotifications()).any((n) => n.id == id) &&
            watch.elapsed < const Duration(seconds: 5)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        final remaining = (await plugin.getActiveNotifications())
            .map((n) => n.id)
            .toSet();
        expect(remaining.contains(id), isFalse);
        expect(remaining.containsAll(original), isTrue);
      } finally {
        await sink.cancelNotification(id);
      }
    },
  );
}
