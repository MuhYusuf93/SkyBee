// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get managementAccess => 'Management access';

  @override
  String get addressOptional => 'Address (optional)';

  @override
  String get correctionReason => 'Correction reason';

  @override
  String get archive => 'Archive';

  @override
  String get archiveProduct => 'Archive product?';

  @override
  String get archiveRecord => 'Archive record?';

  @override
  String get products => 'Products';

  @override
  String get receiveStock => 'Receive stock';

  @override
  String get stockCannotBeSoldFromItsExpiry =>
      'Stock cannot be sold from its expiry date in the store time zone. Enable tracking to record dates; undated stock is marked as unrecorded.';

  @override
  String get barcodeOptional => 'Barcode (optional)';

  @override
  String get cancel => 'Cancel';

  @override
  String get reverseLatestReceipt => 'Reverse latest receipt';

  @override
  String get pay => 'Pay';

  @override
  String get noProductsYet => 'No products yet.';

  @override
  String get noRecordsYet => 'No records yet.';

  @override
  String get noHistoryYet => 'No history yet.';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get createAPinForInventoryAndSettings =>
      'Create a PIN for inventory and settings. Keep the recovery code outside this device.';

  @override
  String get createManagementPin => 'Create management PIN';

  @override
  String get generateCode => 'Generate code';

  @override
  String get openManagement => 'Open management';

  @override
  String get searchOrAddCategory => 'Search or add category';

  @override
  String get searchOrAddSupplier => 'Search or add supplier';

  @override
  String get searchProducts => 'Search products';

  @override
  String get searchNamePrefix => 'Search name prefix';

  @override
  String get searchProductNamePrefix => 'Search product name prefix';

  @override
  String get writeThisCodeDownAndStoreIt =>
      'Write this code down and store it outside this device. It is shown only once. If both PIN and code are lost, management access requires a valid recovery procedure.';

  @override
  String get recordDamagedOrExpiredStock => 'Record damaged or expired stock';

  @override
  String get tryAgain => 'Try again';

  @override
  String get shoppingList => 'Shopping list';

  @override
  String get productDetails => 'Product details';

  @override
  String get inventory => 'Inventory';

  @override
  String get useRecoveryCode => 'Use recovery code';

  @override
  String get price => 'Price';

  @override
  String get purchasePriceWhenStockIsEmpty =>
      'Purchase price when stock is empty';

  @override
  String get purchasePricePerUnit => 'Purchase price per pcs';

  @override
  String get priceSaved => 'Price saved.';

  @override
  String get sellingPrice => 'Selling price';

  @override
  String get debts => 'Debts';

  @override
  String get initialQuantity => 'Initial quantity';

  @override
  String get currentPhysicalQuantity => 'Current physical quantity';

  @override
  String get unitQuantity => 'Unit quantity';

  @override
  String get cashier => 'Cashier';

  @override
  String get checkoutReceivablesReportsPrintingAndBackupsWill =>
      'Checkout, receivables, reports, printing and backups will be added in later stages.';

  @override
  String get categories => 'Categories';

  @override
  String get categoryOptional => 'Category (optional)';

  @override
  String get savedCategory => 'Saved category';

  @override
  String get expiryYyyyMmDdOptional => 'Expiry yyyy-MM-dd (optional)';

  @override
  String get manage => 'Manage';

  @override
  String get typeANamePrefixThenSelect => 'Type a name prefix, then select';

  @override
  String get recoveryCode => 'Recovery code';

  @override
  String get storeCodeAutomaticIfEmpty => 'Store code (automatic if empty)';

  @override
  String get codeBarcodeAndCategory => 'Code, barcode and category';

  @override
  String get confirmNewPin => 'Confirm new PIN';

  @override
  String get correctLatestReceipt => 'Correct latest receipt';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String get lock => 'Lock';

  @override
  String get continueAction => 'Continue';

  @override
  String get enterAValidAmountQuantityAndYyyy =>
      'Enter a valid amount, quantity and yyyy-MM-dd date.';

  @override
  String get forgotPinOrChangeRecoveryCode =>
      'Forgot PIN or change recovery code';

  @override
  String get enterPinAgain => 'Enter PIN again';

  @override
  String get checking => 'Checking…';

  @override
  String get expiringSoon => 'Expiring soon';

  @override
  String get preparingStorage => 'Preparing storage…';

  @override
  String get saving => 'Saving…';

  @override
  String get loadMore => 'Load more';

  @override
  String get reload => 'Reload';

  @override
  String get reloadDetails => 'Reload details';

  @override
  String get name => 'Name';

  @override
  String get productName => 'Product name';

  @override
  String get searchAliasesSeparatedByCommas =>
      'Search aliases, separated by commas';

  @override
  String get storeName => 'Store name';

  @override
  String get nameCodeOrBarcode => 'Name, code or barcode';

  @override
  String get contactNumberOptional => 'Contact number (optional)';

  @override
  String get operationFailedTryAgainOrCheckDevice =>
      'Operation failed. Try again or check device storage.';

  @override
  String get pin => 'PIN';

  @override
  String get newPin => 'New PIN';

  @override
  String get theFourDigitPinRestrictsAccessWithin =>
      'The four-digit PIN restricts access within the app; it does not encrypt the database or device. Keep the recovery code private.';

  @override
  String get oldPin => 'Old PIN';

  @override
  String get trackExpiry => 'Track expiry';

  @override
  String get cashierSearchCartAndPaymentsAreNot =>
      'Cashier search, cart and payments are not available yet. Open inventory using Manage.';

  @override
  String get nextReceipts => 'Next receipts';

  @override
  String get aReceiptCanBeReversedOnlyIf =>
      'A receipt can be reversed only if no subsequent stock movement depends on it. Original records are retained.';

  @override
  String get settingsSaved => 'Settings saved.';

  @override
  String get storeSettings => 'Store settings';

  @override
  String get management => 'Management';

  @override
  String get cannotOpenManagementTryAgain =>
      'Cannot open management. Try again.';

  @override
  String get managementLocked => 'Management locked';

  @override
  String get removeStock => 'Remove stock';

  @override
  String get cannotOpenStorage => 'Cannot open storage.';

  @override
  String get cannotOpenStorageTryAgainOrCheck =>
      'Cannot open storage. Try again or check free device space.';

  @override
  String get localStorageReady => 'Local storage ready.';

  @override
  String get checkQuantityAmountAndDateUseWhole =>
      'Check quantity, amount and date. Use whole units and a valid yyyy-MM-dd date.';

  @override
  String get stockAndExpiryWarnings => 'Stock and expiry warnings';

  @override
  String get lowStockWarning => 'Low stock warning';

  @override
  String get selectCategory => 'Select category';

  @override
  String get selectSupplier => 'Select supplier';

  @override
  String get restore => 'Restore';

  @override
  String get restoreProduct => 'Restore product?';

  @override
  String get restoreRecord => 'Restore record?';

  @override
  String get productHistory => 'Product history';

  @override
  String get stockAndPriceHistory => 'Stock and price history';

  @override
  String get sessionLocked => 'Session locked';

  @override
  String get save => 'Save';

  @override
  String get saveProduct => 'Save product';

  @override
  String get saveRecoveryCode => 'Save recovery code';

  @override
  String get saveSettings => 'Save settings';

  @override
  String get productStatusUpdated => 'Product status updated.';

  @override
  String get stock => 'Stock';

  @override
  String get initialStockAndPurchasePrice => 'Initial stock and purchase price';

  @override
  String get initialStock => 'Initial stock';

  @override
  String get minimumStock => 'Minimum stock';

  @override
  String get stockCount => 'Stock count';

  @override
  String get stockByReceipt => 'Stock by receipt';

  @override
  String get lowStock => 'Low stock';

  @override
  String get iHaveSavedIt => 'I have saved it';

  @override
  String get suppliers => 'Suppliers';

  @override
  String get supplierOptional => 'Supplier (optional)';

  @override
  String get addProduct => 'Add product';

  @override
  String get showPin => 'Show PIN';

  @override
  String get showArchived => 'Show archived';

  @override
  String get dateNotRecorded => 'Date not recorded';

  @override
  String get someStockHasNoRecordedExpiryDate =>
      'Some stock has no recorded expiry date.';

  @override
  String get expiryDateYyyyMmDdOptional => 'Expiry date yyyy-MM-dd (optional)';

  @override
  String get noSupplier => 'No supplier';

  @override
  String get cannotUndo => 'Cannot undo.';

  @override
  String get myStore => 'My store';

  @override
  String get total => 'Total';

  @override
  String get close => 'Close';

  @override
  String get closeThisDialogAndEnterYourPin =>
      'Close this dialog and enter your PIN again.';

  @override
  String get changePinOrRecovery => 'Change PIN or recovery';

  @override
  String get changePinOrRenewRecoveryCode =>
      'Change PIN or renew recovery code';

  @override
  String get editProduct => 'Edit product';

  @override
  String get editRecord => 'Edit record';

  @override
  String get receiptFooterOptional => 'Receipt footer (optional)';

  @override
  String get undo => 'Undo';

  @override
  String get whatsappOrPhoneOptional => 'WhatsApp or phone (optional)';

  @override
  String get storeTimeZoneEGAsiaJakarta => 'Store time zone, e.g. Asia/Jakarta';

  @override
  String get productNotFound => 'Product not found.';

  @override
  String get productIsArchivedRestoreItFirst =>
      'Product is archived. Restore it first.';

  @override
  String get categoryOrSupplierUnavailableSelectAgain =>
      'Category or supplier unavailable. Select again.';

  @override
  String get productNameIsRequired => 'Product name is required.';

  @override
  String get codeOrBarcodeBelongsToAnArchived =>
      'Code or barcode belongs to an archived product. Restore it or use a different code.';

  @override
  String get codeOrBarcodeIsAlreadyUsedBy =>
      'Code or barcode is already used by another product.';

  @override
  String get purchasePriceIsRequiredForInitialStock =>
      'Purchase price is required for initial stock.';

  @override
  String get datedStockRemainsHandleItBeforeDisabling =>
      'Dated stock remains. Handle it before disabling expiry tracking.';

  @override
  String get productChangedReloadBeforeSaving =>
      'Product changed. Reload before saving.';

  @override
  String get productChangedReloadFirst => 'Product changed. Reload first.';

  @override
  String get cannotUndoTheTimeLimitPassedOr =>
      'Cannot undo: the time limit passed or another change occurred.';

  @override
  String get stockRemainsArchivingIsRefused =>
      'Stock remains. Archiving is refused.';

  @override
  String get invalidOperationIdentifier => 'Invalid operation identifier.';

  @override
  String get operationIdentifierAlreadyUsedForDifferentData =>
      'Operation identifier already used for different data.';

  @override
  String get enableExpiryTrackingBeforeRecordingDates =>
      'Enable expiry tracking before recording dates.';

  @override
  String get stockChangedRetryWithCurrentData =>
      'Stock changed. Retry with current data.';

  @override
  String get correctionReasonIsRequired => 'Correction reason is required.';

  @override
  String get receiptCannotBeReversedThroughThisFlow =>
      'Receipt cannot be reversed through this flow.';

  @override
  String get receiptAlreadyReversed => 'Receipt already reversed.';

  @override
  String get stockCountReasonIsRequired => 'Stock count reason is required.';

  @override
  String get physicalQuantityAlreadyMatchesTheRecord =>
      'Physical quantity already matches the record.';

  @override
  String get purchasePriceIsRequiredWhenAddingTo =>
      'Purchase price is required when adding to empty stock.';

  @override
  String get stockRemovalReasonIsRequired =>
      'Stock removal reason is required.';

  @override
  String get insufficientBatchQuantity => 'Insufficient batch quantity.';

  @override
  String get batchListChangedReload => 'Batch list changed. Reload.';

  @override
  String get nameIsRequired => 'Name is required.';

  @override
  String get recordUnavailableReload => 'Record unavailable. Reload.';

  @override
  String get recordNotFound => 'Record not found.';

  @override
  String get historyFilterChangedReload => 'History filter changed. Reload.';

  @override
  String get filterChangedReloadList => 'Filter changed. Reload list.';

  @override
  String get managementSessionLockedEnterPinAgain =>
      'Management session locked. Enter PIN again.';

  @override
  String get pinMustContainFourDigits => 'PIN must contain four digits.';

  @override
  String get pinConfirmationDoesNotMatch => 'PIN confirmation does not match.';

  @override
  String get storeNameIsRequired => 'Store name is required.';

  @override
  String get createAManagementPinFirst => 'Create a management PIN first.';

  @override
  String get unsupportedPinConfiguration => 'Unsupported PIN configuration.';

  @override
  String get pinOrRecoveryCodeDoesNotMatch =>
      'PIN or recovery code does not match.';

  @override
  String get sessionLockedEnterPinAgain => 'Session locked. Enter PIN again.';

  @override
  String get pinChangeIsInProgress => 'PIN change is in progress.';

  @override
  String get unknownTimeZoneExampleAsiaJakarta =>
      'Unknown time zone. Example: Asia/Jakarta.';

  @override
  String get priceChange => 'Price change';

  @override
  String get undoPrice => 'Undo price';

  @override
  String get language => 'Language';

  @override
  String get operationFailed =>
      'Operation failed. Try again or check device storage.';

  @override
  String get currencyConversionRequired =>
      'Currency cannot be changed because financial data already exists. A dedicated migration or conversion is required.';

  @override
  String get currency => 'Currency';

  @override
  String get currencyMismatch =>
      'Amount currency differs from the store currency.';

  @override
  String get currencyScaleHelp =>
      'IDR uses whole rupiah. USD, MYR and EUR use two decimals. Language does not change currency.';

  @override
  String get rupiahCurrency => 'IDR · Indonesian rupiah';

  @override
  String get dollarCurrency => 'USD · US dollar';

  @override
  String get ringgitCurrency => 'MYR · Malaysian ringgit';

  @override
  String get euroCurrency => 'EUR · Euro';

  @override
  String retryAfterSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return 'Try again in $_temp0.';
  }

  @override
  String expiredUnits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expired units',
      one: '1 expired unit',
    );
    return '$_temp0';
  }

  @override
  String stockSummary(int physical, int saleable, int expired) {
    return 'Physical stock $physical • Saleable $saleable • Expired $expired';
  }

  @override
  String productSummary(String price, int physical, int saleable) {
    return '$price • Stock $physical • Saleable $saleable';
  }

  @override
  String sellingPriceAmount(String amount) {
    return 'Selling price $amount';
  }

  @override
  String averageCostAmount(String amount) {
    return 'Average purchase price $amount';
  }

  @override
  String storeCodeValue(String code) {
    return 'Code $code';
  }

  @override
  String barcodeValue(String code) {
    return 'Barcode $code';
  }

  @override
  String batchUnits(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units',
      one: '1 unit',
    );
    return '$_temp0 • $date';
  }

  @override
  String stockChange(int count, String amount) {
    return '$count units • $amount';
  }

  @override
  String get stockRemainsHandleBeforeArchive =>
      'Stock remains. Record removal or a stock count before archiving.';

  @override
  String get stockDependencyBlocksReversal =>
      'Subsequent stock movements exist. Use a stock count or the appropriate removal.';

  @override
  String get batchReconciliationRequired =>
      'Batch stock does not match. Check the records.';

  @override
  String get categoryStillUsed =>
      'Category still in use. Move products to another category first.';

  @override
  String get pinAlreadyConfigured =>
      'PIN already configured. Use PIN change or recovery code.';

  @override
  String get listLoadFailed => 'Cannot load list. Try again.';

  @override
  String get loading => 'Loading…';

  @override
  String get addCategory => 'Add category';

  @override
  String get addSupplier => 'Add supplier';

  @override
  String get insufficientStock => 'Insufficient stock quantity.';

  @override
  String get insufficientSaleableStock => 'Insufficient saleable stock.';

  @override
  String get indonesianLanguage => 'ID · Bahasa Indonesia';

  @override
  String get englishLanguage => 'EN · English';

  @override
  String get m3DraftUnavailable =>
      'The basket draft is unavailable or already completed.';

  @override
  String get m3DraftChanged =>
      'The basket changed. Review it before continuing.';

  @override
  String get m3UndoExpired =>
      'Cannot undo: the time limit passed or the basket changed.';

  @override
  String get m3SaleUnavailable => 'The sale is unavailable.';

  @override
  String get m3AttemptChanged =>
      'This attempt is already saved with different details. Open the saved result.';

  @override
  String get m3AmbiguousCode =>
      'This code matches more than one product. Choose a search result.';

  @override
  String get m3OperationFailed =>
      'The operation failed. Try again; your basket remains saved.';

  @override
  String get m3SearchFailed => 'Search failed. Try typing again.';

  @override
  String get m3StockChanged => 'Stock changed. Review the basket.';

  @override
  String get m3EmptyCart => 'Add products before paying.';

  @override
  String get m3InvalidPayment =>
      'Check the payment amount. A partial payment must be above zero and below the total.';

  @override
  String get m3PricesChanged => 'Product prices changed.';

  @override
  String get m3CustomerUnavailable =>
      'The customer is unavailable. Select again.';

  @override
  String get m3CustomerRequired =>
      'A customer name is required to record debt.';

  @override
  String get m3SaleMovement => 'Sale';

  @override
  String get m3PaymentTooLarge => 'Payment cannot exceed the outstanding debt.';

  @override
  String get m3PaymentPlanChanged =>
      'Debt changed since the preview. Review a new payment allocation.';

  @override
  String get m3RecoveredSale =>
      'Saved sale recovered. This basket is already completed.';

  @override
  String get m3SaleSaved => 'Sale saved.';

  @override
  String get m3ReceiptNumber => 'Sale number';

  @override
  String get m3Customer => 'Customer';

  @override
  String get m3Paid => 'Recorded payment';

  @override
  String get m3RemainingDebt => 'Outstanding debt';

  @override
  String get m3PrintingLater =>
      'Sale saved. Receipt printing is not available yet.';

  @override
  String get m3NextSale => 'Next basket';

  @override
  String get m3PaidFull => 'Paid in full';

  @override
  String get m3PartialDebt => 'Partly on credit';

  @override
  String get m3AllDebt => 'Entirely on credit';

  @override
  String get m3PaidExplanation =>
      'Payment is recorded for the total. Handle physical money in the store.';

  @override
  String get m3PaidAmount => 'Amount paid';

  @override
  String get m3CustomerName => 'Customer name';

  @override
  String get m3PhoneOptional => 'Customer phone (optional)';

  @override
  String get m3SelectedCustomer => 'The selected customer will be used.';

  @override
  String get m3ChooseCustomer => 'Select an existing customer if appropriate.';

  @override
  String get m3NoPhone => 'No phone recorded';

  @override
  String get m3CreateSeparateCustomer =>
      'Create a new customer, even with the same name';

  @override
  String get m3ConfirmSale => 'Save sale';

  @override
  String get m3AcceptPricesExplanation =>
      'The basket still shows the accepted prices. Accept the latest prices to continue payment.';

  @override
  String get m3AcceptPrices => 'Accept latest prices';

  @override
  String get m3ClearSearch => 'Clear search';

  @override
  String get m3Available => 'Saleable stock';

  @override
  String get m3ClearCart => 'Clear basket';

  @override
  String get m3ClearCartExplanation =>
      'Remove all products from the basket? Undo is available for five seconds if the basket has not changed.';

  @override
  String get m3CartRemoved => 'Basket updated.';

  @override
  String get m3Decrease => 'Decrease quantity';

  @override
  String get m3Increase => 'Increase quantity';

  @override
  String get m3RemoveItem => 'Remove basket item';

  @override
  String get m3Quantity => 'Product quantity';

  @override
  String get m3SearchCustomers => 'Search customer name (Enter)';

  @override
  String get m3NoDebt => 'No outstanding debts.';

  @override
  String get m3LoadMore => 'Load more';

  @override
  String get m3PaymentPreview => 'Debt payment details';

  @override
  String get m3OldestFirst => 'Payment is allocated to the oldest sales first.';

  @override
  String get m3ConfirmPayment => 'Record this payment';

  @override
  String get m3RepaymentAmount => 'Repayment amount';

  @override
  String get m3RecordPayment => 'Record payment';

  @override
  String get m3SaleHistory => 'Sale history';

  @override
  String get m3CostSnapshot => 'Stored cost of goods sold';

  @override
  String get m3LaterFeatures =>
      'Full reports, sale corrections, printing and backups are not available yet.';

  @override
  String get m31WholeQuantity => 'Enter a whole number using digits 0–9.';

  @override
  String get m31PackRequired =>
      'Fill in the box label and pcs per box, or leave both empty.';

  @override
  String get m31WholesalePositive =>
      'Wholesale price must be greater than zero. Leave empty if unavailable.';

  @override
  String get m31ConflictingInput => 'Use one input unit for this receipt.';

  @override
  String get m31WholesaleChange => 'Wholesale price change';

  @override
  String get m31WholesaleUnavailable =>
      'Wholesale price is no longer available. Choose retail or remove this line before paying.';

  @override
  String get m31Wholesale => 'Wholesale';

  @override
  String get m31WholesalePerBase =>
      'Price per pcs, applies to the entire quantity on this line.';

  @override
  String get m31UseRetail => 'Use retail price';

  @override
  String get m31WholesaleOptional => 'Wholesale price — optional';

  @override
  String get m31WholesalePrice => 'Wholesale price per pcs';

  @override
  String get m31WholesaleHelp =>
      'Empty means unavailable. The cashier selects Wholesale manually; this is not a price per box.';

  @override
  String get m31PackOptional => 'Box packaging — optional';

  @override
  String get m31PackLabel => 'Box label';

  @override
  String get m31PackSize => 'Pcs per box';

  @override
  String get m31PackConfigHelp =>
      'Packaging helps warehouse input. Changing its size does not change stock or old receipts. Sales remain in pcs.';

  @override
  String get m31InputUnit => 'Input unit';

  @override
  String get m31BaseUnit => 'Base unit (pcs)';

  @override
  String get m31PackUnit => 'Box';

  @override
  String get m31PackCount => 'Number of boxes';

  @override
  String get m31DigitsHelp =>
      'Use digits 0–9; signs, fractions and scientific notation are not accepted.';

  @override
  String get m31ReceiptOverride =>
      'May differ for this receipt/count; the product configuration stays unchanged.';

  @override
  String get m31PreviewInvalid =>
      'Enter a valid quantity and pack size to preview pcs.';

  @override
  String get m31PurchasePerPack => 'Purchase price per box';

  @override
  String get m31PriceWarning => 'Check wholesale price';

  @override
  String get m31AboveRetail =>
      'Wholesale price exceeds retail. Continue only if this is intentional.';

  @override
  String get m31BelowCost =>
      'Wholesale price is below average cost. A sale may make a loss.';

  @override
  String get m31BaseStock => 'Base-unit stock';

  @override
  String get m31Unavailable => 'Unavailable';

  @override
  String get m31Retail => 'Retail';

  @override
  String get m31ReceiptInput => 'Receipt input';

  @override
  String get m31InputPrice => 'Purchase cost per input unit';

  @override
  String get m31ReceiptValue => 'Total receipt value';

  @override
  String get m31LegacyInput =>
      'The original receipt input unit was not recorded. Stock quantity remains in base units.';

  @override
  String m31ConversionPreview(String count, String size, String total) {
    return '$count boxes × $size pcs = $total pcs';
  }

  @override
  String get m4Reports => 'Reports';

  @override
  String get m4NetSales => 'Net sales';

  @override
  String get m4GrossProfit => 'Gross profit';

  @override
  String get m4NetPayments => 'Net payments in period';

  @override
  String get m4CheckoutPayments => 'Payments at checkout';

  @override
  String get m4Repayments => 'Receivable repayments';

  @override
  String get m4UnknownPayments => 'Payments with unknown origin';

  @override
  String get m4CurrentReceivables => 'Current receivables balance';

  @override
  String get m4InventoryValue => 'Current inventory value';

  @override
  String get m4PhysicalStock => 'Current physical stock quantity';

  @override
  String get m4ExpiredStock => 'Current expired quantity';

  @override
  String get m4SalesCount => 'Sales recorded in period';

  @override
  String get m4ReturnsCount => 'Sales cancelled in period';

  @override
  String get m4SelectPeriod => 'Choose period';

  @override
  String get m4ThisMonth => 'This month';

  @override
  String get m4AllTime => 'All time';

  @override
  String get m4AllStatuses => 'All statuses';

  @override
  String get m4Active => 'Active';

  @override
  String get m4Cancelled => 'Cancelled';

  @override
  String get m4Reversal => 'Reversal';

  @override
  String get m4SaleEvent => 'Sale';

  @override
  String get m4SalesEvents => 'Sales details';

  @override
  String get m4PaymentLedger => 'Payment ledger';

  @override
  String get m4AllCustomers => 'All customers';

  @override
  String get m4CustomerFilter => 'Customer filter';

  @override
  String get m4NoCustomer => 'No customer';

  @override
  String get m4PeriodPolicy =>
      'Cancellations reduce amounts on the reversal date. Repayments are not new sales. Gross profit excludes operating expenses.';

  @override
  String get m4CurrentSnapshot =>
      'Receivables show current balances for the selected customers. Inventory shows the current whole-store position, separate from the report period.';

  @override
  String get m4ReloadStart => 'Reload from the start';

  @override
  String get m4Reconcile => 'Check records agree';

  @override
  String get m4Consistent => 'The checked records agree.';

  @override
  String get m4Inconsistent =>
      'Some records disagree. Do not correct them by deleting history.';

  @override
  String get m4StockCheck => 'Stock quantities';

  @override
  String get m4ValueCheck => 'Inventory values';

  @override
  String get m4SaleCheck => 'Sales items';

  @override
  String get m4BatchCheck => 'Batch allocations';

  @override
  String get m4PaymentCheck => 'Payment allocations';

  @override
  String get m4DebtCheck => 'Receivables balances';

  @override
  String get m4ReturnCheck => 'Returned-goods records';

  @override
  String get m4RelationsCheck => 'Record relationships';

  @override
  String get m4CancelSale => 'Cancel sale';

  @override
  String get m4CancelPayment => 'Cancel payment';

  @override
  String get m4Reason => 'Correction reason';

  @override
  String get m4GoodsReturned =>
      'All goods have actually been returned to the store.';

  @override
  String get m4MoneyHandled =>
      'Any relevant refund or money adjustment is handled in the store; the app only reverses the records.';

  @override
  String get m4CorrectionNotice =>
      'A correction adds reversal records and keeps the original transaction. Full sale cancellation is refused while a later repayment remains active.';

  @override
  String get m4ConfirmCancellation => 'Confirm cancellation';

  @override
  String get m4ReasonRequired => 'Enter a correction reason.';

  @override
  String get m4ReasonTooLong => 'The reason may contain up to 500 characters.';

  @override
  String get m4ConfirmMoney =>
      'Confirm how the money is handled in the store first.';

  @override
  String get m4ConfirmGoods =>
      'A full cancellation requires all goods to have actually been returned.';

  @override
  String get m4AlreadyCancelled =>
      'This record has already been cancelled. Reload to see the result.';

  @override
  String get m4ActiveRepayment =>
      'A later repayment remains active. Review and reverse that payment first if it was recorded in error; do not delete it.';

  @override
  String get m4AnonymousPayment =>
      'This payment has no customer to own the reopened debt. Use a full sale cancellation if all goods have actually been returned.';

  @override
  String get m4PaymentUnavailable =>
      'The payment is unavailable or is itself a reversal.';

  @override
  String get m4InconsistentData =>
      'Related records disagree. Check reconciliation; no correction was saved.';

  @override
  String get m4DatasetChanged => 'The data changed. Reload from the start.';

  @override
  String get m4InvalidPeriod => 'The period start must precede its end.';

  @override
  String get m4AggregateTooLarge =>
      'The report total exceeds the database integer limit. Choose a smaller period or filter.';

  @override
  String get m4LaterFeatures =>
      'Printing, notifications, backup and restore are planned for the next stage.';

  @override
  String get m5OperationFailed =>
      'Operation did not complete. Check permissions, connection, or enter your PIN again.';

  @override
  String get m5PermissionDenied =>
      'Permission not granted. In-app alerts remain available.';

  @override
  String get m5Printer => 'Bluetooth printer';

  @override
  String get m5PrinterHelp =>
      'ESC/POS over Bluetooth Classic/SPP. Iware MP-581RL usually appears as RPP02N. Calibrate the profile on real paper. Enter your PIN again after an Android permission dialog if locked.';

  @override
  String get m5Paired => 'Paired devices';

  @override
  String get m5Discover => 'Discover devices';

  @override
  String get m5Pair => 'Pair';

  @override
  String get m5PairRequested =>
      'Pairing requested from Android; check its dialog, then reload paired devices.';

  @override
  String get m5SavedPrinters => 'Saved printers';

  @override
  String get m5FirstPage => 'Load first page';

  @override
  String get m5NextPage => 'Next page';

  @override
  String get m5PrintableDots => 'Printable width (dots)';

  @override
  String get m5LeftDots => 'Left margin (dots)';

  @override
  String get m5RightDots => 'Right margin (dots)';

  @override
  String get m5ShiftDots => 'Horizontal shift (dots)';

  @override
  String get m5Feed => 'Blank space after receipt (0–8 lines)';

  @override
  String get m5TopFeed => 'Blank space before header (0–8 lines)';

  @override
  String get m5Protocol => 'Printer command language';

  @override
  String get m5ProtocolRaster => 'ESC/POS Raster (common)';

  @override
  String get m5ProtocolColumn => 'ESC/POS Column (alternative)';

  @override
  String get m5ProtocolTspl => 'TSPL (continuous paper)';

  @override
  String get m5ProtocolCpcl => 'CPCL (continuous paper)';

  @override
  String get m5ProtocolHelp =>
      'Match the printer mode or manufacturer guide, then Save. Firmware mode is not changed automatically. TSPL/CPCL use continuous paper at 203 dpi; match page height to the printer capability. Test print to check the paper result.';

  @override
  String get m5PageRows => 'Maximum page height (128–4096 dots)';

  @override
  String get m5TopFeedDecrease => 'Reduce blank space before header';

  @override
  String get m5TopFeedIncrease => 'Increase blank space before header';

  @override
  String get m5FeedDecrease => 'Reduce blank space after receipt';

  @override
  String get m5FeedIncrease => 'Increase blank space after receipt';

  @override
  String get m5GeometryHelp =>
      '203 DPI: 8 dots is about 1 mm. Paper width differs from printable width. Keep shifts within the safe area; the OpenLabel -4 mm setting is not a universal default. Edit header/footer in store settings.';

  @override
  String get m5Bold => 'Bold text';

  @override
  String get m5Logo => 'Print logo when available';

  @override
  String get m5HeaderAlign => 'Header alignment';

  @override
  String get m5FooterAlign => 'Footer alignment';

  @override
  String get m5AlignLeft => 'Left';

  @override
  String get m5AlignCenter => 'Center';

  @override
  String get m5AlignRight => 'Right';

  @override
  String get m5ResetTemplate => 'Reset profile template';

  @override
  String get m5Preview => 'Preview';

  @override
  String get m5ProfileInvalid =>
      'Invalid template geometry or size. Check printable area and margins.';

  @override
  String get m5PrinterSaved => 'Printer profile saved.';

  @override
  String get m5TestPrint => 'Print UJI COBA';

  @override
  String get m5ForgetPrinter => 'Forget in this app';

  @override
  String get m5PrinterForgotten => 'Printer binding removed from this app.';

  @override
  String get m5Disconnect => 'Disconnect';

  @override
  String get m5Disconnected => 'Disconnected.';

  @override
  String get m5PrintReceipt => 'Print receipt';

  @override
  String get m5PrintCopy => 'Print SALINAN';

  @override
  String get m5DataSent => 'Data sent. Check the printed paper.';

  @override
  String get m5DeliveryUnknown =>
      'Delivery is uncertain. Check the printer first; print SALINAN only if needed.';

  @override
  String get m5NotSent =>
      'Data was not sent. Check the printer and connection.';

  @override
  String get m5PrintPrepared => 'Print job prepared.';

  @override
  String get m5PrintSetupRequired =>
      'Printer is not ready. Open Printer settings. The sale remains saved.';

  @override
  String get m5ScanCancelled => 'Discovery cancelled.';

  @override
  String get m5ScanTimedOut =>
      'Discovery timed out; discovered devices are shown.';

  @override
  String get m5ScanFinished => 'Discovery finished.';

  @override
  String get m5Alerts => 'Inventory alerts';

  @override
  String get m5AlertsHelp =>
      'Stock alerts follow each product’s minimum. Expiry uses remaining batches and the shop calendar. Notifications are best effort; tap to open the protected list with your PIN.';

  @override
  String get m5ExpiryDays => 'Days before expiry (0–365)';

  @override
  String get m5Notifications => 'Enable inventory notifications';

  @override
  String get m5SettingsSaved => 'Settings saved.';

  @override
  String get m5NoAlerts => 'No active alerts.';

  @override
  String get m5Expiry => 'Expiry';

  @override
  String get m5Saleable => 'Saleable stock';

  @override
  String get m5Minimum => 'Minimum';

  @override
  String get m5Backup => 'Backup & Google Drive';

  @override
  String get m5BackupHelp =>
      'Backups contain shop data and logo in an encrypted archive. Export with the Android file picker to keep a copy outside the app. Restore replaces all active data. After an Android dialog, enter your PIN again to continue.';

  @override
  String get m5RecoveryConfigured => 'Backup recovery code is configured.';

  @override
  String get m5RecoveryRequired =>
      'Set up and save a recovery code before creating a backup.';

  @override
  String get m5GenerateCode => 'Set up a new code';

  @override
  String get m5ShowCode => 'Show saved code';

  @override
  String get m5CopyCode => 'Copy to clipboard';

  @override
  String get m5CodeCopied => 'Recovery code copied without spaces or hyphens.';

  @override
  String get m5CodeCopyFailed =>
      'Code was not copied. Show the complete code and retry while the app is active.';

  @override
  String get m5RecoveryCodeHelp =>
      'This code differs from your PIN and PIN recovery. Keep a private copy outside the device. Older backups still need the code used when created; a lost code cannot be derived from your PIN.';

  @override
  String get m5ConfirmRecoveryCode => 'Enter the code you saved';

  @override
  String get m5CodeStored =>
      'I have saved a copy of this code where I can retrieve it.';

  @override
  String get m5SaveRecoveryCode => 'Confirm and save code';

  @override
  String get m5LocalBackups => 'Encrypted local backups';

  @override
  String get m5CreateBackup => 'Create local backup';

  @override
  String get m5Export => 'Export file';

  @override
  String get m5SelectRestore => 'Select for restore';

  @override
  String get m5Restore => 'Restore backup';

  @override
  String get m5ChooseArchive => 'Choose archive from files';

  @override
  String get m5ArchiveSelected =>
      'Archive selected. Enter your PIN again if prompted, then validate with that archive’s recovery code.';

  @override
  String get m5RecoveryCode => 'Backup recovery code';

  @override
  String get m5ValidateArchive => 'Validate archive';

  @override
  String get m5RestoreWarning =>
      'All active data, including local drafts, will be replaced by the backup. An encrypted safety backup must succeed first. After restore, use the selected backup’s PIN. Reconfigure Google, automatic backups, notifications, and printer bindings; nothing prints automatically.';

  @override
  String get m5ReplaceAndDrafts =>
      'I agree to replace all active data and local drafts with the selected backup.';

  @override
  String get m5RestoreFinalConfirmation => 'Proceed with full restore now?';

  @override
  String get m5Confirm => 'Confirm';

  @override
  String get m5GoogleDrive => 'Optional Google Drive';

  @override
  String get m5DriveHelp =>
      'Uses only the app data folder in the selected account. This does not synchronize stock. Manual upload sends an encrypted archive; automation requires separate consent. Seven successful backups are retained per shop and installation origin. OAuth Testing may require authorization again after about seven days.';

  @override
  String get m5TargetAccount => 'Target account';

  @override
  String get m5ChooseAccount => 'Choose or switch Google account';

  @override
  String get m5PendingAccount => 'Account choice not yet saved';

  @override
  String get m5UseAccount => 'Use this account';

  @override
  String get m5AutomaticBackup => 'Automatic Drive backup';

  @override
  String get m5AutomaticBackupHelp =>
      'Targets 21:00 in the shop timezone, best effort. Network, Doze, and device restrictions can delay it; execution after force-stop is not guaranteed.';

  @override
  String get m5AutomaticConsent =>
      'Allow automatic upload of encrypted shop archives to the displayed target account?';

  @override
  String get m5UploadNow => 'Back up to Drive now';

  @override
  String get m5DriveVersions => 'Drive backup versions';

  @override
  String get m5Refresh => 'Refresh status';

  @override
  String get m5CodeSaved => 'Backup recovery code saved.';

  @override
  String get m5LocalBackupReady =>
      'Validated local backup is ready. Export it to keep a copy outside the app.';

  @override
  String get m5ExportVerified =>
      'Export file was written and read back successfully.';

  @override
  String get m5Cancelled => 'Cancelled.';

  @override
  String get m5ArchiveValidated =>
      'Archive authenticated and data validated. Review metadata before restore.';

  @override
  String get m5RestoreComplete =>
      'Restore completed. Use the backup’s PIN to open Management.';

  @override
  String get m5RestoreOutcomeCheck =>
      'Restore could not be confirmed complete. Active storage was reopened; check its status and shop contents before continuing.';

  @override
  String get m5AccountPending =>
      'Account choice is ready. Enter your PIN again, then confirm the target account.';

  @override
  String get m5AccountConnected =>
      'Target account saved. Automatic backup remains off.';

  @override
  String get m5DriveBackupReady => 'Drive archive upload verified.';

  @override
  String get m5DriveNeedsAuth =>
      'Google needs authorization again. Choose the account on this screen; workers do not open login dialogs.';

  @override
  String get m5DriveConsentChanged =>
      'Operation stopped because the account or consent changed.';

  @override
  String get m5DriveAccountMismatch =>
      'Account identity does not match. Choose and confirm the target account again.';

  @override
  String get m5DriveQuota => 'Google Drive storage quota is insufficient.';

  @override
  String get m5DriveOffline => 'Network unavailable or timed out. Try again.';

  @override
  String get m5DriveFailed =>
      'Drive operation is incomplete. Check network, authorization, and account configuration.';

  @override
  String get m5DriveApiNotEnabled =>
      'Google Drive API is not enabled or has been disabled in the app\'s Google Cloud project. Enable it in the project that owns the OAuth clients, then retry.';

  @override
  String get m5DriveForbidden =>
      'Google Drive denied access. Check the app\'s Drive data permission and Google Cloud project configuration. Being listed as a test user alone does not guarantee API access.';

  @override
  String get m5ArchiveRejected =>
      'Code or archive is invalid, damaged, or unreadable. Active data was not replaced.';

  @override
  String get m5CodeRotationWarning =>
      'A new code applies to future backups. Keep the old code for existing backups. Continue?';

  @override
  String get m5DatabaseKeyMissing =>
      'Installation database key is missing. Files are retained; no empty database was created. Use a verified backup on another installation or investigate key recovery.';

  @override
  String get m5DatabaseKeyUnavailable =>
      'Keystore could not unlock the database key. Existing files are retained.';

  @override
  String get m5DatabaseUnlockFailed =>
      'Database could not be opened with the installation key. Files are retained; check backups and storage status.';

  @override
  String get m5EncryptedExportFailed =>
      'Encrypted export failed. Source data is retained.';

  @override
  String get m5DatabaseInUse =>
      'Database is still in use. Wait for other operations to finish, then retry.';

  @override
  String get m5PrintSending => 'Sending print data';

  @override
  String get m5BackupRunning => 'Running';

  @override
  String get m5BackupFailed => 'Failed';

  @override
  String get m5BackupSuccess => 'Succeeded';

  @override
  String get m5ChooseLogo => 'Choose shop logo';

  @override
  String get m5ApplyLogo => 'Apply selected logo';

  @override
  String get m5RemoveLogo => 'Remove shop logo';

  @override
  String get m5ReceiptPreview => 'Receipt preview';

  @override
  String get m5HideCode => 'Hide recovery code';

  @override
  String get m5LastAutomaticFailure =>
      'Last automatic attempt failure on this device';

  @override
  String get m5AutomaticFailureHistoryHelp =>
      'This is a device record and may refer to a previous destination account.';

  @override
  String get m5LastAttempt => 'Last backup attempt';

  @override
  String get m5LastSuccess => 'Last successful backup';

  @override
  String get m5NextTarget => 'Next backup target (shop time)';

  @override
  String get m5NotScheduled => 'Not scheduled';

  @override
  String get m5RunRunning => 'In progress';

  @override
  String get m5RunCompleted => 'Verified complete';

  @override
  String get m5RunFailed => 'Failed; not a successful backup';

  @override
  String get m5RunUnknown => 'Status needs review';

  @override
  String get m5RestoreContents => 'Archive contents and shop identity';

  @override
  String get m5RestoreCurrent => 'Current shop';

  @override
  String get m5LogoSize => 'Logo size within printable area';

  @override
  String get m5LineGap => 'Line spacing';

  @override
  String get m5DatabaseNewerSchema =>
      'This database requires a newer app version. Use a compatible version; data was not replaced.';

  @override
  String get m5CopyWarning =>
      'Check any paper already printed. Sent data does not confirm printing, and reprinting can produce duplicates. Continue as SALINAN (copy)?';

  @override
  String get m5OpenSourceLicenses => 'Open source licenses';

  @override
  String get m5Connect => 'Connect';

  @override
  String get m5Connecting => 'Connecting printer…';

  @override
  String get m5Connected => 'Connected to printer';

  @override
  String get m5ConnectionFailed =>
      'Printer connection failed. Check the printer and try again.';

  @override
  String get m5ConnectionNotChecked =>
      'Printer connection has not been checked';

  @override
  String get m5CheckConnection => 'Check connection';

  @override
  String get m5BluetoothUnavailable =>
      'Bluetooth is unavailable on this device';

  @override
  String get m5BluetoothDisabled =>
      'Bluetooth is off. Enable it in device settings.';

  @override
  String get m5BluetoothPermissionHelp =>
      'Nearby devices permission (location on older Android) is needed when using the printer. If the permission dialog no longer appears, check app permissions in Android Settings.';

  @override
  String get driveRetryLimitReached =>
      'Automatic backup stopped after three failed attempts. Check the connection and try a manual backup. The next daily schedule remains active.';

  @override
  String get m5PrinterPermissionDenied =>
      'Bluetooth permission is not granted. Allow Nearby devices (Location on older Android) in this app’s Android settings, then try again.';

  @override
  String get m5ExportNameTitle => 'Export file name';

  @override
  String get m5ExportNameLabel => 'File name';

  @override
  String get m5ExportNameHelp =>
      'The .kasirbackup extension is added automatically. Choose a location next.';

  @override
  String get m5ExportNameInvalid =>
      'Invalid name. Avoid path separators and special characters; maximum 128 characters including the extension.';

  @override
  String get m5ExportChooseLocation => 'Continue';

  @override
  String get m5DriveArchiveList => 'Destination account Drive archives';

  @override
  String get m5DriveArchiveEmpty => 'No Drive archives on this page.';

  @override
  String get m5RunHistoryTitle => 'Backup history on this device';

  @override
  String get m5RunHistoryHelp =>
      'Drive upload records for all accounts on this device. Retention may remove older archives; history is retained.';

  @override
  String get m5RunCurrentAccount => 'Current destination account';

  @override
  String get m5RunOtherAccount => 'Another or previous destination account';

  @override
  String get m5RunUnknownAccount => 'Destination account not recorded';

  @override
  String get m51Attributes => 'Optional product attributes';

  @override
  String get m51Size => 'Weight / volume';

  @override
  String get m51SizeHelp => 'Up to 3 decimals, no grouping. Example: 0.5';

  @override
  String get m51Unit => 'Size unit';

  @override
  String get m51NoUnit => 'No unit';

  @override
  String get m51Liter => 'liter';

  @override
  String get m51Shelf => 'Shelf location';

  @override
  String get m51Note => 'Product note';

  @override
  String get m51AttributesHelp =>
      'Size is descriptive; stock stays in pcs. Shelf: 80 characters; note: 1,000. Clear both value and unit to remove size.';

  @override
  String get m51AttributesInvalid =>
      'Enter a positive size with its unit (up to 3 decimals, no grouping). Check shelf 80 and note 1,000 character limits.';

  @override
  String get m51Security => 'Management security';

  @override
  String get m51FreshAuthentication => 'Fresh authentication required';

  @override
  String get m51FreshAuthenticationRequired =>
      'Authenticate again to approve this sensitive action.';

  @override
  String get m51SystemOperationPending =>
      'Complete or cancel the current system dialog.';

  @override
  String get m51UseAppPin => 'Use app PIN';

  @override
  String get m51UseBiometric => 'Use strong biometrics';

  @override
  String get m51BiometricUnavailable =>
      'Class 3 biometrics are unavailable or not enrolled. Use the app PIN.';

  @override
  String get m51BiometricCancelled =>
      'Biometric authentication cancelled. You can use the app PIN.';

  @override
  String get m51BiometricLockout =>
      'Android has locked biometric authentication. Use the app PIN or try later.';

  @override
  String get m51BiometricInvalidated =>
      'Biometric binding changed. Use the app PIN and enable it again if desired.';

  @override
  String get m51BiometricHelp =>
      'Optional, Class 3 only. Every enrolled device biometric can authenticate; the app cannot identify individual owners or staff. App PIN remains available. Re-enable with PIN after enrollment changes or restore.';

  @override
  String get m51SessionPolicy => 'Management session policy';

  @override
  String get m51CurrentPolicy => 'Effective policy';

  @override
  String get m51LegacyPolicy =>
      'Legacy default retained: lock on minimize, 5-minute idle limit.';

  @override
  String get m51SessionImmediate => 'Lock immediately on minimize';

  @override
  String get m51Session1 => '1 minute idle';

  @override
  String get m51Session5 => '5 minutes idle';

  @override
  String get m51Session15 => '15 minutes idle';

  @override
  String get m51SessionHelp =>
      'Timed choices include background inactivity; returning does not extend the session. Immediate lock also has a 5-minute idle limit. App dialogs are bounded to 60 seconds; full file/account pickers may require PIN once on return. Screen lock, restart, manual lock, PIN changes and restore invalidate access. Cashier stays open. Grace is a convenience choice retaining temporary access.';

  @override
  String get m51PrintRecovery => 'Print recovery code';

  @override
  String get m51RecoveryPrintWarning =>
      'The paper contains a secret that unlocks backups. Check that you own this destination, collect the paper and store it separately from archives/the device. Printer transport and memory are not guaranteed confidential. There is no automatic retry.';

  @override
  String get m51RecoveryPrintStoredOnly =>
      'Prints the saved code. For a new or rotated code, confirm and save it first; printing is optional.';

  @override
  String get m51RecoveryPrinterRequired =>
      'Select and save a printer profile in printer settings first.';

  @override
  String get m51RecoveryPrinterChanged =>
      'The printer profile changed. Check and confirm the destination again.';

  @override
  String get m51RecoveryPrintSubmitted =>
      'Print data submitted. Check the paper and all 64 characters; submitted bytes do not prove complete paper output.';

  @override
  String get m51RecoveryPrintNotSent =>
      'The code was not sent. Check the printer/connection. Reprinting requires new authentication and confirmation.';

  @override
  String get m51RecoveryPrintUnknown =>
      'Print outcome is uncertain; part of the code may be on paper. No automatic retry. Secure the paper, check the printer, then authenticate again if choosing to reprint.';

  @override
  String get m51RecoveryPaperStored =>
      'I checked the entire code on paper and stored my copy privately.';

  @override
  String get m51ConfirmPaperStored => 'Record copy storage confirmation';

  @override
  String get m51RecoveryCopyStored =>
      'Copy storage confirmation recorded without retaining its contents.';

  @override
  String get m51PrinterTitle => 'Bluetooth / USB printer';

  @override
  String get m51UsbHelp =>
      'USB OTG needs USB Host, a data cable, power and an ESC/POS USB printer-class device. Select a device before granting access. Vendor USB serial is not supported. Avoid unplugging during output; failed delivery never retries automatically.';

  @override
  String get m51UsbLoad => 'Load USB devices';

  @override
  String get m51UsbEmpty =>
      'No supported class 7/1 USB printer detected. Check OTG, data cable and power.';

  @override
  String get m51UsbSelect =>
      'Select a USB printer, then Connect to request access to that device only.';

  @override
  String get m51UsbTemporary =>
      'Temporary identity: a printer without a unique serial must be reselected after detach or app restart. An old profile never automatically connects to a similar printer.';

  @override
  String get m51UsbUnavailable =>
      'USB Host unavailable. Cashier and Bluetooth remain usable.';

  @override
  String get m51UsbPermissionDenied =>
      'USB permission was denied or interrupted. Re-enter the app PIN if locked. Use Retry USB permission only to request it explicitly.';

  @override
  String get m51UsbRetryPermission => 'Retry USB permission';

  @override
  String get m51UsbSelectAgain =>
      'USB printer detached, changed identity or is ambiguous. Reload and reselect; no automatic reprint.';

  @override
  String get m51UsbBusy =>
      'USB interface is busy or cannot be claimed without displacing a driver. Close other app connections, then retry explicitly.';

  @override
  String get m51UsbFailed =>
      'USB operation failed. Check power, OTG, data cable, permission and printer compatibility. No automatic reprint.';

  @override
  String get m51Tender => 'Cash received';

  @override
  String get m51Applied => 'Payment applied';

  @override
  String get m51Change => 'Change';

  @override
  String get m51Numpad => 'Numpad';

  @override
  String get m51QuickCash => 'Quick cash';

  @override
  String get m51ExactCash => 'Exact amount';

  @override
  String get m51TenderRequired =>
      'Enter cash received, choose Exact amount, or explicitly choose All debt.';

  @override
  String get m51Backspace => 'Backspace';

  @override
  String get m51ClearTender => 'Clear amount';

  @override
  String get m51ConfirmTender => 'Confirm amount';

  @override
  String get m51QuickSettings => 'Quick cash amounts';

  @override
  String get m51ResetQuick => 'Reset defaults';

  @override
  String get m51Export => 'Export report';

  @override
  String get m51ExportPolicy =>
      'Export the full selected period and customer filter. Inventory and receivables are current snapshots, not historical positions. Files contain store data. UTF-8 CSV: import barcodes, IDs and amounts as text to preserve precision; formula-like text is prefixed with an apostrophe. Not an official tax form.';

  @override
  String get m51ExportRows => 'Rows prepared';

  @override
  String get m51ExportCreate => 'Prepare and choose destination';

  @override
  String get m51ExportSelected =>
      'Destination selected. Re-enter PIN if requested, then press Write file. Destination expires in two minutes.';

  @override
  String get m51ExportWrite => 'Write file';

  @override
  String get m51ExportVerified =>
      'Report written and verified by reading it back.';

  @override
  String get m51ExportFailed =>
      'Export did not complete. Check PIN session, storage and destination. Select again if the destination expired.';

  @override
  String get m51MaintenancePolicy =>
      'Space maintenance is scheduled after a valid backup, while idle and charging. It skips low benefit, busy operations or insufficient storage. History is never deleted.';

  @override
  String get m51MaintenanceStatus => 'Space maintenance';

  @override
  String get m51MaintenanceAttempt => 'Last attempt';

  @override
  String get m51MaintenanceSuccess => 'Last success';

  @override
  String get m51Space_databaseBusy =>
      'Database is in use; maintenance was skipped.';

  @override
  String get m51Space_none => 'Not scheduled';

  @override
  String get m51Space_pending => 'Waiting for idle conditions';

  @override
  String get m51Space_running => 'Running';

  @override
  String get m51Space_success => 'Successful';

  @override
  String get m51Space_skipped => 'Skipped';

  @override
  String get m51Space_error => 'Did not complete';

  @override
  String get m51Space_cooldown => 'Maintenance cooldown is active.';

  @override
  String get m51Space_interrupted =>
      'Previous process was interrupted; waiting for the next valid backup.';

  @override
  String get m51Space_lowBenefit => 'Reclaimable space is below the threshold.';

  @override
  String get m51Space_insufficientSpace => 'Insufficient temporary space.';

  @override
  String get m51Space_deviceInUse => 'Device is in use or not charging.';

  @override
  String get m51Space_compacted => 'Database compacted and integrity verified.';

  @override
  String get m51Space_maintenanceFailed =>
      'Maintenance failed. The previous valid backup remains available.';

  @override
  String get m52PayAll => 'Pay full balance';

  @override
  String get m52PhoneInvalid =>
      'Invalid phone number for this country. Use digits and an optional leading +.';

  @override
  String get m52EmailInvalid => 'Invalid email format.';

  @override
  String get m52WebsiteInvalid =>
      'Enter a domain or http/https URL with a valid host.';

  @override
  String get m52InitialQuantityLimit =>
      'Initial quantity must be 0–999999 base units, at most six digits.';

  @override
  String get m52PurchaseAboveRetail =>
      'Purchase cost per unit must not exceed the retail selling price.';

  @override
  String get m52WholesaleAboveRetail =>
      'Wholesale price must not exceed the retail selling price.';

  @override
  String get m52ReferenceCostRequired =>
      'Enter the reference purchase cost per unit, including an explicit zero if free.';

  @override
  String get m52ShelfDuplicate => 'This shelf name/code already exists.';

  @override
  String get m52UnsavedTitle => 'Unsaved changes';

  @override
  String get m52UnsavedBody =>
      'There are unsaved changes. Going back now will discard changes to this form. Continue?';

  @override
  String get m52KeepEditing => 'Continue editing';

  @override
  String get m52Discard => 'Go back without saving';

  @override
  String get m52PromoInvalid =>
      'Select a product and name, a positive minimum quantity and a discount of 0.01–100%.';

  @override
  String get m52PromoConflict =>
      'This product already has an active promotion. Disable the old promotion first.';

  @override
  String get m52Untracked => '999 — Fictitious stock (not tracked)';

  @override
  String get m52UntrackedNote =>
      'Initial quantity is empty. The system will store fictitious stock 999 because this product is not tracked. This is not a real quantity and is excluded from inventory value.';

  @override
  String get m52StockOperationRequiresTracking =>
      'Physical inventory operations require stock tracking.';

  @override
  String get m52StockTransition =>
      'Reconcile physical stock and batches before changing tracking mode.';

  @override
  String get m52ReferenceCost =>
      'Reference purchase cost per unit (not tracked)';

  @override
  String get m52Tracked => 'Stock tracked';

  @override
  String get m52CostSource => 'Cost basis';

  @override
  String get m52Promo => 'Retail quantity promotion';

  @override
  String get m52PromoName => 'Promotion name';

  @override
  String get m52PromoMinimum => 'Minimum base-unit quantity';

  @override
  String get m52PromoPercent => 'Discount (%)';

  @override
  String get m52PromoActive => 'Active';

  @override
  String get m52PromoArchive => 'Archive this promotion?';

  @override
  String get m52Gross => 'Gross amount';

  @override
  String get m52Discount => 'Discount';

  @override
  String get m52PromoLoss =>
      'The promoted price is below cost. Review the margin before enabling it.';

  @override
  String get m52Shelf => 'Shelf (optional)';

  @override
  String get m52Shelves => 'Add / edit shelves';

  @override
  String get m52ShelfName => 'Shelf code/name';

  @override
  String get m52Email => 'Email (optional)';

  @override
  String get m52Website => 'Website (optional)';

  @override
  String get m52PhoneRegion => 'Local phone region (ISO code, e.g. ID)';

  @override
  String get m52DateTomorrow =>
      'A new date must be tomorrow or later in the device calendar.';

  @override
  String get m52LowPriceTitle => 'Review low price';

  @override
  String get m52LowPriceBody =>
      'This price is low for this currency. Review the amount. Save anyway?';

  @override
  String get m52Review => 'Review again';

  @override
  String get m52SaveAnyway => 'Save anyway';

  @override
  String get m52SuppressLowPrice =>
      'Do not show the low-price warning again for this currency in this shop';

  @override
  String get m52LowPriceSettings => 'Low-price warning preferences';

  @override
  String get m52Threshold => 'Low-price threshold';

  @override
  String get m52PaperWidth => 'Paper width';

  @override
  String get m52IwareFeed => 'Try Iware 58: 3 feed lines (this profile only)';

  @override
  String get m52FeedHelp =>
      'Enter the number of lines or use −/+. 0 adds no extra blank space. Press Save for this printer. Line length varies by printer; the printhead-to-tear distance remains.';

  @override
  String get m52BatteryHelp =>
      '21:00 backup is a best-effort target. Battery/background restrictions can delay it. On HyperOS, No restrictions (if available) may help without guaranteeing timing. Scheduling cannot be relied on after force-stop.';

  @override
  String get m52AppSettings => 'Open App info / battery settings';

  @override
  String get m52UntrackedCount => 'Products without stock tracking';

  @override
  String get m52TrackingChange => 'Change stock tracking mode';

  @override
  String get m52TrackedOpening =>
      'Enable tracking with an actual opening quantity (enter 0 if empty) and purchase cost per unit. Past sales retain their original mode and cost.';

  @override
  String get m52ContactOpenFailed =>
      'Cannot open this destination. Check the number/address and the device\'s WhatsApp/browser app.';

  @override
  String get add => 'Add';

  @override
  String get delete => 'Delete';

  @override
  String get m52LowPriceThreshold =>
      'The low-price threshold must not be negative.';

  @override
  String get m53Features => 'Features and stock tracking';

  @override
  String get m53StockMode => 'Store stock tracking';

  @override
  String get m53Stockoff => 'Do not track stock';

  @override
  String get m53Stockpartial => 'Track selected products';

  @override
  String get m53Stockall => 'Track all products';

  @override
  String get m53TrackThisProduct => 'Track stock for this product';

  @override
  String get m53StockHelp =>
      'Untracked stock does not show the quantity in the store and does not decrease after a sale. Check availability. For tracked stock, record receipts, sales, returns and corrections to match physical stock. Record or reconcile sales made outside the app. Reconcile conflicting products before changing the store mode.';

  @override
  String get m53PolicyPreview => 'Review changes';

  @override
  String get m53PolicyImpact =>
      'Products requiring reconciliation before changing mode';

  @override
  String get m53PreserveFeatures =>
      'Hiding a feature preserves stored wholesale prices, packaging, barcodes, dates and history. Sale eligibility rules still apply.';

  @override
  String get m53WholesaleHelp =>
      'Configure wholesale prices per product. Enabling this feature does not assign wholesale prices automatically.';

  @override
  String get m53BarcodeHelp =>
      'Use barcodes with a supported camera or external scanner. Products without barcodes can use automatic internal codes.';

  @override
  String get m53ExpiryHelp =>
      'Dates and batches help with reminders and sale eligibility. Check physical condition. Hiding these inputs does not erase dates or make expired stock saleable.';

  @override
  String get m53PolicyChanged =>
      'Settings changed. Reopen to review the latest data.';

  @override
  String get m53StockReconciliationRequired =>
      'Some products conflict with this stock mode. Reconcile them using product tracking changes, then review again. No balances were changed.';

  @override
  String get m53StockModeConflict =>
      'Product tracking conflicts with the store policy. Reload settings and choose a compatible mode.';

  @override
  String get m53InitialQuantityRequired =>
      'Enter an explicit initial quantity, including 0 if there is no stock.';

  @override
  String get m53PinRequired72Hours =>
      'Use the app PIN to unlock management. A PIN is required again after 72 hours; biometrics do not restart this interval.';

  @override
  String get m53RoleSetupRequired =>
      'Changing task assignments requires the corresponding PIN and access setup.';

  @override
  String get m53UnknownCostPending =>
      'This setting requires explicit unknown-cost accounting. Existing costs are preserved.';

  @override
  String get m53OwnerRequired =>
      'Owner/Reports access is required for this action.';

  @override
  String get m53WarehouseNotConfigured =>
      'Warehouse access has not been configured for this task pattern.';

  @override
  String get m53PinsMustDiffer =>
      'Warehouse and Owner/Reports PINs must differ.';

  @override
  String get m53ChooseAccess => 'Choose the access to unlock';

  @override
  String get m53OwnerRole => 'Owner/Reports';

  @override
  String get m53WarehouseRole => 'Warehouse';

  @override
  String get m53TaskPattern => 'How is your store managed?';

  @override
  String get m53TaskHelp =>
      'These are task and access patterns on the same app/device, not employee limits or personal accounts. Changes revoke existing management sessions.';

  @override
  String get m53Pattern1 => '1 — Owner handles checkout and management';

  @override
  String get m53Pattern2 => '2 — Cashier and manager';

  @override
  String get m53Pattern3 => '3 or more — Separate responsibilities';

  @override
  String get m53WarehousePinHelp =>
      'All products must be tracked. Reconcile untracked products before selecting this pattern. The Warehouse PIN must differ from the Owner/Reports PIN. Biometrics are for Owner/Reports only; device biometrics do not prove an employee role. The owner can reset the Warehouse PIN on this page.';

  @override
  String get m53WarehousePin => 'Create Warehouse PIN';

  @override
  String get m53ZeroCostConfirmation =>
      'Confirm that this purchase is intentionally free before recording zero cost.';

  @override
  String get m53ValuationQuantityMismatch =>
      'Cost reconciliation quantity must match the confirmed stock quantity.';

  @override
  String get m53LockedUnsavedBody =>
      'There are unsaved management changes. Stay on the locked screen, or discard the changes and return to the cashier. Authenticate with the appropriate access to resume editing.';

  @override
  String get m53StayLocked => 'Stay on locked screen';

  @override
  String get m53DiscardToCashier => 'Discard and return to cashier';
}
