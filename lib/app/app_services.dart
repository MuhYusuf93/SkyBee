import '../core/time/store_clock.dart';
import '../data/database/database_coordinator.dart';
import '../features/inventory/application/inventory_service.dart';
import '../features/management/application/management_service.dart';
import '../features/settings/application/settings_service.dart';
import '../features/cashier/application/cashier_store.dart';
import '../features/cashier/application/cart_service.dart';
import '../features/cashier/application/checkout_service.dart';
import '../features/cashier/application/product_search_service.dart';
import '../features/receivables/application/receivables_service.dart';
import '../features/sale_history/application/sale_history_service.dart';
import '../features/reports/application/reports_service.dart';
import '../features/corrections/application/correction_service.dart';
import '../features/printer/application/print_queue_service.dart';
import '../features/printer/application/printer_settings_service.dart';
import '../features/printer/application/printer_transport.dart';
import '../features/backup/application/backup_service.dart';
import '../features/backup/application/drive_backup_service.dart';
import '../features/alerts/application/alert_service.dart';
import '../features/alerts/application/android_stock_notifications.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Dependency composition only, no shared cart/catalog/report state.
final class AppServices {
  AppServices(this.database, {StoreClock? clock}) {
    management = ManagementService(database, clock ?? StoreClock());
    inventory = InventoryService(database, management);
    settings = SettingsService(database, management);
    final cashierStore = CashierStore(management.clock);
    cart = CartService(database, cashierStore);
    checkout = CheckoutService(database, cashierStore);
    search = ProductSearchService(database, cashierStore);
    receivables = ReceivablesService(database, cashierStore);
    history = SaleHistoryService(database, management, cashierStore);
    reports = ReportsService(database, management);
    corrections = CorrectionService(database, management, cashierStore);
  }
  final DatabaseCoordinator database;
  late final ManagementService management;
  late final InventoryService inventory;
  late final SettingsService settings;
  late final CartService cart;
  late final CheckoutService checkout;
  late final ProductSearchService search;
  late final ReceivablesService receivables;
  late final SaleHistoryService history;
  late final ReportsService reports;
  late final CorrectionService corrections;
  late final printing = PrintQueueService(
    database,
    checkout,
    management,
    const NativePrinterTransport(),
  );
  late final printers = PrinterSettingsService(database, management);
  late final backups = BackupService(
    database,
    management,
    pausePeripherals: printing.pauseForRestore,
    resumePeripherals: printing.resumeAfterRestore,
  );
  late final drive = DriveBackupService(database, management, backups);
  late final notifications = AndroidStockNotifications(
    FlutterLocalNotificationsPlugin(),
  );
  late final alerts = AlertService(
    database,
    management.clock,
    notifications,
    access: management,
  );
}
