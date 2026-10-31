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
  String get m53Ons => 'ons (100 g)';

  @override
  String get m53LastPurchaseReminder =>
      'This price comes from the last purchase. Check and change it if the current price differs.';

  @override
  String get m53ReceiptReferenceHint =>
      'Reference cost, not the last purchase price. Check the current price.';

  @override
  String get m53ReceiptUnknownHint =>
      'The last purchase price is unknown. Enter the current price.';

  @override
  String get m53ReceiptInexactHint =>
      'The previous price cannot be entered exactly in this unit. Enter the current price or change the unit.';

  @override
  String get m53ReceiptOriginalPack => 'Pack size on the previous purchase';

  @override
  String get m53ReceiptQuantityInvalid =>
      'Enter a whole received quantity greater than 0.';

  @override
  String get m53ReceiptPackInvalid => 'Enter a whole pack size greater than 0.';

  @override
  String get m53ReceiptCostRequired =>
      'Enter the purchase price for the selected unit.';

  @override
  String get m53ReceiptCostInvalid =>
      'Enter a valid purchase price for the selected unit.';

  @override
  String get m53WarehouseChanged =>
      'Warehouse data or date changed. Reload the list.';

  @override
  String get m53WarehouseStockFilter => 'Stock condition';

  @override
  String get m53WarehouseAll => 'All conditions';

  @override
  String get m53WarehouseExpired => 'Expired stock / reference date';

  @override
  String get m53WarehouseEmpty => 'Tracked stock is empty';

  @override
  String get m53WarehouseRelations =>
      'Filter category, shelf and master supplier';

  @override
  String get m53WarehouseReferenceExpired =>
      'Expired reference date; physical quantity is not tracked';

  @override
  String get m53MasterSupplierHelp =>
      'The optional master supplier groups products. Each receipt records its own transaction supplier.';

  @override
  String get m53CategoryLongPress =>
      'Long-press to rename a category; an edit button is also available.';

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

  @override
  String get m53CostIncomplete => 'Incomplete — cost unknown';

  @override
  String get m53IncompleteSaleEvents =>
      'Sale/reversal documents with incomplete cost';

  @override
  String get m53IncompleteInventoryProducts =>
      'Stock products with incomplete value';

  @override
  String get m53CostHelp =>
      'Cost supports cost of sales, inventory value and estimated profit. Revenue is still recorded without cost; cost/profit is marked incomplete. Empty cost differs from zero cost.';

  @override
  String get m53ConfirmFreeTitle => 'Free acquisition?';

  @override
  String get m53ConfirmFreeBody =>
      'I intentionally record zero cost. These goods were acquired free of charge; their cost is not unknown.';

  @override
  String get m53ReconcileValuation => 'Reconcile entire stock value';

  @override
  String get m53ReconcileValuationHelp =>
      'Enter the total cost of the entire current physical balance and its supporting reason. Previous sale cost snapshots stay unchanged.';

  @override
  String get m53PoolTotalCost => 'Total cost of entire stock';

  @override
  String get m53ValuationHistory => 'Stock valuation history';

  @override
  String get m53TrackingClosureRequired =>
      'Review the balance and confirm ending tracking with a reason.';

  @override
  String get m53TrackingClosed =>
      'Tracking ended; the last balance was archived, not lost goods';

  @override
  String get m53TrackingChangeRecorded => 'Stock tracking change';

  @override
  String get m53TrackingHistory => 'Tracking history';

  @override
  String get m53TrackingClosureHelp =>
      'The physical goods remain. The last balance and batches are archived, then excluded from tracked stock/value. This is not a stocktake loss or cost of sales. Reopening tracking requires a new physical count.';

  @override
  String get m53HistoricalAverageReference =>
      'Use the last average cost as the per-unit reference';

  @override
  String get m53ConfirmTrackingClosure =>
      'I understand these goods are not treated as lost and confirm ending tracking for this balance';

  @override
  String get m53TrackingExpiryPreserved =>
      'The earliest date of closed batches is retained. Changing tracking does not make expired goods saleable.';

  @override
  String get m53StartPartialTransition =>
      'Start reconciliation using partial tracking';

  @override
  String get m53PartialTransitionHelp =>
      'The store will use partial tracking so each product can be reviewed. Change product tracking and enter physical counts as needed, then select the target mode here again. Balances are not changed in bulk.';

  @override
  String get m53CorrectionReasonLimit =>
      'The reason must not exceed 1000 characters.';

  @override
  String get m53CostKnowledgeCheck => 'Sale cost snapshot completeness';

  @override
  String get m53EmptyCostCheck => 'Empty stock valuation';

  @override
  String get m53SetupTitle => 'Store setup';

  @override
  String get m53SetupIdentity => 'Store identity';

  @override
  String get m53SetupSecurity => 'Management security';

  @override
  String get m53SetupFeatures => 'Visible features';

  @override
  String get m53SetupPrinter => 'Set up a receipt printer now?';

  @override
  String get m53SetupReview => 'Review setup';

  @override
  String get m53SetupStep => 'Step';

  @override
  String get m53SetupNext => 'Next';

  @override
  String get m53SetupBack => 'Previous';

  @override
  String get m53SetupFinish => 'Finish and open Cashier';

  @override
  String get m53SetupAddress => 'Address (optional)';

  @override
  String get m53SetupContact => 'WhatsApp/phone (optional)';

  @override
  String get m53SetupSelfManaged => 'I manage the store myself';

  @override
  String get m53SetupTaskHelp =>
      'These are access patterns on the same app/device, not personal employee accounts. Pattern 1: the owner handles checkout and management. Pattern 2: cashier and inventory/reports manager. Pattern 3 or more: Cashier, Warehouse and Owner/Reports are separate.';

  @override
  String get m53SetupPinHelp =>
      'The PIN protects management; Cashier stays open unless the optional cashier lock is enabled. Owner/manager biometrics can be enabled later in Security. Biometrics do not identify Warehouse staff.';

  @override
  String get m53SetupOwnerPin => 'Create Owner/Management PIN';

  @override
  String get m53SetupOwnerConfirm => 'Confirm Owner/Management PIN';

  @override
  String get m53SetupWarehouseConfirm => 'Confirm Warehouse PIN';

  @override
  String get m53SetupPreparePin => 'Save security setup';

  @override
  String get m53SetupPinsReady =>
      'Security is prepared. Raw PINs are not stored in the draft.';

  @override
  String get m53SetupRedoPin => 'Prepare PINs again';

  @override
  String get m53SetupStockRequired =>
      'Stock tracking is active for warehouse task separation.';

  @override
  String get m53SetupPrinterHelp =>
      'You can set up a printer later. Select a profile/transport, connect and try a test print on the printer page. Profiles change only after saving. Failed or cancelled printing does not block setup.';

  @override
  String get m53SetupOpenPrinter => 'Set up printer';

  @override
  String get m53SetupSkipPrinter => 'Skip';

  @override
  String get m53SetupOffline =>
      'Setup needs no internet or Google account. The initial currency is IDR; currency settings remain available in store settings.';

  @override
  String get m53SetupVisiblePin => 'Show PIN';

  @override
  String get m53SetupShowRecovery => 'Show recovery code';

  @override
  String get m53SetupDraftInvalid =>
      'The setup draft is invalid. Check the fields and try again.';

  @override
  String get m53SetupChanged =>
      'Setup progress changed. Reopen setup to load the latest progress.';

  @override
  String get m53SetupUnavailable =>
      'New-store setup is unavailable for a configured store or a store with business data.';

  @override
  String get m53SetupPinsRequired =>
      'Complete security setup and save the recovery code first.';

  @override
  String get m53SetupSaved => 'Progress is saved on this device.';

  @override
  String get m53SetupWholesale => 'Wholesale prices';

  @override
  String get m53SetupPackaging => 'Carton/box packaging';

  @override
  String get m53SetupCost => 'Purchase price/cost';

  @override
  String get m53SetupBarcode => 'Barcode';

  @override
  String get m53SetupExpiry => 'Expiry tracking';

  @override
  String get m53SetupPackagingHelp =>
      'Enter package quantity and units per package. Base stock stays in pieces; configuration changes do not alter old transactions.';

  @override
  String get m53SetupOptionalFeatures =>
      'Additional features can be enabled later in feature settings.';

  @override
  String get m53SetupSecurityHidden =>
      'Setup is hidden while the app is inactive.';

  @override
  String get m53CashierLockSettings => 'Optional cashier lock';

  @override
  String get m53CashierEnable => 'Enable cashier lock';

  @override
  String get m53CashierLockNow => 'Lock cashier';

  @override
  String get m53CashierScreenLock =>
      'Lock cashier when the device screen locks';

  @override
  String get m53CashierPinSource => 'PIN used to unlock Cashier';

  @override
  String get m53CashierOwnerReference => 'Use Owner/Management PIN';

  @override
  String get m53CashierOwnPin => 'Use a separate cashier PIN';

  @override
  String get m53CashierPin => 'Cashier PIN';

  @override
  String get m53CashierNewPin => 'New cashier PIN';

  @override
  String get m53CashierOwnerPin => 'Owner/Management PIN';

  @override
  String get m53CashierLocked => 'Cashier locked';

  @override
  String get m53CashierUnlock => 'Unlock Cashier';

  @override
  String get m53CashierUnlockHelp =>
      'Enter the cashier PIN. Unlocking Cashier does not grant management access. Your cart and tender draft are retained.';

  @override
  String get m53CashierOwnerReferenceHelp =>
      'This setting uses the Owner/Management PIN to unlock Cashier only. It does not grant management access or restart the management biometric PIN interval.';

  @override
  String get m53CashierPolicyHelp =>
      'Off by default. The owner can choose a separate cashier PIN or reference the management PIN. The Lock cashier shortcut works whenever enabled. The screen option uses Android lock/noninteractive state; permission dialogs, notifications and briefly switching apps do not by themselves lock Cashier. Cart and tender are retained.';

  @override
  String get m53CashierOwnPinHelp =>
      'A four-digit PIN is required when enabling or switching to a separate cashier PIN. While that PIN is already active, leave both fields empty to retain it. The owner can disable the lock if the cashier PIN is forgotten.';

  @override
  String get m53CashierPinRequired => 'Set up a four-digit cashier PIN first.';

  @override
  String get m53CashierForgotPin => 'Forgot cashier PIN? Owner help';

  @override
  String get m53CashierUsePin => 'Return to cashier PIN';

  @override
  String get m53CashierOwnerDisableHelp =>
      'Only the owner can disable this lock with the Owner/Management PIN. A Warehouse or cashier PIN does not grant this right. Store data is retained.';

  @override
  String get m53CashierDisableConsent =>
      'I am the owner and confirm disabling the cashier lock.';

  @override
  String get m53CashierDisable => 'Disable cashier lock';

  @override
  String get m53CashierScreenUnavailable =>
      'Automatic screen-lock detection is unavailable right now. Use the Lock cashier shortcut; the manual cashier PIN gate still applies.';

  @override
  String get m53QuickAmountsInvalid =>
      'Quick cash amounts must be positive, unique, and contain 1 to 8 values.';

  @override
  String get m53RemoveDenomination =>
      'Remove one note/coin of this denomination';

  @override
  String get m53EditQuickAmounts => 'Edit amounts';

  @override
  String get m53UnclassifiedTender => 'Amount without denomination details';

  @override
  String get m53TenderCompositionRetained =>
      'Denomination details are retained. Manually editing the amount replaces them with an amount without denomination details.';

  @override
  String get m53MemberFieldsInvalid =>
      'Enter a member name (up to 200 characters), a phone number up to 128 characters, and an address up to 4096 characters.';

  @override
  String get m53MemberPhoneRequired =>
      'A phone number is required for a new member.';

  @override
  String get m53MemberPhoneUsed =>
      'Another member already uses this number. Select the correct member or ask the owner to correct the profile.';

  @override
  String get m53MemberRepairRequired =>
      'The owner must complete this member profile before a new credit sale. Existing debts can still be paid.';

  @override
  String get m53MemberNameRequired => 'Enter the member name.';

  @override
  String get m53Members => 'Members';

  @override
  String get m53MemberName => 'Member name';

  @override
  String get m53MemberPhone => 'Member phone number';

  @override
  String get m53MemberAddress => 'Address (optional)';

  @override
  String get m53UseMember => 'Link to a member';

  @override
  String get m53MemberVisits => 'Purchases';

  @override
  String get m53MemberVisitHelp =>
      'Purchases count completed sales that have not been reversed. Debt repayments do not count as new purchases.';

  @override
  String get m53NoMembers => 'No matching members.';

  @override
  String get m53ArchivedMembers => 'Archived members';

  @override
  String get m53ArchiveMember => 'Archive member';

  @override
  String get m53RestoreMember => 'Restore member';

  @override
  String get m53MemberSelected => 'Selected member';

  @override
  String get m53ChangeMember => 'Change member / create new';

  @override
  String get m53MemberSaved => 'Member profile saved.';

  @override
  String get m53MemberSearch => 'Search name or phone number';

  @override
  String get m53MemberCreate => 'Create member';

  @override
  String get m53GuestHelp =>
      'Paid sales may use a guest. Credit sales must select or create a member.';

  @override
  String get m53MemberPhoneHelp =>
      'Use a valid, unique number. Include a country code, such as +62, if it differs from the shop phone region.';

  @override
  String get m53ArchiveMemberHelp =>
      'Archiving hides the member from new sales. History and debts remain, and existing debts can still be paid. The phone number remains linked to this profile.';

  @override
  String get m53Guest => 'Guest';

  @override
  String get m53SearchFrequent => 'Most frequently sold';

  @override
  String get m53SearchRelevance => 'Most relevant';

  @override
  String get m53SearchOrder => 'Result order';

  @override
  String get m53SearchHelpTitle => 'Product search order';

  @override
  String get m53SearchHelp =>
      'Eligible products appear first. An exact code or barcode stays first even when unavailable; unavailable products cannot be added. Most frequently sold counts completed sales containing the product in the last 30 days, then net quantity and search relevance. Cancelled sales are excluded. Multiple units in one sale still count as one sale. Debt repayments are not new sales. Only matching products appear. The snapshot refreshes after a sale/cancellation, when returning to the app, or when the next search is more than 60 seconds later. Use Refresh to update the current results.';

  @override
  String get m53SearchRefresh => 'Refresh results';

  @override
  String get m53SearchMore => 'More results';

  @override
  String get m53CashDrawer => 'Cash drawer and pieces';

  @override
  String get m53CashPolicy => 'Cash recording policy';

  @override
  String get m53CashOff => 'Off';

  @override
  String get m53CashNotes => 'Cashier notes';

  @override
  String get m53CashAudit => 'Owner required audit';

  @override
  String get m53CashAuditHelp =>
      'The owner requires piece counts for cash. Cashiers cannot disable this. Piece counts are cashier declarations, not proof of the physical cash. A difference does not automatically mean misconduct.';

  @override
  String get m53CashNotesHelp =>
      'Enable this to help record daily cash. Records remain when the date changes or recording is disabled. Close open sessions before disabling recording.';

  @override
  String get m53CashReasonRequired =>
      'Enter a reason of at most 1,000 characters.';

  @override
  String get m53CashPolicyChanged =>
      'The cash policy changed. Reload and review your choice.';

  @override
  String get m53CashCloseSessionsFirst =>
      'Close the open cash sessions before changing this policy.';

  @override
  String get m53CashAuditRequired =>
      'Recording is required by the owner and cannot be disabled by the cashier.';

  @override
  String get m53CashRecordingOff => 'Cash recording is off.';

  @override
  String get m53CashSessionChanged =>
      'The cash session, date, or settings changed. Reload and review your entries before trying again.';

  @override
  String get m53CashSessionAlreadyOpen =>
      'A cash session is already open today. Reload to view it.';

  @override
  String get m53CashPreviousUnclosed =>
      'A session from another day is still open. Review the warning before opening a new one.';

  @override
  String get m53CashClockChanged =>
      'The device time is earlier than the latest cash record. Check the device time before continuing.';

  @override
  String get m53CashOldSession =>
      'This session belongs to an earlier date or settings. A current count cannot be treated as the physical count from that time.';

  @override
  String get m53CashCountRequired =>
      'Enter the physical piece counts before closing the session.';

  @override
  String get m53CashPiecesUnavailable =>
      'The outgoing pieces are not available in the records. Recount the drawer with a reason or correct the piece details, then try again. The balance has not been reduced.';

  @override
  String get m53CashCompositionRequired =>
      'Active recording requires complete cash piece counts. An amount alone or Exact cash is insufficient.';

  @override
  String get m53CashCompositionMismatch =>
      'The piece total must exactly match the required amount. No automatic rounding is applied.';

  @override
  String get m53CashSessionRequired =>
      'Open today’s cash session and review the opening balance before recording cash.';

  @override
  String get m53CashCountInvalid =>
      'Check the piece counts. Use whole numbers from 0 to 1,000,000.';

  @override
  String get m53CashDeclarationHelp =>
      'Enter the number of pieces you observe for each denomination. The + button adds one note or coin. These are declared counts, not sensor readings.';

  @override
  String get m53CashRequiredTotal => 'Required total';

  @override
  String get m53CashClearCounts => 'Clear counts';

  @override
  String get m53CashPieceCount => 'Piece count';

  @override
  String get m53CashAddPiece => 'Add one piece';

  @override
  String get m53CashIncoming => 'Pieces received';

  @override
  String get m53CashChangeCounts => 'Change pieces';

  @override
  String get m53CashOpeningCounts => 'Opening piece count';

  @override
  String get m53CashObservedCounts => 'Current physical count';

  @override
  String get m53CashRefundCounts => 'Refund pieces';

  @override
  String get m53CashJournalCounts => 'Pieces for this entry';

  @override
  String get m53CashOpeningKnown => 'Opening balance counted';

  @override
  String get m53CashOpeningUnknown => 'Opening balance unknown';

  @override
  String get m53CashUnknownHelp =>
      'Unknown is different from empty. The expected amount is uncertain. Outgoing cash is limited to pieces already counted or recorded as received. Recount with a reason to correct the records.';

  @override
  String get m53CashOpenSession => 'Open cash session';

  @override
  String get m53CashCloseSession => 'Close cash session';

  @override
  String get m53CashRecount => 'Recount and record correction';

  @override
  String get m53CashExpected => 'Expected pieces';

  @override
  String get m53CashLowerBound => 'Minimum pieces already recorded';

  @override
  String get m53CashBalance => 'Recorded piece value';

  @override
  String get m53CashSessionDate => 'Session date';

  @override
  String get m53CashPendingDays => 'Other days have unclosed sessions';

  @override
  String get m53CashPendingHelp =>
      'A new date does not close or delete an older session. Review the new opening balance independently; an older balance is not copied automatically.';

  @override
  String get m53CashAcceptPending =>
      'I understand that another day has an unclosed session';

  @override
  String get m53CashNoSession => 'There is no open cash session for today.';

  @override
  String get m53CashSessionClosed =>
      'This session is closed. Its records and counts remain stored.';

  @override
  String get m53CashCashIn => 'Cash in excluding sales';

  @override
  String get m53CashCashOut => 'Cash out';

  @override
  String get m53CashHandover => 'Deposit or cash handover';

  @override
  String get m53CashReason => 'Reason';

  @override
  String get m53CashHistory => 'Session and journal history';

  @override
  String get m53CashDifference => 'Count difference';

  @override
  String get m53CashDifferenceHelp =>
      'A difference compares recorded cash with the declared count. It does not change sales and is not proof of theft.';

  @override
  String get m53CashOwnerException => 'Close without historical count — owner';

  @override
  String get m53CashOwnerExceptionHelp =>
      'Use this when the physical count from an older session is unavailable. The owner PIN and a reason are required. The record is marked unverified, not treated as a zero difference.';

  @override
  String get m53CashSourceDrawer => 'Cash from/to drawer';

  @override
  String get m53CashSourceExternal => 'Outside drawer / noncash';

  @override
  String get m53CashSourceUnknown => 'Legacy payment source unknown';

  @override
  String get m53CashEditReceived => 'Enter or review received pieces';

  @override
  String get m53CashCurrentSession => 'Cash session used';

  @override
  String get m53CashReviewSession => 'Review and use this session';

  @override
  String get m53CashMissingDetails =>
      'The piece details are incomplete. The previous amount is retained until you replace it.';

  @override
  String get m53CashPaymentDeclaration => 'Payment source and details';

  @override
  String get m53CashRefundPieces => 'Refund pieces';

  @override
  String get m53CashDetailsUnknown => 'Details or count unknown';

  @override
  String get m53CashPublicHistoryHelp =>
      'Cashier notes remain available here. The owner opens audit history from Management.';

  @override
  String get m53CashClosingCounts => 'Physical count at closing';

  @override
  String get m53CashReference => 'Reference';

  @override
  String get m53CashSaleAudit => 'Transaction cash details';

  @override
  String get m53CashApplied => 'Applied payment';

  @override
  String get m53CashUnclassified => 'Amount without piece details';

  @override
  String get m53CameraScan => 'Scan with camera';

  @override
  String get m53CameraHelp =>
      'Aim one code at the camera. Review the selected text and tap Use code. Tap Scan again for the next item, including the same code. A product barcode cannot prove that a physical item was scanned only once.';

  @override
  String get m53CameraUnavailable =>
      'The camera is unavailable or could not open. Use manual search or an external scanner.';

  @override
  String get m53CameraInvalidCode =>
      'The code is invalid or its format is unsupported. Use manual entry.';

  @override
  String get m53CameraPermissionDenied =>
      'Camera permission has not been granted. Manual search and external scanners remain available. You can retry after allowing camera access.';

  @override
  String get m53CameraStoreChanged =>
      'The store data was replaced. Close the scanner and reopen it from the current store.';

  @override
  String get m53CameraFeatureOff =>
      'The barcode feature is disabled in store preferences. Manual entry remains available.';

  @override
  String get m53CameraLookupFailed =>
      'The code could not be processed. Review the result and try scanning again.';

  @override
  String get m53CameraStart => 'Start camera';

  @override
  String get m53CameraScanAgain => 'Scan again';

  @override
  String get m53CameraAim => 'Camera active. Aim a code at the scan area.';

  @override
  String get m53CameraPaused =>
      'Scanning is paused until you start or scan again.';

  @override
  String get m53CameraSelectedCode => 'Selected code';

  @override
  String get m53CameraUseCode => 'Use code';

  @override
  String get m53CameraRegisterProduct => 'Register product using the form';

  @override
  String get m53CameraManualFallback =>
      'Back to manual entry / external scanner';

  @override
  String get m53CameraAdded => 'One item added to the cart.';

  @override
  String get m53CameraProductOpened =>
      'Product details opened. Stock is unchanged.';

  @override
  String get m53CameraCodeCopied =>
      'The code was filled in the form. The product has not been saved.';

  @override
  String get m53CameraEquivalentCodes =>
      'A zero-prefixed EAN-13 and UPC-A can use the same bars. Select the exact code text stored for your product; the app does not silently change it.';

  @override
  String get m53ReceiptDrafts => 'Receiving drafts';

  @override
  String get m53ReceiptDraftNew => 'New receiving draft';

  @override
  String get m53ReceiptDraft => 'Receiving draft';

  @override
  String get m53ReceiptDraftSaved => 'Draft saved. Stock has not changed.';

  @override
  String get m53ReceiptDraftNoStockYet =>
      'Scanning and editing change only the draft. Stock changes once when the entire document is confirmed. A product barcode does not identify its physical batch.';

  @override
  String get m53ReceiptDraftPosted =>
      'Receiving confirmed. Stock and history have been recorded.';

  @override
  String get m53ReceiptDraftChanged =>
      'The draft changed or is closed. Reload and review before continuing.';

  @override
  String get m53ReceiptDraftLimit =>
      'A draft supports up to 100 lines. Finish or split this document.';

  @override
  String get m53ReceiptChooseLine => 'Choose a receiving line or batch';

  @override
  String get m53ReceiptSeparateLine =>
      'Several lines could receive this code. Create a separate line, then enter the correct quantity and batch?';

  @override
  String get m53ReceiptDraftEmpty =>
      'Add at least one product before confirming.';

  @override
  String get m53ReceiptDraftCode =>
      'Exact barcode or SKU (external scanner supported)';

  @override
  String get m53ReceiptDraftAddCode => 'Add 1 base unit';

  @override
  String get m53ReceiptDraftScanAdded =>
      'One base unit added to the draft. Stock has not changed.';

  @override
  String get m53ReceiptDraftConfirm => 'Confirm receiving';

  @override
  String get m53ReceiptDraftConfirmHelp =>
      'Review every quantity, unit, pack size, cost, purchase supplier and expiry. Confirmation posts all lines together; any failed line rolls back the entire posting.';

  @override
  String get m53ReceiptDraftReview => 'Review current product data';

  @override
  String get m53ReceiptDraftReviewHelp =>
      'Refresh product and stock baselines to their current state. Draft input is retained; review prices, units and quantities before confirming again.';

  @override
  String get m53ReceiptDraftCancel => 'Cancel receiving draft';

  @override
  String get m53ReceiptDraftCancelHelp =>
      'Close this draft without changing stock? Cancelled drafts are retained as a record and cannot be edited again.';

  @override
  String get m53ReceiptRegisterUnknown =>
      'This code is not registered. Create a product with opening stock 0, then return to the draft?';

  @override
  String get m53ReceiptNewProductZero =>
      'New products for this draft use opening stock 0. Enter and confirm received quantities in the receiving document.';

  @override
  String get m53ReceiptDraftExistingCost =>
      'The cost already entered in this draft is shown so editing units or quantity does not erase it.';

  @override
  String get m53ReceiptReverseWholeDocument =>
      'This receipt belongs to a complete document. Open it and review all lines before reversing.';

  @override
  String get m53ReceiptDraftReversed =>
      'The entire receipt has been reversed; original records are retained.';

  @override
  String get m53ReceiptDraftReverse => 'Reverse this entire receipt';

  @override
  String get m53ReceiptDraftReverseHelp =>
      'This reverses every line in the document, not just one product. It is allowed only when no later stock or cost mutation depends on it. Original history is retained.';

  @override
  String get m53ReceiptDraftCancelled =>
      'Draft cancelled without posting stock.';

  @override
  String get m53ReceiptStatusPosted => 'Confirmed';

  @override
  String get m53ReceiptStatusCancelled => 'Cancelled';

  @override
  String get m53ReceiptDraftHelp => 'Using this draft';

  @override
  String get m53Stocktakes => 'Stocktake sessions';

  @override
  String get m53Stocktake => 'Stocktake';

  @override
  String get m53StocktakeNew => 'Create stocktake draft';

  @override
  String get m53StocktakeDraft => 'Saved draft · stock unchanged';

  @override
  String get m53StocktakePosted => 'Completed stocktake · snapshot saved';

  @override
  String get m53StocktakeSystem => 'System stock at baseline';

  @override
  String get m53StocktakePhysical => 'Counted physical quantity';

  @override
  String get m53StocktakeDifference => 'Physical difference';

  @override
  String get m53StocktakeUncounted => 'Not yet counted';

  @override
  String get m53StocktakeEdit => 'Edit physical count';

  @override
  String get m53StocktakeExpiry => 'Observed expiry date';

  @override
  String get m53StocktakeZeroHelp =>
      'Blank means not yet counted. Enter 0 only after checking that the stock is absent.';

  @override
  String get m53StocktakeScan => 'Scan +1 base unit';

  @override
  String get m53StocktakeScanAdded => 'Draft count increased by 1 base unit.';

  @override
  String get m53StocktakeInclude => 'Include without counting';

  @override
  String get m53StocktakeUndo => 'Undo last count';

  @override
  String get m53StocktakePlus => '+1 base unit';

  @override
  String get m53StocktakeMinus => '−1 base unit';

  @override
  String get m53StocktakeZero => 'Set physical count to 0';

  @override
  String get m53StocktakeReset => 'Reset to not counted';

  @override
  String get m53StocktakeHelp => 'Counting guide';

  @override
  String get m53StocktakeHelpBody =>
      'Drafts are saved without changing stock. A barcode identifies a product type, not each unique piece: the same piece can be counted twice. Choose the physical batch when several exist. Not counted is not 0. After a sale, receipt, product or time zone change, review and recount before finalization. Differences may arise from counting errors, unrecorded transactions, damage or other causes; they are not evidence of theft.';

  @override
  String get m53StocktakeBatchHelp =>
      'Choose the correct batch using physical evidence. Quantities here are in base units. Found units retain the observed expiry date, including past dates; costing remains the product moving average.';

  @override
  String get m53StocktakeBatches => 'Batch observations';

  @override
  String get m53StocktakeBatchChoice =>
      'Several batches exist. Choose the physical batch for +1; this scan has not increased the count.';

  @override
  String get m53StocktakeNewBatch => 'Add a found physical batch';

  @override
  String get m53StocktakeRecount => 'Capture new baseline and recount';

  @override
  String get m53StocktakeRecountHelp =>
      'This product’s counts, entered value and undo will be cleared. Stock and batch baselines will be captured again from current data. Count the physical stock again. Stock is unchanged.';

  @override
  String get m53StocktakeRemove => 'Remove product from this draft';

  @override
  String get m53StocktakeValue => 'Total value of all found stock';

  @override
  String get m53StocktakeValueHelp =>
      'System stock started at 0, so no previous average exists. Enter the TOTAL value for the full counted quantity, not a price per piece or pack. Blank means unknown and is allowed only when purchase cost is optional. Zero requires free-cost confirmation. Review the value again if the count changes. This is not a new purchase or supplier debt.';

  @override
  String get m53StocktakeValueDifference => 'Estimated value difference';

  @override
  String get m53StocktakeFinalize => 'Review and finalize stocktake';

  @override
  String get m53StocktakeFinalizeHelp =>
      'Check every product’s baseline, physical count and difference. Stock, batches, value and history update atomically only if the baseline still matches. Results and reason become permanent snapshots. A shortage is not evidence of theft.';

  @override
  String get m53StocktakeCancel => 'Cancel stocktake draft';

  @override
  String get m53StocktakeCancelHelp =>
      'Keep the session as cancelled. Stock is unchanged and previous input remains in the cancelled draft.';

  @override
  String get m53StocktakeEmpty =>
      'No products yet. Scan a code or include a product without entering a count.';

  @override
  String get m53StocktakeRegister =>
      'Product is not registered. Register it with initial stock 0, then include it in the draft and count its physical stock.';

  @override
  String get m53StocktakeChanged =>
      'The stocktake draft or page changed. Reload and review your input before retrying.';

  @override
  String get m53StocktakeConflict =>
      'Stock, product, batches or time zone changed since the baseline. Open the affected product, capture a new baseline and recount. Old input stays saved until you choose to recount.';

  @override
  String get m53StocktakeIncomplete =>
      'Explicitly count every batch before finalizing. Not counted is not 0.';

  @override
  String get m53StocktakeLineLimit =>
      'A draft supports up to 100 products. Continue remaining products in another session.';

  @override
  String get m53StocktakeUntracked =>
      'This product is untracked; sentinel 999 is not physical stock. Use the tracking activation flow if needed.';

  @override
  String get m53StocktakeFrozenBatch =>
      'A baseline batch date cannot be changed by a count. Add a found physical batch if its date differs.';

  @override
  String get m53StocktakeNothingUndo =>
      'No count can be undone. Up to the last 50 count changes are retained.';

  @override
  String get m53StocktakeValueRequired =>
      'Enter the total value of found stock because purchase cost is enabled.';

  @override
  String get m53StocktakeValueReview =>
      'The physical quantity changed after valuation. Review and save the total value for the current count.';

  @override
  String get m53StocktakeValueScope =>
      'This total value applies only when system stock started at 0, every batch is counted and physical quantity is positive.';

  @override
  String get m53StocktakeReviewLine => 'Review count or value';

  @override
  String get m53SupplierTerms => 'Supplier payment terms';

  @override
  String get m53SupplierAllowsCredit => 'Supplier allows payment on credit';

  @override
  String get m53SupplierTermsHelp =>
      'This records the agreement at the store, not automatic supplier approval. It defaults to off. Turning it off only blocks new credit invoices; it does not erase existing debts or payments. Historical receipts are not automatically treated as paid or owed.';

  @override
  String get m53SupplierTermsReadOnly =>
      'Warehouse can view these terms. Only the owner can change them.';

  @override
  String get m53SupplierTermsChanged =>
      'Supplier terms changed. Reload and review your choice before saving.';

  @override
  String get m53SupplierMissing =>
      'Supplier not found. Reload the supplier list.';

  @override
  String get m53SupplierInputInvalid => 'Check the invoice or payment fields.';

  @override
  String get m53SupplierAccessChanged =>
      'Access changed while saving. Unlock and review the result before retrying.';

  @override
  String get m53SupplierInvoiceMissing => 'Invoice not found.';

  @override
  String get m53SupplierInvoiceChanged =>
      'The invoice or list changed. Reload and review before continuing.';

  @override
  String get m53SupplierReceiptMissing =>
      'Receipt not found or contains no items.';

  @override
  String get m53SupplierReceiptNotPurchase =>
      'This document is not a purchase receipt eligible for invoicing.';

  @override
  String get m53SupplierInvoiceSourceMismatch =>
      'Supplier must match the receiving document.';

  @override
  String get m53SupplierInvoiceNeedsSupplier =>
      'Choose a supplier on the document before creating an invoice.';

  @override
  String get m53SupplierArchived =>
      'Supplier is archived. Reactivate it before creating a new invoice.';

  @override
  String get m53SupplierCreditNotAllowed =>
      'This supplier does not allow credit yet. The owner can update supplier terms.';

  @override
  String get m53SupplierDueInvalid =>
      'Credit requires a due date on or after the invoice date.';

  @override
  String get m53SupplierInvoiceCostUnknown =>
      'Complete the costs of all receiving lines to create an invoice. The owner can separately reconcile a historical total if old costs are incomplete.';

  @override
  String get m53SupplierInvoicePrecision =>
      'The source total is finer than one minor currency unit. Review document costs; debt cannot be silently rounded.';

  @override
  String get m53SupplierPaymentInvalid =>
      'Amount must be positive, within the remaining balance, with matching cash details.';

  @override
  String get m53SupplierInvoiceExists =>
      'This receipt already has an active invoice. Open that invoice.';

  @override
  String get m53SupplierPaymentDateInvalid =>
      'Payment date cannot be in the future.';

  @override
  String get m53SupplierPaymentMissing => 'Payment not found.';

  @override
  String get m53SupplierPaymentReversed =>
      'This payment has already been reversed.';

  @override
  String get m53SupplierCashReturnRequired =>
      'Record the cash actually returned to the drawer, with exact pieces and an active cash session.';

  @override
  String get m53SupplierInvoiceDependencies =>
      'Reverse effective payments or credits before voiding the invoice.';

  @override
  String get m53SupplierInvoiceBlocksReceiptReversal =>
      'The owner must void the linked invoice before reversing the receipt.';

  @override
  String get backupSupplierFinanceInvalid =>
      'The archive contains inconsistent supplier invoice, payment or cash relationships.';

  @override
  String get m53SupplierCashOut => 'Cash pieces paid from drawer';

  @override
  String get m53SupplierPaymentConfirm =>
      'Confirm payment already made for this single invoice. The app does not execute transfers.';

  @override
  String get m53SupplierSourcedrawer => 'From cash drawer';

  @override
  String get m53SupplierSourcebank => 'Transfer / bank';

  @override
  String get m53SupplierSourceownerFunds => 'Owner funds';

  @override
  String get m53SupplierPay => 'Record payment';

  @override
  String get m53SupplierPaymentHelp =>
      'Record an actual payment for one invoice. Transfers do not change drawer balance. When cash tracking is active, drawer payments require a session and outgoing pieces.';

  @override
  String get m53SupplierPayRemaining => 'Fill remaining balance';

  @override
  String get m53SupplierPaymentDate => 'Payment date';

  @override
  String get m53SupplierPaymentSource => 'Payment source';

  @override
  String get m53SupplierPaymentReference => 'Payment reference (optional)';

  @override
  String get m53SupplierPaymentNote => 'Payment note (optional)';

  @override
  String get m53SupplierInitialActual => 'Initial payment confirmed by owner';

  @override
  String get m53SupplierInvoiceConfirm =>
      'Save an invoice from this document? Existing stock is not received again. For a new draft, receipt and invoice are posted together.';

  @override
  String get m53SupplierInvoiceNew => 'Create / reconcile invoice';

  @override
  String get m53SupplierInvoiceHelp =>
      'Invoicing is optional. Its value follows document costs. Cash terms alone do not prove payment; only actual payments reduce the balance.';

  @override
  String get m53SupplierHistoricalHelp =>
      'The historical document has no supplier or incomplete item costs. Only the owner can confirm the supplier, financial total and reconciliation reason. This does not complete HPP or guess per-item cost allocations.';

  @override
  String get m53SupplierInvoiceNumber => 'Invoice number (optional)';

  @override
  String get m53SupplierInvoiceDate => 'Invoice date';

  @override
  String get m53SupplierInvoiceTerms => 'Payment terms';

  @override
  String get m53SupplierTermsCash => 'Cash / paid in full';

  @override
  String get m53SupplierTermsCredit => 'Credit / partial payment';

  @override
  String get m53SupplierDue => 'Due date';

  @override
  String get m53SupplierReportedInitial => 'Reported paid amount (optional)';

  @override
  String get m53SupplierReportedHelp =>
      'This reported amount is not an actual payment and does not reduce debt. The owner must separately confirm an actual payment.';

  @override
  String get m53SupplierBillingCostsHelp =>
      'Costs are shown for invoicing even when purchase prices are hidden. Tap a line to complete costs.';

  @override
  String get m53SupplierReceiveInvoice =>
      'Confirm receipt + invoice (optional)';

  @override
  String get m53SupplierInvoices => 'Supplier invoices';

  @override
  String get m53SupplierUnreconciled => 'Unreconciled receipts';

  @override
  String get m53SupplierFilterall => 'All invoices';

  @override
  String get m53SupplierFilteropen => 'Open balance';

  @override
  String get m53SupplierFilterpaid => 'Paid';

  @override
  String get m53SupplierFilteroverdue => 'Overdue';

  @override
  String get m53SupplierStatusunpaid => 'Unpaid';

  @override
  String get m53SupplierStatuspartial => 'Partly paid';

  @override
  String get m53SupplierStatuspaid => 'Paid';

  @override
  String get m53SupplierStatusvoided => 'Voided';

  @override
  String get m53SupplierNext => 'Next page';

  @override
  String get m53SupplierFirst => 'Back to first page';

  @override
  String get m53SupplierEmpty => 'No documents match this filter.';

  @override
  String get m53SupplierPaid => 'Effective payments';

  @override
  String get m53SupplierCredit => 'Applied credit';

  @override
  String get m53SupplierRemaining => 'Remaining balance';

  @override
  String get m53SupplierDueToday => 'Due today';

  @override
  String get m53SupplierNotDue => 'Not due yet';

  @override
  String get m53SupplierOverdue => 'Past due';

  @override
  String get m53SupplierInvoiceVoid => 'Void invoice';

  @override
  String get m53SupplierAmendDue => 'Amend due date with reason';

  @override
  String get m53SupplierPayments => 'Payment history';

  @override
  String get m53SupplierReversePayment => 'Reverse payment';

  @override
  String get m53SupplierPaymentReversedLabel => 'Payment reversed';

  @override
  String get m53SupplierCashReturned => 'Cash pieces actually returned';

  @override
  String get m53SupplierCorrectionHelp =>
      'Corrections append a new trace. Enter a reason before voiding, reversing payment or changing the due date.';

  @override
  String get m53SupplierRetryPayment => 'Retry the same payment';

  @override
  String get m53SupplierCancelPendingPayment => 'Discard pending payment input';

  @override
  String get m53SupplierItems => 'Source document items';

  @override
  String get m53SupplierSummaryScope =>
      'All active invoices for this supplier, current balance; effective payments net of reversals. Unreconciled receipts are separate.';

  @override
  String get m53SupplierPurchases => 'Gross invoiced purchases';

  @override
  String get m53ReturnSourceUnavailable =>
      'The source receipt, item or batch cannot be traced for this return. Do not guess a batch; review the source document.';

  @override
  String get m53ReturnSupplierRequired =>
      'The historical document has no supplier. The owner must explicitly reconcile its supplier before a return can be created.';

  @override
  String get m53ReturnQuantityInvalid =>
      'Quantity must be positive and within the source quantity still eligible for return.';

  @override
  String get m53ReturnStockUnavailable =>
      'The source batch has insufficient physical stock for this return.';

  @override
  String get m53ReturnChanged =>
      'The return draft, document or list changed. Reload and review before continuing.';

  @override
  String get m53ReturnLimit =>
      'A return document is limited to 100 lines. Create another document for additional items.';

  @override
  String get m53ReturnLineExists =>
      'This source item is already in the draft. Tap its line to change the quantity.';

  @override
  String get m53ReturnEmpty => 'Add at least one item from the source receipt.';

  @override
  String get m53ReturnConflict =>
      'Stock or product data changed since the line was selected. Review the quantity and balance before confirming; stock is not overwritten.';

  @override
  String get m53ReturnAlreadyReversed =>
      'This return document has already been reversed.';

  @override
  String get m53ReturnCreditDependency =>
      'This return has approved supplier credit. The owner must resolve credit reversal and its allocations first.';

  @override
  String get m53ReturnReversalDependency =>
      'Stock or batch changes occurred after this return. An exact reversal is unavailable; review the history and goods.';

  @override
  String get m53ReturnBlocksReceiptReversal =>
      'This receipt has an active physical return. Resolve a valid return reversal before reversing the receipt.';

  @override
  String get backupSupplierReturnsInvalid =>
      'The archive contains inconsistent supplier return sources, batches, values or event order.';

  @override
  String get m53SupplierReturn => 'Return to supplier';

  @override
  String get m53SupplierReturns => 'Supplier returns';

  @override
  String get m53ReturnQuantity => 'Return quantity (base units)';

  @override
  String get m53ReturnConfirmHelp =>
      'Confirm the entire return document? Source batch stock will be removed at its current average inventory value. This return is not yet approved credit or incoming money.';

  @override
  String get m53ReturnUndoHelp =>
      'Reverse this entire return with the entered reason? This requires no dependent stock changes or credit. History is retained and customer sales are not cancelled.';

  @override
  String get m53ReturnNoAutomaticCredit =>
      'Physical returns and supplier credit approval are separate events. Returning goods does not automatically reduce debt or add drawer cash.';

  @override
  String get m53ReturnStatusdraft => 'Return draft — stock unchanged';

  @override
  String get m53ReturnStatusposted => 'Return posted';

  @override
  String get m53ReturnStatuscancelled => 'Return draft cancelled';

  @override
  String get m53ReturnUntrackedHelp =>
      'Untracked: physical balance not validated';

  @override
  String get m53ReturnSaveReason => 'Save reason to draft';

  @override
  String get m53ReturnConfirm => 'Confirm physical return';

  @override
  String get m53ReturnReview => 'Review draft balances and quantities';

  @override
  String get m53ReturnCancel => 'Cancel return draft';

  @override
  String get m53ReturnCancelHelp =>
      'Cancel this draft? Stock is unchanged and the draft remains recorded as cancelled.';

  @override
  String get m53ReturnSourceItems => 'Choose items from the source receipt';

  @override
  String get m53ReturnEligible => 'Still eligible for return';

  @override
  String get m53ReturnPhysicalAvailable => 'Available in source batch';

  @override
  String get m53ReturnReversed => 'Return reversed';

  @override
  String get m53ReturnPendingCredit =>
      'Physical return recorded; credit value not approved';

  @override
  String get m53ReturnInventoryValue => 'Inventory value removed';

  @override
  String get m53ReturnUndo => 'Reverse return with reason';

  @override
  String get m53ReturnListdrafts => 'Return drafts';

  @override
  String get m53ReturnListposted => 'Return history';

  @override
  String get m53ReturnListreceipts => 'Source receipts';

  @override
  String get m53ReturnChooseReceipt => 'Create a draft from this receipt';

  @override
  String get m53CreditMissing => 'Supplier credit not found.';

  @override
  String get m53CreditChanged =>
      'The credit balance or history changed. Reload and review before continuing.';

  @override
  String get m53CreditReturnUnavailable =>
      'The physical return is unavailable or reversed. New credit cannot be approved.';

  @override
  String get m53CreditAlreadyApproved =>
      'This return already has approved credit. Open that credit.';

  @override
  String get m53CreditDateInvalid =>
      'Check the date. It cannot be in the future or before the approval or original reversed event.';

  @override
  String get m53CreditAmountInvalid =>
      'Amount must be positive and within both available credit and the target invoice balance.';

  @override
  String get m53CreditTargetInvalid =>
      'Choose an active invoice for the same supplier and currency.';

  @override
  String get m53CreditAllocationMissing => 'Credit allocation not found.';

  @override
  String get m53CreditAllocationReversed => 'Credit allocation reversed.';

  @override
  String get m53CreditDependencies =>
      'Reverse effective allocations and refunds before reversing credit approval.';

  @override
  String get m53CreditRefundMissing => 'Supplier refund not found.';

  @override
  String get m53CreditRefundReversed =>
      'This refund has already been reversed.';

  @override
  String get m53CreditCashOutRequired =>
      'Enter the cash pieces actually sent back to the supplier from an active drawer session.';

  @override
  String get backupSupplierCreditInvalid =>
      'The archive contains inconsistent supplier credit approvals, allocations, refunds or balances.';

  @override
  String get m53CreditApprove => 'Approve supplier credit value';

  @override
  String get m53CreditApproveConfirm =>
      'Confirm the value actually approved by the supplier? This is separate from inventory removed. Allocation to the original invoice is posted together, without automatically receiving money.';

  @override
  String get m53CreditAppliedNow => 'Applied to original invoice now';

  @override
  String get m53CreditAvailable => 'Unallocated credit';

  @override
  String get m53CreditApprovalHelp =>
      'Enter a value and reason based on supplier approval, not an estimated goods price. It may differ from inventory removed. Allocation is capped by the original invoice balance; excess stays unallocated.';

  @override
  String get m53CreditNoInvoice =>
      'No active original invoice exists. Approved credit is kept separately for later allocation or refund.';

  @override
  String get m53CreditApprovedValue => 'Approved credit value';

  @override
  String get m53CreditApprovalDate => 'Supplier approval date';

  @override
  String get m53CreditAgreementReason => 'Reason / supplier agreement evidence';

  @override
  String get m53SupplierCredits => 'Supplier credits and refunds';

  @override
  String get m53CreditRefund => 'Record refund received';

  @override
  String get m53CreditAllocate => 'Apply to one invoice';

  @override
  String get m53CreditCashReceived => 'Refund cash pieces received in drawer';

  @override
  String get m53CreditRefundConfirm =>
      'Record refund money already received from the supplier? This uses available credit, not a new supplier payment or an automatic transfer.';

  @override
  String get m53CreditAllocateConfirm =>
      'Apply credit to the selected single invoice? No money or stock is moved.';

  @override
  String get m53CreditRefundHelp =>
      'Record only money actually received from the supplier. Refunded credit cannot also be allocated to invoices. Bank transfers do not change drawer balance.';

  @override
  String get m53CreditAllocateHelp =>
      'One allocation targets one invoice for the same supplier. Both balances are rechecked at confirmation. This allocation does not pay drawer cash.';

  @override
  String get m53CreditRefundAmount => 'Refund amount received';

  @override
  String get m53CreditAllocationAmount => 'Credit amount applied';

  @override
  String get m53CreditFillMaximum => 'Fill available maximum';

  @override
  String get m53CreditRefundDate => 'Refund receipt date';

  @override
  String get m53CreditAllocationDate => 'Credit allocation date';

  @override
  String get m53CreditRefundDestination => 'Destination of received money';

  @override
  String get m53CreditDestinationdrawer => 'Into cash drawer';

  @override
  String get m53CreditDestinationbank => 'Received through bank';

  @override
  String get m53CreditDestinationownerFunds =>
      'Received by owner outside drawer';

  @override
  String get m53CreditDrawerOff =>
      'Drawer tracking is off. The refund amount is recorded, but no drawer pieces or balance are created. Open cash settings to track pieces and a drawer session.';

  @override
  String get m53CreditSummaryScope =>
      'All effective credits for this supplier, current balance, separated by currency. Reversed approvals remain in the list history.';

  @override
  String get m53CreditSummaryapproved => 'Total effective approved credit';

  @override
  String get m53CreditSummaryallocated => 'Effective credit applied';

  @override
  String get m53CreditSummaryrefunded => 'Effective refunds received';

  @override
  String get m53CreditSummaryavailable => 'Unallocated credit';

  @override
  String get m53CreditReversed => 'Credit approval reversed';

  @override
  String get m53CreditChooseInvoice => 'Choose one target invoice';

  @override
  String get m53CreditReverseAllocation => 'Reverse credit allocation';

  @override
  String get m53CreditCashSentBack => 'Cash pieces sent back to supplier';

  @override
  String get m53CreditReverseRefund => 'Reverse received refund';

  @override
  String get m53CreditReverse => 'Reverse credit approval';

  @override
  String get m53CreditAllocations => 'Credit allocation history';

  @override
  String get m53CreditRefunds => 'Supplier refund history';

  @override
  String get m53CreditRefundReversedLabel => 'Refund reversed';

  @override
  String get m53CreditApprovedStatus =>
      'Credit value approved; review its allocations and balance';

  @override
  String get m53VisitMissing => 'Visit plan not found.';

  @override
  String get m53VisitInputInvalid =>
      'Check the visit time and note (up to 1,000 characters).';

  @override
  String get m53VisitChanged =>
      'The plan or reminder preference changed. Reload before continuing.';

  @override
  String get backupSupplierScheduleInvalid =>
      'The archive contains inconsistent supplier plans or reminder preferences.';

  @override
  String get m53ReminderUnavailable =>
      'Reminders are unavailable. Plans and invoices remain saved; check notification permission and battery restrictions.';

  @override
  String get m53SupplierSchedules => 'Supplier plans and reminders';

  @override
  String get m53SupplierReminderHelp =>
      'H-1 reminders at 09:00 shop time depend on Android permission and restrictions and may be delayed. Past H-1 targets are not sent as catch-up alerts. General notifications can be enabled in Reminder settings.';

  @override
  String get m53ReminderPermissionSettings => 'Reminder settings';

  @override
  String get m53DueReminderList => 'Invoices with due dates';

  @override
  String get m53VisitAdd => 'Add visit plan';

  @override
  String get m53VisitFilter => 'Visit status';

  @override
  String get m53VisitStatusplanned => 'Planned';

  @override
  String get m53VisitStatuscompleted => 'Completed';

  @override
  String get m53VisitStatuscancelled => 'Cancelled';

  @override
  String get m53VisitStatusall => 'All statuses';

  @override
  String get m53VisitEmpty => 'No visit plans match this selection.';

  @override
  String get m53VisitAttention =>
      'Needs attention: the H-1 target has passed. Review the visit date and status.';

  @override
  String get m53VisitReview => 'Review visit plan';

  @override
  String get m53VisitNoPosting =>
      'A visit plan does not create a receipt, invoice or payment. This date is separate from invoice due dates.';

  @override
  String get m53VisitDate => 'Visit date';

  @override
  String get m53VisitTime => 'Visit time (optional)';

  @override
  String get m53VisitNoTime => 'No specific time';

  @override
  String get m53VisitClearTime => 'Clear visit time';

  @override
  String get m53VisitReminder => 'Remind me H-1 before the visit';

  @override
  String get m53VisitNote => 'Visit note (optional)';

  @override
  String get m53DueAttentionHelp =>
      'These invoices still have a balance. Invoices due today or overdue need attention even if a reminder was not shown. Partial payment keeps the reminder; full settlement cancels it.';

  @override
  String get m53DueReminderEmpty =>
      'No invoices with due dates have an outstanding balance.';

  @override
  String get m53DueReminder => 'Remind me H-1 before payment is due';

  @override
  String get m53ReminderDueTitle => 'Supplier payment due tomorrow';

  @override
  String get m53ReminderVisitTitle => 'Supplier visit tomorrow';

  @override
  String m53ReminderPrivateBody(String supplier) {
    return '$supplier · Open with management access.';
  }

  @override
  String get m53VisitNextDate => 'Next planned visit date';

  @override
  String get m53VisitNoFuture => 'No plans for today or a later date';

  @override
  String get m53Labels => 'Product QR labels';

  @override
  String get m53LabelHelp =>
      'QR contains a stable SkyBee product identity even after its name, SKU or price changes. Existing barcodes still work. Physical scanners must support QR (2D).';

  @override
  String get m53LabelPrinterSettings => 'Connect or configure printer';

  @override
  String get m53LabelPrinter => 'Label printer';

  @override
  String get m53LabelProtocol => 'Command language supported by the printer';

  @override
  String get m53LabelwidthMm => 'Label width (mm)';

  @override
  String get m53LabelheightMm => 'Label height (mm)';

  @override
  String get m53LabelgapMm => 'Inter-label gap (mm)';

  @override
  String get m53LabeloffsetXmm => 'Right offset (mm)';

  @override
  String get m53LabeloffsetYmm => 'Down offset (mm)';

  @override
  String get m53LabelmoduleDots => 'QR module size (4–12 printer dots)';

  @override
  String get m53Labelfeed => 'Trailing feed for continuous paper (0–8 lines)';

  @override
  String get m53Labelcopies => 'Label copies (1–100)';

  @override
  String get m53LabelPrice => 'Show current retail price';

  @override
  String get m53LabelGap => 'Use gap label media (TSPL)';

  @override
  String get m53LabelGapAck =>
      'I have confirmed the printer supports TSPL and this media size/gap.';

  @override
  String get m53LabelMediaHelp =>
      'Label settings are separate from receipts. QR uses a four-module white margin and integer modules of at least four dots. Media that is too small is rejected. Test one label first; physical dimensions depend on the printer specifications. No automatic calibration is performed.';

  @override
  String get m53LabelSaveProfile => 'Save label settings';

  @override
  String get m53LabelPreview => 'Preview label';

  @override
  String get m53LabelTotalMedia => 'Media including feed/gap';

  @override
  String get m53LabelPrint => 'Send labels to printer';

  @override
  String get m53LabelPaperWarning =>
      'Sent data does not prove a label printed. Check the paper and scan the QR. A new job may produce additional labels, especially when the previous delivery is unknown.';

  @override
  String get m53LabelNewJob => 'Create a new label job';

  @override
  String get m53LabelPrinterMissing => 'Select and save a printer first.';

  @override
  String get m53LabelProfileChanged =>
      'Label settings changed. Reopen this screen to load the current version.';

  @override
  String get m53LabelProductChanged =>
      'Product details changed. Review a fresh preview before printing.';

  @override
  String get m53LabelCopiesInvalid => 'Label copies must be between 1 and 100.';

  @override
  String get m53LabelProfileInvalid =>
      'Label size, offsets, QR module size or feed are invalid.';

  @override
  String get m53LabelGapUnsupported =>
      'Gap labels require TSPL and confirmation of printer support.';

  @override
  String get m53LabelWidthExceeded =>
      'Label width exceeds the selected printer’s printable area.';

  @override
  String get m53LabelDoesNotFit =>
      'The label content does not fit. Increase media size or reduce offsets/optional price. QR modules are never automatically shrunk.';

  @override
  String get m53LabelSnapshotInvalid =>
      'The label snapshot is invalid. Create a new job from valid product details.';

  @override
  String get backupLabelProfileInvalid =>
      'The backup contains invalid label settings.';

  @override
  String get m53LabelResume => 'Continue the same label job';

  @override
  String get m53LabelTspl => 'TSPL (continuous or confirmed gap media)';

  @override
  String get m53LabelIdentityInvalid =>
      'This product identity is not supported for QR labels. Product data was not changed.';

  @override
  String get m53ReceiptPolicy => 'Receipt policy';

  @override
  String get m53ReceiptPolicyRequired =>
      'Require a receipt before the next sale';

  @override
  String get m53ReceiptPolicyHelp =>
      'Off by default. When enabled as a sale is saved, the cashier remains on its receipt until paper output is confirmed or the owner approves a single-sale exception. Stock, debt and money are committed once even if the printer fails. Disabling the policy affects future sales; existing obligations still need resolution.';

  @override
  String get m53ReceiptRequiredPending =>
      'This sale’s receipt is still required. Inspect and confirm the paper, explicitly print a copy, or request an owner exception before the next basket.';

  @override
  String get m53ReceiptPolicyUnavailable =>
      'The receipt policy requires a database upgrade.';

  @override
  String get m53ReceiptPolicyChanged =>
      'The receipt policy changed. Reload settings before saving.';

  @override
  String get m53ReceiptNotPending =>
      'This sale is no longer waiting for receipt fulfillment. Reload the receipt.';

  @override
  String get m53ReceiptConfirmationUnavailable =>
      'This job cannot confirm the receipt. Use a receipt delivery for the same sale; label, calibration and failed deliveries do not qualify.';

  @override
  String get m53ReceiptPaperQuestion => 'Has the receipt printed?';

  @override
  String get m53ReceiptPaperInspect =>
      'Inspect this sale’s paper receipt yourself. Successful writes, ACK or sent status do not prove paper delivery. This confirmation is an operator statement, not automatic physical verification by the printer.';

  @override
  String get m53ReceiptPaperYes => 'Yes, I inspected the paper receipt';

  @override
  String get m53ReceiptPaperHelp =>
      'Unknown delivery never retries automatically. Confirm only after paper actually comes out, including from an earlier attempt. If the printer is broken or out of paper, the owner may approve a single-sale exception with a reason.';

  @override
  String get m53ReceiptOperatorConfirmed =>
      'The operator confirmed the receipt after inspecting the paper.';

  @override
  String get m53ReceiptOwnerExcepted =>
      'The owner approved a receipt exception for this sale only.';

  @override
  String get m53ReceiptException => 'Request a single-sale receipt exception';

  @override
  String get m53ReceiptExceptionHelp =>
      'The sale is already saved. This exception does not cancel, charge again or change stock/debt/money. Enter a reason, then ask the owner to authenticate again to approve this sale only. The reason and approval are recorded; the owner session is locked again after the action.';

  @override
  String get m53ReceiptExceptionReason => 'Exception reason';

  @override
  String get m53ReceiptExceptionReasonRequired =>
      'Enter an exception reason, up to 1000 characters.';

  @override
  String get m53ReceiptExceptionAuthenticate =>
      'Authenticate the owner and approve once';

  @override
  String get backupReceiptPolicyInvalid =>
      'The backup contains invalid receipt policy, obligation or confirmation records.';

  @override
  String get m53OperationalReports => 'Inventory and supplier reports';

  @override
  String get m53OperationalReportChanged =>
      'Data, access or shop day changed. Reload the report.';

  @override
  String get m53OpInvoiceLevel => 'Per invoice';

  @override
  String get m53OpSearch => 'Search text containing';

  @override
  String get m53OpApply => 'Apply / reload';

  @override
  String get m53OpAllDates => 'All dates';

  @override
  String get m53OpCaptured => 'Snapshot captured';

  @override
  String get m53OpWholeScope => 'Summary of the entire filtered scope';

  @override
  String get m53OpNoComparison => 'No comparison data yet';

  @override
  String get m53OpEmpty => 'No matching data';

  @override
  String get m53OpUnassigned => 'Unassigned category / supplier or whole store';

  @override
  String get m53OpNextPage => 'Next page (20 rows)';

  @override
  String get m53OpFirstPage => 'Return to first page';

  @override
  String get m53OpCashAudit => 'Cash history and audit';

  @override
  String get m53OpCashPolicy => 'Mandatory cash audit policy';

  @override
  String get m53OpAssumptions => 'Basis, coverage and calculation limits';

  @override
  String get m53OpNoSupplier => 'No supplier';

  @override
  String get m53OpNoCategory => 'No category';

  @override
  String get m53OpAppliedSearch => 'Applied search';

  @override
  String get m53OpSectionPotential => 'Potential stock retail value';

  @override
  String get m53OpSectionVariance => 'Stock variance / indication of shortage';

  @override
  String get m53OpSectionSupplierInvoices => 'Current supplier balances';

  @override
  String get m53OpSectionSupplierPayments => 'Supplier payments during period';

  @override
  String get m53OpSectionSupplierCredits => 'Current supplier credits';

  @override
  String get m53OpSectionSupplierRefunds => 'Supplier refunds during period';

  @override
  String get m53OpSectionUnreconciled => 'Unreconciled receipts';

  @override
  String get m53OpSectionPendingReturns => 'Returns awaiting credit approval';

  @override
  String get m53OpHelpPotential =>
      'Tracked saleable stock × current retail price. Estimated stock gross profit deducts allocated average carrying cost. Known cost/profit subtotals exclude incomplete costs. Archived, expired and untracked products are separate. This is not a forecast, net profit or realized sales; cart promotions, wholesale, charges, tax and operating costs are excluded. Supplier grouping uses the product master supplier, not batch provenance. Cross-unit quantities count base units; compare individual products.';

  @override
  String get m53OpHelpVariance =>
      'Posted stocktake snapshots only, not current balances. Shortages may reflect counting errors, unrecorded transactions, damage or other causes; they are not evidence of theft. Uncounted lines and untracked stock are not losses. Inventory adjustment values remain separate from sales and sale cost.';

  @override
  String get m53OpHelpSupplierInvoices =>
      'CURRENT balances, not historical balances at a date. Purchases, effective payments and applied credits use active invoices. Overdue amounts are part of open balances, not an additional total; missing due dates are not overdue. Currencies stay separate. Unreconciled receipts and unapproved returns are separate, not inferred debt/credit. Search supplier names or invoice numbers.';

  @override
  String get m53OpHelpSupplierPayments =>
      'Original payments use the operator-entered payment date. Reversals use their recorded time in the shop timezone. Old payments remain in their original period after a later reversal. Owner funds, bank and drawer are separate; these are not all store cash. This period does not alter current debt balances or sale cost.';

  @override
  String get m53OpHelpSupplierCredits =>
      'Active credit approvals: effective allocations and refunds reduce available credit. Available credit is not a payment or a debt deduction until allocated.';

  @override
  String get m53OpHelpSupplierRefunds =>
      'Actual refunds and reversals use operator-entered event dates. Bank, drawer and owner funds stay separate. These do not create sales or sale cost.';

  @override
  String get m53OpHelpUnreconciled =>
      'Actual purchase receipts without an active invoice. Opening stock, tracking transitions and reversed receipts are excluded. Document counts are not estimated debt.';

  @override
  String get m53OpHelpPendingReturns =>
      'Active physical returns without active credit approval. Known carrying values are inventory adjustments only, not approved credit or debt reductions.';

  @override
  String get m53OpGroupProduct => 'Per product';

  @override
  String get m53OpGroupCategory => 'Per category';

  @override
  String get m53OpGroupSupplier => 'Per supplier';

  @override
  String get m53OpGroupStore => 'Whole store';

  @override
  String get m53OpBalanceAll => 'All invoices';

  @override
  String get m53OpBalanceOpen => 'Open balances';

  @override
  String get m53OpBalanceFuture => 'Not yet due';

  @override
  String get m53OpBalanceToday => 'Due today';

  @override
  String get m53OpBalanceOverdue => 'Overdue';

  @override
  String get m53OpBalancePaid => 'Paid';

  @override
  String get m53OpBalanceNoDue => 'Open without due date';

  @override
  String get m53OpFieldProductCount => 'Product count';

  @override
  String get m53OpFieldTrackedProductCount => 'Tracked products';

  @override
  String get m53OpFieldUntrackedProductCount =>
      'Cannot calculate: stock quantity is untracked';

  @override
  String get m53OpFieldSaleableQuantity => 'Saleable quantity';

  @override
  String get m53OpFieldExcludedQuantity => 'Excluded quantity';

  @override
  String get m53OpFieldExpiredQuantity => 'Expired quantity';

  @override
  String get m53OpFieldArchivedProductCount => 'Archived products';

  @override
  String get m53OpFieldPotentialMinor => 'Potential stock retail value';

  @override
  String get m53OpFieldKnownCostMicros => 'Known related cost subtotal';

  @override
  String get m53OpFieldKnownExcludedCostMicros =>
      'Known excluded stock cost subtotal';

  @override
  String get m53OpFieldKnownCostQuantity =>
      'Saleable quantity with complete costs';

  @override
  String get m53OpFieldKnownGrossMicros =>
      'Estimated stock gross profit: known cost subtotal';

  @override
  String get m53OpFieldUnknownCostProductCount =>
      'Saleable products with incomplete costs';

  @override
  String get m53OpFieldUnknownCostQuantity =>
      'Saleable quantity with incomplete costs';

  @override
  String get m53OpFieldUnknownExcludedQuantity =>
      'Excluded quantity with incomplete costs';

  @override
  String get m53OpFieldUncountedLineCount => 'Uncounted lines, not losses';

  @override
  String get m53OpFieldComparisonLineCount => 'Valid comparison lines';

  @override
  String get m53OpFieldBaselineQuantity => 'System quantity at baseline';

  @override
  String get m53OpFieldPhysicalQuantity => 'Final physical quantity';

  @override
  String get m53OpFieldDeltaQuantity => 'Quantity variance (physical − system)';

  @override
  String get m53OpFieldShortageQuantity => 'Shortage quantity';

  @override
  String get m53OpFieldSurplusQuantity => 'Surplus quantity';

  @override
  String get m53OpFieldKnownDeltaMicros => 'Known value variance subtotal';

  @override
  String get m53OpFieldKnownBaselineMicros => 'Known baseline value subtotal';

  @override
  String get m53OpFieldKnownFinalMicros => 'Known final value subtotal';

  @override
  String get m53OpFieldUnknownValueLineCount => 'Lines with incomplete values';

  @override
  String get m53OpFieldInvoiceCount => 'Invoice count';

  @override
  String get m53OpFieldPurchaseMinor => 'Total invoiced purchases';

  @override
  String get m53OpFieldEffectivePaymentMinor => 'Total effective payments';

  @override
  String get m53OpFieldAppliedCreditMinor => 'Applied credits / returns';

  @override
  String get m53OpFieldRemainingMinor => 'Total open debt';

  @override
  String get m53OpFieldOpenInvoiceCount => 'Open invoices';

  @override
  String get m53OpFieldNoDueMinor => 'Balance without due date';

  @override
  String get m53OpFieldDueTodayMinor => 'Balance due today';

  @override
  String get m53OpFieldFutureMinor => 'Balance not yet due';

  @override
  String get m53OpFieldOverdueMinor => 'Overdue balance';

  @override
  String get m53OpFieldOverdue17Minor => 'Overdue 1–7 days';

  @override
  String get m53OpFieldOverdue830Minor => 'Overdue 8–30 days';

  @override
  String get m53OpFieldOverdueOver30Minor => 'Overdue >30 days';

  @override
  String get m53OpFieldPaidInvoiceCount => 'Paid invoices';

  @override
  String get m53OpFieldPaymentMinor => 'Original period payments';

  @override
  String get m53OpFieldPaymentReversalMinor => 'Period payment reversals';

  @override
  String get m53OpFieldNetPaymentMinor => 'Net period payments';

  @override
  String get m53OpFieldEventCount => 'Event count';

  @override
  String get m53OpFieldRefundMinor => 'Original period refunds';

  @override
  String get m53OpFieldRefundReversalMinor => 'Period refund reversals';

  @override
  String get m53OpFieldNetRefundMinor => 'Net period refunds';

  @override
  String get m53OpFieldCreditCount => 'Active credit approvals';

  @override
  String get m53OpFieldApprovedCreditMinor => 'Approved credit';

  @override
  String get m53OpFieldAllocatedCreditMinor => 'Allocated credit';

  @override
  String get m53OpFieldRefundedCreditMinor => 'Effective refunded credit';

  @override
  String get m53OpFieldAvailableCreditMinor => 'Available credit';

  @override
  String get m53OpFieldUnreconciledReceiptCount => 'Unreconciled receipts';

  @override
  String get m53OpFieldPendingReturnLineCount => 'Unapproved return lines';

  @override
  String get m53OpFieldPendingReturnQuantity => 'Unapproved return quantity';

  @override
  String get m53OpFieldKnownPendingCarryingMicros =>
      'Known return carrying subtotal (not credit)';

  @override
  String get m53OpFieldUnknownPendingValueLineCount =>
      'Return lines with incalculable value';

  @override
  String get m53OpFieldPaymentDrawerMinor => 'Net payments: drawer';

  @override
  String get m53OpFieldPaymentBankMinor => 'Net payments: bank';

  @override
  String get m53OpFieldPaymentOwnerFundsMinor => 'Net payments: owner funds';

  @override
  String get m53OpFieldRefundDrawerMinor => 'Net refunds: drawer';

  @override
  String get m53OpFieldRefundBankMinor => 'Net refunds: bank';

  @override
  String get m53OpFieldRefundOwnerFundsMinor => 'Net refunds: owner funds';

  @override
  String get m53OpDetailProductId => 'Product ID';

  @override
  String get m53OpDetailSku => 'SKU';

  @override
  String get m53OpDetailBarcode => 'Legacy code';

  @override
  String get m53OpDetailCategory => 'Product master category';

  @override
  String get m53OpDetailSupplier => 'Master / document supplier';

  @override
  String get m53OpDetailSupplierId => 'Supplier ID';

  @override
  String get m53OpDetailBaseUnit => 'Base unit';

  @override
  String get m53OpDetailRetailPriceMinor => 'Retail price';

  @override
  String get m53OpDetailStockTracking => 'Stock tracking';

  @override
  String get m53OpDetailArchived => 'Archived (1=yes)';

  @override
  String get m53OpDetailStocktakeId => 'Stocktake ID';

  @override
  String get m53OpDetailOperationId => 'Inventory operation';

  @override
  String get m53OpDetailPostedAt => 'Posted time';

  @override
  String get m53OpDetailReason => 'Reason';

  @override
  String get m53OpDetailActorRole => 'Actor role';

  @override
  String get m53OpDetailBaselineAt => 'Baseline time';

  @override
  String get m53OpDetailBaselineEpoch => 'Baseline epoch';

  @override
  String get m53OpDetailBaselineQuantity => 'Baseline quantity';

  @override
  String get m53OpDetailFinalQuantity => 'Final physical quantity';

  @override
  String get m53OpDetailSnapshotZone => 'Snapshot timezone';

  @override
  String get m53OpDetailInvoiceId => 'Invoice ID';

  @override
  String get m53OpDetailInvoiceDate => 'Invoice date';

  @override
  String get m53OpDetailDueDate => 'Due date';

  @override
  String get m53OpDetailDaysOverdue => 'Days overdue';

  @override
  String get m53OpDetailStatus => 'Status';

  @override
  String get m53OpDetailCreditId => 'Credit ID';

  @override
  String get m53OpDetailSource => 'Funds source / destination';

  @override
  String get m53OpDetailKind => 'Event kind';

  @override
  String get m53OpDetailEventDate => 'Event date';

  @override
  String get m53OpDetailRecordedAt => 'Recorded time';

  @override
  String get m53OpDetailDateBasis => 'Date basis';

  @override
  String get m53OpDetailReturnId => 'Return ID';

  @override
  String get m53OpDetailApprovedDate => 'Approval date';

  @override
  String get m53OpDetailReceiptId => 'Receipt ID';

  @override
  String get m53OpDetailGrouping => 'Grouping level';

  @override
  String get m53OpBasisPotential =>
      'Current retail prices; average costs; tracked saleable stock only. Profit covers only complete costs.';

  @override
  String get m53OpBasisVariance =>
      'Completed stocktake snapshots; not suspected theft or current stock balances.';

  @override
  String get m53OpBasisSupplierInvoices =>
      'Current balances. Overdue debt is part of open balances.';

  @override
  String get m53OpBasisSupplierPayments =>
      'Operator payment dates; reversals use the shop recording date.';

  @override
  String get m53OpBasisSupplierCredits =>
      'Active approvals, effective allocations and refunds.';

  @override
  String get m53OpBasisSupplierRefunds =>
      'Actual refunds and reversals by operator-entered event dates.';

  @override
  String get m53OpBasisUnreconciled =>
      'Actual uninvoiced receipts; these counts are not debt values.';

  @override
  String get m53OpBasisPendingReturns =>
      'Unapproved physical returns do not reduce debt.';

  @override
  String get m53OpValueTracked => 'Tracked';

  @override
  String get m53OpValueUntracked => 'Untracked';

  @override
  String get m53OpValuePaid => 'Paid';

  @override
  String get m53OpValueUnpaid => 'Unpaid';

  @override
  String get m53OpValuePartial => 'Partial';

  @override
  String get m53OpValueDrawer => 'Drawer';

  @override
  String get m53OpValueBank => 'Bank';

  @override
  String get m53OpValueOwnerFunds => 'Owner funds';

  @override
  String get m53OpValueOriginal => 'Original';

  @override
  String get m53OpValueReversal => 'Reversal';

  @override
  String get m53OpValueRecordedShopDate => 'Recorded date in the shop timezone';

  @override
  String get m53OpValueOperatorEventDate => 'Operator-entered event date';

  @override
  String get m53OpAllSuppliers => 'All suppliers';

  @override
  String get m53OpAllCategories => 'All categories';
}
