import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'alert_service.dart';

/// Lock-screen text and payload contain no customer, debt or product details.
/// Taps only request the protected alerts route; the management PIN gate remains.
final class AndroidStockNotifications implements StockNotificationSink {
  AndroidStockNotifications(this.plugin);
  final FlutterLocalNotificationsPlugin plugin;
  Future<void> initialize(
    void Function() onTap, {
    void Function()? onSupplierTap,
  }) async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stock_notification'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          response.payload == 'supplier-reminders' && onSupplierTap != null
          ? onSupplierTap()
          : onTap(),
    );
  }

  Future<bool> requestPermission() async =>
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission() ??
      false;
  @override
  Future<bool> get permitted async =>
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled() ??
      false;
  static const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'stock_alerts_v1',
      'Inventory alerts',
      channelDescription: 'Stock and expiry reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      visibility: NotificationVisibility.private,
      onlyAlertOnce: true,
    ),
  );
  @override
  Future<void> show(int id, {required bool expiry, required bool english}) =>
      plugin.show(
        id: id,
        title: english ? 'Inventory reminder' : 'Pengingat persediaan',
        body: english
            ? 'Open protected inventory alerts.'
            : 'Buka peringatan persediaan melalui PIN.',
        notificationDetails: details,
        payload: 'inventory-alerts',
      );
  @override
  Future<void> summary(int count, {required bool english}) => plugin.show(
    id: AlertService.summaryId,
    title: english ? 'Inventory reminders' : 'Pengingat persediaan',
    body: english
        ? '$count active alerts. Open inventory.'
        : '$count peringatan aktif. Buka persediaan.',
    notificationDetails: details,
    payload: 'inventory-alerts',
  );
  @override
  Future<void> cancel(int id) => plugin.cancel(id: id);
}
