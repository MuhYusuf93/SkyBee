import '../features/cashier_lock/application/cashier_lock_service.dart';
import '../features/barcode/application/native_barcode_camera.dart';
import '../features/barcode/domain/barcode_camera.dart';
import '../features/cash_drawer/application/cash_drawer_service.dart';
import '../features/members/application/member_service.dart';
import '../features/onboarding/application/onboarding_service.dart';
import '../features/cashier/application/quick_cash_service.dart';
import '../features/cashier/application/quantity_promotion_service.dart';
import '../features/reports/application/report_export_service.dart';
import '../core/time/store_clock.dart';
import '../data/database/database_coordinator.dart';
import '../features/inventory/application/inventory_service.dart';
import '../features/management/application/management_service.dart';
import '../features/management/application/strong_biometrics.dart';
import '../features/settings/application/settings_service.dart';
import '../features/cashier/application/cashier_store.dart';
import '../features/cashier/application/cart_service.dart';
import '../features/cashier/application/checkout_service.dart';
import '../features/cashier/application/product_search_service.dart';
import '../features/receivables/application/receivables_service.dart';
import '../features/sale_history/application/sale_history_service.dart';
import '../features/reports/application/reports_service.dart';
import '../features/corrections/application/correction_service.dart';
import '../features/cash_drawer/application/cash_drawer_history_service.dart';
import '../features/printer/application/print_queue_service.dart';
import '../features/printer/application/printer_settings_service.dart';
import '../features/printer/application/printer_transport.dart';
import '../features/printer/application/printer_output_gate.dart';
import '../features/printer/application/recovery_print_service.dart';
import '../features/backup/application/backup_service.dart';
import '../features/backup/application/drive_backup_service.dart';
import '../features/alerts/application/alert_service.dart';
import '../features/alerts/application/android_stock_notifications.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../features/suppliers/application/supplier_service.dart';
import '../features/suppliers/application/supplier_reminder_service.dart';
import '../features/suppliers/application/android_supplier_reminders.dart';

/// Dependency composition only, no shared cart/catalog/report state.
final class AppServices {
  AppServices(
    this.database, {
    StoreClock? clock,
    StrongBiometrics? biometrics,
    PrinterOutputGate? printerGate,
    BarcodeCamera Function()? barcodeCameraFactory,
    this.supplierReminderSink,
  }) : printerGate = printerGate ?? defaultPrinterOutputGate(),
       barcodeCameraFactory = barcodeCameraFactory ?? NativeBarcodeCamera.new {
    management = ManagementService(
      database,
      clock ?? StoreClock(),
      biometrics: biometrics,
    );
    inventory = InventoryService(database, management);
    settings = SettingsService(database, management);
    final cashierStore = CashierStore(
      management.clock,
      cashierAccess: cashierLock,
    );
    cart = CartService(database, cashierStore);
    cashDrawer = CashDrawerService(database, management, cashierStore);
    cashDrawerHistory = CashDrawerHistoryService(cashDrawer);
    checkout = CheckoutService(database, cashierStore);
    search = ProductSearchService(database, cashierStore);
    receivables = ReceivablesService(database, cashierStore);
    members = MemberService(database, management, cashierStore);
    history = SaleHistoryService(database, management, cashierStore);
    reports = ReportsService(database, management);
    corrections = CorrectionService(database, management, cashierStore);
  }
  final DatabaseCoordinator database;
  final PrinterOutputGate printerGate;
  final BarcodeCamera Function() barcodeCameraFactory;
  final SupplierReminderSink? supplierReminderSink;
  late final ManagementService management;
  late final suppliers = SupplierService(database, management);
  late final supplierReminders = SupplierReminderService(
    database,
    management.clock,
    supplierReminderSink ?? AndroidSupplierReminders(notifications.plugin),
  );
  late final onboarding = OnboardingService(database, management);
  late final cashierLock = CashierLockService(database, management);
  late final InventoryService inventory;
  late final SettingsService settings;
  late final CartService cart;
  late final CashDrawerService cashDrawer;
  late final CashDrawerHistoryService cashDrawerHistory;
  late final CheckoutService checkout;
  late final ProductSearchService search;
  late final ReceivablesService receivables;
  late final MemberService members;
  late final SaleHistoryService history;
  late final ReportsService reports;
  late final CorrectionService corrections;
  late final printing = PrintQueueService(
    database,
    checkout,
    management,
    const NativePrinterTransport(),
    outputGate: printerGate,
  );
  late final quickCash = QuickCashService(
    database,
    management,
    cashierAccess: cashierLock,
  );
  late final promotions = QuantityPromotionService(database, management);
  late final reportExport = ReportExportService(database, management);
  late final printers = PrinterSettingsService(
    database,
    management,
    outputGate: printerGate,
  );
  late final cashierPrinters = PrinterSettingsService(
    database,
    management,
    outputGate: printerGate,
    publicAccess: true,
  );
  late final backups = BackupService(
    database,
    management,
    pausePeripherals: printing.pauseForRestore,
    resumePeripherals: printing.resumeAfterRestore,
  );
  late final drive = DriveBackupService(database, management, backups);
  late final recoveryPrinting = RecoveryPrintService(
    database,
    management,
    backups,
    printing,
  );
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
