import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/m54_archive_purge_test.dart' show m54ArchivePurgeSuite;
import '../test/m54_checkout_settlement_test.dart'
    show m54CheckoutSettlementSuite;
import '../test/m54_purchase_history_test.dart' show m54PurchaseHistorySuite;
import '../test/m54_receipt_photo_test.dart' show m54ReceiptPhotoSuite;
import '../test/m54_sale_returns_test.dart' show m54SaleReturnsSuite;
import '../test/support/m53_member_suite.dart';
import '../test/support/m53_supplier_credits_suite.dart';
import '../test/support/m53_supplier_returns_suite.dart';
import '../test/support/m53_warehouse_suite.dart';
import 'm53_portable_backup_test.dart' as portable;
import 'm54_outputs_test.dart' as outputs;
import 'support/encrypted_fixture_factory.dart';

/// Run with the protected wrapper and the literal "M54 " name filter. Groups
/// with shared M5.3 suites select their M5.4 cases through that filter.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
      !const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M54 acceptance requires the isolated Android fixture');
  }
  if (const bool.fromEnvironment('KASIR_M54_RESERVATION_RECHECK')) {
    _supplierAndBackup();
    return;
  }
  group(
    'Checkout',
    () => m54CheckoutSettlementSuite(EncryptedFixtureFactory()),
  );
  group('Sale returns', () => m54SaleReturnsSuite(EncryptedFixtureFactory()));
  group(
    'Receipt photos',
    () => m54ReceiptPhotoSuite(EncryptedFixtureFactory()),
  );
  group(
    'Purchase history',
    () => m54PurchaseHistorySuite(EncryptedFixtureFactory()),
  );
  group('Archive purge', () => m54ArchivePurgeSuite(EncryptedFixtureFactory()));
  group('Warehouse', () => m53WarehouseSuite(EncryptedFixtureFactory()));
  group('Member history', () => m53MemberSuite(EncryptedFixtureFactory()));
  _supplierAndBackup();
  if (const bool.fromEnvironment('KASIR_M54_INCLUDE_OUTPUTS')) {
    group('M54 outputs', outputs.main);
  }
}

void _supplierAndBackup() {
  group(
    'Supplier returns',
    () => m53SupplierReturnsSuite(EncryptedFixtureFactory()),
  );
  group(
    'Supplier credits',
    () => m53SupplierCreditsSuite(EncryptedFixtureFactory()),
  );
  group('M54 portable backup', portable.main);
}
