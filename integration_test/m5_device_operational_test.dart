import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kasir_app/features/alerts/application/android_stock_notifications.dart';
import 'package:sqflite/sqflite.dart';
import '../test/m5_alerts_test.dart' show m5AlertsSuite;
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  m5AlertsSuite(
    EncryptedFixtureFactory(),
    () async =>
        '${await getDatabasesPath()}/m5_regression_${DateTime.now().microsecondsSinceEpoch}.db',
  );
  test(
    'actual Android generic notification posts privately and cancels only its own ID',
    () async {
      if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST')) {
        throw StateError('isolatedNotificationRequired');
      }
      final plugin = FlutterLocalNotificationsPlugin();
      final sink = AndroidStockNotifications(plugin);
      await sink.initialize(() {});
      if (!await sink.permitted) {
        markTestSkipped(
          'Existing test-package notification permission disabled; no settings changed',
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
        await sink.show(id, expiry: false, english: false);
        final note = (await plugin.getActiveNotifications())
            .where((n) => n.id == id)
            .single;
        expect(note.title, 'Pengingat persediaan');
        expect(note.body, 'Buka peringatan persediaan melalui PIN.');
        final metadata = await native.invokeMapMethod<Object?, Object?>(
          'metadata',
          {'id': id},
        );
        expect(metadata?['exists'], true);
        expect(metadata?['privateVisibility'], true);
        await sink.cancel(id);
        // The cancel method acknowledges dispatch to NotificationManager, not
        // service-side removal. Observe completion, without issuing cancel again.
        final clock = Stopwatch()..start();
        var after = (await plugin.getActiveNotifications())
            .map((n) => n.id)
            .toSet();
        final visibleAtFirstRead = after.contains(id);
        while (after.contains(id) &&
            clock.elapsed < const Duration(seconds: 3)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          after = (await plugin.getActiveNotifications())
              .map((n) => n.id)
              .toSet();
        }
        debugPrint(
          'M5_NOTIFICATION_CANCEL firstReadVisible=$visibleAtFirstRead elapsedMs=${clock.elapsedMilliseconds} removed=${!after.contains(id)}',
        );
        expect(after.contains(id), false);
        expect(
          (await native.invokeMapMethod<Object?, Object?>('metadata', {
            'id': id,
          }))?['exists'],
          false,
        );
        expect(after.containsAll(original), true);
      } finally {
        // ID was absent at baseline; never cancel all or remove another alert.
        await sink.cancel(id);
      }
      // Active OS metadata is not evidence of lockscreen appearance, sound,
      // user tapping, TalkBack or OEM rendering on paper/screen.
    },
  );
}
