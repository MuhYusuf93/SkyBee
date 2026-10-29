import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// User-facing Management access
  ///
  /// In en, this message translates to:
  /// **'Management access'**
  String get managementAccess;

  /// User-facing Address (optional)
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get addressOptional;

  /// User-facing Correction reason
  ///
  /// In en, this message translates to:
  /// **'Correction reason'**
  String get correctionReason;

  /// User-facing Archive
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// User-facing Archive product?
  ///
  /// In en, this message translates to:
  /// **'Archive product?'**
  String get archiveProduct;

  /// User-facing Archive record?
  ///
  /// In en, this message translates to:
  /// **'Archive record?'**
  String get archiveRecord;

  /// User-facing Products
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// User-facing Receive stock
  ///
  /// In en, this message translates to:
  /// **'Receive stock'**
  String get receiveStock;

  /// User-facing Stock cannot be sold from its expiry date in the store time zone. Enable tracking to record dates; undated stock is marked as unrecorded.
  ///
  /// In en, this message translates to:
  /// **'Stock cannot be sold from its expiry date in the store time zone. Enable tracking to record dates; undated stock is marked as unrecorded.'**
  String get stockCannotBeSoldFromItsExpiry;

  /// User-facing Barcode (optional)
  ///
  /// In en, this message translates to:
  /// **'Barcode (optional)'**
  String get barcodeOptional;

  /// User-facing Cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// User-facing Reverse latest receipt
  ///
  /// In en, this message translates to:
  /// **'Reverse latest receipt'**
  String get reverseLatestReceipt;

  /// User-facing Pay
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get pay;

  /// User-facing No products yet.
  ///
  /// In en, this message translates to:
  /// **'No products yet.'**
  String get noProductsYet;

  /// User-facing No records yet.
  ///
  /// In en, this message translates to:
  /// **'No records yet.'**
  String get noRecordsYet;

  /// User-facing No history yet.
  ///
  /// In en, this message translates to:
  /// **'No history yet.'**
  String get noHistoryYet;

  /// User-facing Uncategorized
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// User-facing Create a PIN for inventory and settings. Keep the recovery code outside this device.
  ///
  /// In en, this message translates to:
  /// **'Create a PIN for inventory and settings. Keep the recovery code outside this device.'**
  String get createAPinForInventoryAndSettings;

  /// User-facing Create management PIN
  ///
  /// In en, this message translates to:
  /// **'Create management PIN'**
  String get createManagementPin;

  /// User-facing Generate code
  ///
  /// In en, this message translates to:
  /// **'Generate code'**
  String get generateCode;

  /// User-facing Open management
  ///
  /// In en, this message translates to:
  /// **'Open management'**
  String get openManagement;

  /// User-facing Search or add category
  ///
  /// In en, this message translates to:
  /// **'Search or add category'**
  String get searchOrAddCategory;

  /// User-facing Search or add supplier
  ///
  /// In en, this message translates to:
  /// **'Search or add supplier'**
  String get searchOrAddSupplier;

  /// User-facing Search products
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get searchProducts;

  /// User-facing Search name prefix
  ///
  /// In en, this message translates to:
  /// **'Search name prefix'**
  String get searchNamePrefix;

  /// User-facing Search product name prefix
  ///
  /// In en, this message translates to:
  /// **'Search product name prefix'**
  String get searchProductNamePrefix;

  /// User-facing Write this code down and store it outside this device. It is shown only once. If both PIN and code are lost, management access requires a valid recovery procedure.
  ///
  /// In en, this message translates to:
  /// **'Write this code down and store it outside this device. It is shown only once. If both PIN and code are lost, management access requires a valid recovery procedure.'**
  String get writeThisCodeDownAndStoreIt;

  /// User-facing Record damaged or expired stock
  ///
  /// In en, this message translates to:
  /// **'Record damaged or expired stock'**
  String get recordDamagedOrExpiredStock;

  /// User-facing Try again
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// User-facing Shopping list
  ///
  /// In en, this message translates to:
  /// **'Shopping list'**
  String get shoppingList;

  /// User-facing Product details
  ///
  /// In en, this message translates to:
  /// **'Product details'**
  String get productDetails;

  /// User-facing Inventory
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// User-facing Use recovery code
  ///
  /// In en, this message translates to:
  /// **'Use recovery code'**
  String get useRecoveryCode;

  /// User-facing Price
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// User-facing Purchase price when stock is empty
  ///
  /// In en, this message translates to:
  /// **'Purchase price when stock is empty'**
  String get purchasePriceWhenStockIsEmpty;

  /// User-facing Purchase price per unit
  ///
  /// In en, this message translates to:
  /// **'Purchase price per pcs'**
  String get purchasePricePerUnit;

  /// User-facing Price saved.
  ///
  /// In en, this message translates to:
  /// **'Price saved.'**
  String get priceSaved;

  /// User-facing Selling price
  ///
  /// In en, this message translates to:
  /// **'Selling price'**
  String get sellingPrice;

  /// User-facing Debts
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get debts;

  /// User-facing Initial quantity
  ///
  /// In en, this message translates to:
  /// **'Initial quantity'**
  String get initialQuantity;

  /// User-facing Current physical quantity
  ///
  /// In en, this message translates to:
  /// **'Current physical quantity'**
  String get currentPhysicalQuantity;

  /// User-facing Unit quantity
  ///
  /// In en, this message translates to:
  /// **'Unit quantity'**
  String get unitQuantity;

  /// User-facing Cashier
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get cashier;

  /// User-facing Checkout, receivables, reports, printing and backups will be added in later stages.
  ///
  /// In en, this message translates to:
  /// **'Checkout, receivables, reports, printing and backups will be added in later stages.'**
  String get checkoutReceivablesReportsPrintingAndBackupsWill;

  /// User-facing Categories
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// User-facing Category (optional)
  ///
  /// In en, this message translates to:
  /// **'Category (optional)'**
  String get categoryOptional;

  /// User-facing Saved category
  ///
  /// In en, this message translates to:
  /// **'Saved category'**
  String get savedCategory;

  /// User-facing Expiry yyyy-MM-dd (optional)
  ///
  /// In en, this message translates to:
  /// **'Expiry yyyy-MM-dd (optional)'**
  String get expiryYyyyMmDdOptional;

  /// User-facing Manage
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// User-facing Type a name prefix, then select
  ///
  /// In en, this message translates to:
  /// **'Type a name prefix, then select'**
  String get typeANamePrefixThenSelect;

  /// User-facing Recovery code
  ///
  /// In en, this message translates to:
  /// **'Recovery code'**
  String get recoveryCode;

  /// User-facing Store code (automatic if empty)
  ///
  /// In en, this message translates to:
  /// **'Store code (automatic if empty)'**
  String get storeCodeAutomaticIfEmpty;

  /// User-facing Code, barcode and category
  ///
  /// In en, this message translates to:
  /// **'Code, barcode and category'**
  String get codeBarcodeAndCategory;

  /// User-facing Confirm new PIN
  ///
  /// In en, this message translates to:
  /// **'Confirm new PIN'**
  String get confirmNewPin;

  /// User-facing Correct latest receipt
  ///
  /// In en, this message translates to:
  /// **'Correct latest receipt'**
  String get correctLatestReceipt;

  /// User-facing Clear selection
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// User-facing Lock
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lock;

  /// User-facing Continue
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// User-facing Enter a valid amount, quantity and yyyy-MM-dd date.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount, quantity and yyyy-MM-dd date.'**
  String get enterAValidAmountQuantityAndYyyy;

  /// User-facing Forgot PIN or change recovery code
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN or change recovery code'**
  String get forgotPinOrChangeRecoveryCode;

  /// User-facing Enter PIN again
  ///
  /// In en, this message translates to:
  /// **'Enter PIN again'**
  String get enterPinAgain;

  /// User-facing Checking…
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// User-facing Expiring soon
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get expiringSoon;

  /// User-facing Preparing storage…
  ///
  /// In en, this message translates to:
  /// **'Preparing storage…'**
  String get preparingStorage;

  /// User-facing Saving…
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// User-facing Load more
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// User-facing Reload
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// User-facing Reload details
  ///
  /// In en, this message translates to:
  /// **'Reload details'**
  String get reloadDetails;

  /// User-facing Name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// User-facing Product name
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get productName;

  /// User-facing Search aliases, separated by commas
  ///
  /// In en, this message translates to:
  /// **'Search aliases, separated by commas'**
  String get searchAliasesSeparatedByCommas;

  /// User-facing Store name
  ///
  /// In en, this message translates to:
  /// **'Store name'**
  String get storeName;

  /// User-facing Name, code or barcode
  ///
  /// In en, this message translates to:
  /// **'Name, code or barcode'**
  String get nameCodeOrBarcode;

  /// User-facing Contact number (optional)
  ///
  /// In en, this message translates to:
  /// **'Contact number (optional)'**
  String get contactNumberOptional;

  /// User-facing Operation failed. Try again or check device storage.
  ///
  /// In en, this message translates to:
  /// **'Operation failed. Try again or check device storage.'**
  String get operationFailedTryAgainOrCheckDevice;

  /// User-facing PIN
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pin;

  /// User-facing New PIN
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get newPin;

  /// User-facing The four-digit PIN restricts access within the app; it does not encrypt the database or device. Keep the recovery code private.
  ///
  /// In en, this message translates to:
  /// **'The four-digit PIN restricts access within the app; it does not encrypt the database or device. Keep the recovery code private.'**
  String get theFourDigitPinRestrictsAccessWithin;

  /// User-facing Old PIN
  ///
  /// In en, this message translates to:
  /// **'Old PIN'**
  String get oldPin;

  /// User-facing Track expiry
  ///
  /// In en, this message translates to:
  /// **'Track expiry'**
  String get trackExpiry;

  /// User-facing Cashier search, cart and payments are not available yet. Open inventory using Manage.
  ///
  /// In en, this message translates to:
  /// **'Cashier search, cart and payments are not available yet. Open inventory using Manage.'**
  String get cashierSearchCartAndPaymentsAreNot;

  /// User-facing Next receipts
  ///
  /// In en, this message translates to:
  /// **'Next receipts'**
  String get nextReceipts;

  /// User-facing A receipt can be reversed only if no subsequent stock movement depends on it. Original records are retained.
  ///
  /// In en, this message translates to:
  /// **'A receipt can be reversed only if no subsequent stock movement depends on it. Original records are retained.'**
  String get aReceiptCanBeReversedOnlyIf;

  /// User-facing Settings saved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved.'**
  String get settingsSaved;

  /// User-facing Store settings
  ///
  /// In en, this message translates to:
  /// **'Store settings'**
  String get storeSettings;

  /// User-facing Management
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get management;

  /// User-facing Cannot open management. Try again.
  ///
  /// In en, this message translates to:
  /// **'Cannot open management. Try again.'**
  String get cannotOpenManagementTryAgain;

  /// User-facing Management locked
  ///
  /// In en, this message translates to:
  /// **'Management locked'**
  String get managementLocked;

  /// User-facing Remove stock
  ///
  /// In en, this message translates to:
  /// **'Remove stock'**
  String get removeStock;

  /// User-facing Cannot open storage.
  ///
  /// In en, this message translates to:
  /// **'Cannot open storage.'**
  String get cannotOpenStorage;

  /// User-facing Cannot open storage. Try again or check free device space.
  ///
  /// In en, this message translates to:
  /// **'Cannot open storage. Try again or check free device space.'**
  String get cannotOpenStorageTryAgainOrCheck;

  /// User-facing Local storage ready.
  ///
  /// In en, this message translates to:
  /// **'Local storage ready.'**
  String get localStorageReady;

  /// User-facing Check quantity, amount and date. Use whole units and a valid yyyy-MM-dd date.
  ///
  /// In en, this message translates to:
  /// **'Check quantity, amount and date. Use whole units and a valid yyyy-MM-dd date.'**
  String get checkQuantityAmountAndDateUseWhole;

  /// User-facing Stock and expiry warnings
  ///
  /// In en, this message translates to:
  /// **'Stock and expiry warnings'**
  String get stockAndExpiryWarnings;

  /// User-facing Low stock warning
  ///
  /// In en, this message translates to:
  /// **'Low stock warning'**
  String get lowStockWarning;

  /// User-facing Select category
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get selectCategory;

  /// User-facing Select supplier
  ///
  /// In en, this message translates to:
  /// **'Select supplier'**
  String get selectSupplier;

  /// User-facing Restore
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// User-facing Restore product?
  ///
  /// In en, this message translates to:
  /// **'Restore product?'**
  String get restoreProduct;

  /// User-facing Restore record?
  ///
  /// In en, this message translates to:
  /// **'Restore record?'**
  String get restoreRecord;

  /// User-facing Product history
  ///
  /// In en, this message translates to:
  /// **'Product history'**
  String get productHistory;

  /// User-facing Stock and price history
  ///
  /// In en, this message translates to:
  /// **'Stock and price history'**
  String get stockAndPriceHistory;

  /// User-facing Session locked
  ///
  /// In en, this message translates to:
  /// **'Session locked'**
  String get sessionLocked;

  /// User-facing Save
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// User-facing Save product
  ///
  /// In en, this message translates to:
  /// **'Save product'**
  String get saveProduct;

  /// User-facing Save recovery code
  ///
  /// In en, this message translates to:
  /// **'Save recovery code'**
  String get saveRecoveryCode;

  /// User-facing Save settings
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get saveSettings;

  /// User-facing Product status updated.
  ///
  /// In en, this message translates to:
  /// **'Product status updated.'**
  String get productStatusUpdated;

  /// User-facing Stock
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stock;

  /// User-facing Initial stock and purchase price
  ///
  /// In en, this message translates to:
  /// **'Initial stock and purchase price'**
  String get initialStockAndPurchasePrice;

  /// User-facing Initial stock
  ///
  /// In en, this message translates to:
  /// **'Initial stock'**
  String get initialStock;

  /// User-facing Minimum stock
  ///
  /// In en, this message translates to:
  /// **'Minimum stock'**
  String get minimumStock;

  /// User-facing Stock count
  ///
  /// In en, this message translates to:
  /// **'Stock count'**
  String get stockCount;

  /// User-facing Stock by receipt
  ///
  /// In en, this message translates to:
  /// **'Stock by receipt'**
  String get stockByReceipt;

  /// User-facing Low stock
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get lowStock;

  /// User-facing I have saved it
  ///
  /// In en, this message translates to:
  /// **'I have saved it'**
  String get iHaveSavedIt;

  /// User-facing Suppliers
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliers;

  /// User-facing Supplier (optional)
  ///
  /// In en, this message translates to:
  /// **'Supplier (optional)'**
  String get supplierOptional;

  /// User-facing Add product
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get addProduct;

  /// User-facing Show PIN
  ///
  /// In en, this message translates to:
  /// **'Show PIN'**
  String get showPin;

  /// User-facing Show archived
  ///
  /// In en, this message translates to:
  /// **'Show archived'**
  String get showArchived;

  /// User-facing Date not recorded
  ///
  /// In en, this message translates to:
  /// **'Date not recorded'**
  String get dateNotRecorded;

  /// User-facing Some stock has no recorded expiry date.
  ///
  /// In en, this message translates to:
  /// **'Some stock has no recorded expiry date.'**
  String get someStockHasNoRecordedExpiryDate;

  /// User-facing Expiry date yyyy-MM-dd (optional)
  ///
  /// In en, this message translates to:
  /// **'Expiry date yyyy-MM-dd (optional)'**
  String get expiryDateYyyyMmDdOptional;

  /// User-facing No supplier
  ///
  /// In en, this message translates to:
  /// **'No supplier'**
  String get noSupplier;

  /// User-facing Cannot undo.
  ///
  /// In en, this message translates to:
  /// **'Cannot undo.'**
  String get cannotUndo;

  /// User-facing My store
  ///
  /// In en, this message translates to:
  /// **'My store'**
  String get myStore;

  /// User-facing Total
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// User-facing Close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// User-facing Close this dialog and enter your PIN again.
  ///
  /// In en, this message translates to:
  /// **'Close this dialog and enter your PIN again.'**
  String get closeThisDialogAndEnterYourPin;

  /// User-facing Change PIN or recovery
  ///
  /// In en, this message translates to:
  /// **'Change PIN or recovery'**
  String get changePinOrRecovery;

  /// User-facing Change PIN or renew recovery code
  ///
  /// In en, this message translates to:
  /// **'Change PIN or renew recovery code'**
  String get changePinOrRenewRecoveryCode;

  /// User-facing Edit product
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get editProduct;

  /// User-facing Edit record
  ///
  /// In en, this message translates to:
  /// **'Edit record'**
  String get editRecord;

  /// User-facing Receipt footer (optional)
  ///
  /// In en, this message translates to:
  /// **'Receipt footer (optional)'**
  String get receiptFooterOptional;

  /// User-facing Undo
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// User-facing WhatsApp or phone (optional)
  ///
  /// In en, this message translates to:
  /// **'WhatsApp or phone (optional)'**
  String get whatsappOrPhoneOptional;

  /// User-facing Store time zone, e.g. Asia/Jakarta
  ///
  /// In en, this message translates to:
  /// **'Store time zone, e.g. Asia/Jakarta'**
  String get storeTimeZoneEGAsiaJakarta;

  /// User-facing Product not found.
  ///
  /// In en, this message translates to:
  /// **'Product not found.'**
  String get productNotFound;

  /// User-facing Product is archived. Restore it first.
  ///
  /// In en, this message translates to:
  /// **'Product is archived. Restore it first.'**
  String get productIsArchivedRestoreItFirst;

  /// User-facing Category or supplier unavailable. Select again.
  ///
  /// In en, this message translates to:
  /// **'Category or supplier unavailable. Select again.'**
  String get categoryOrSupplierUnavailableSelectAgain;

  /// User-facing Product name is required.
  ///
  /// In en, this message translates to:
  /// **'Product name is required.'**
  String get productNameIsRequired;

  /// User-facing Code or barcode belongs to an archived product. Restore it or use a different code.
  ///
  /// In en, this message translates to:
  /// **'Code or barcode belongs to an archived product. Restore it or use a different code.'**
  String get codeOrBarcodeBelongsToAnArchived;

  /// User-facing Code or barcode is already used by another product.
  ///
  /// In en, this message translates to:
  /// **'Code or barcode is already used by another product.'**
  String get codeOrBarcodeIsAlreadyUsedBy;

  /// User-facing Purchase price is required for initial stock.
  ///
  /// In en, this message translates to:
  /// **'Purchase price is required for initial stock.'**
  String get purchasePriceIsRequiredForInitialStock;

  /// User-facing Dated stock remains. Handle it before disabling expiry tracking.
  ///
  /// In en, this message translates to:
  /// **'Dated stock remains. Handle it before disabling expiry tracking.'**
  String get datedStockRemainsHandleItBeforeDisabling;

  /// User-facing Product changed. Reload before saving.
  ///
  /// In en, this message translates to:
  /// **'Product changed. Reload before saving.'**
  String get productChangedReloadBeforeSaving;

  /// User-facing Product changed. Reload first.
  ///
  /// In en, this message translates to:
  /// **'Product changed. Reload first.'**
  String get productChangedReloadFirst;

  /// User-facing Cannot undo: the time limit passed or another change occurred.
  ///
  /// In en, this message translates to:
  /// **'Cannot undo: the time limit passed or another change occurred.'**
  String get cannotUndoTheTimeLimitPassedOr;

  /// User-facing Stock remains. Archiving is refused.
  ///
  /// In en, this message translates to:
  /// **'Stock remains. Archiving is refused.'**
  String get stockRemainsArchivingIsRefused;

  /// User-facing Invalid operation identifier.
  ///
  /// In en, this message translates to:
  /// **'Invalid operation identifier.'**
  String get invalidOperationIdentifier;

  /// User-facing Operation identifier already used for different data.
  ///
  /// In en, this message translates to:
  /// **'Operation identifier already used for different data.'**
  String get operationIdentifierAlreadyUsedForDifferentData;

  /// User-facing Enable expiry tracking before recording dates.
  ///
  /// In en, this message translates to:
  /// **'Enable expiry tracking before recording dates.'**
  String get enableExpiryTrackingBeforeRecordingDates;

  /// User-facing Stock changed. Retry with current data.
  ///
  /// In en, this message translates to:
  /// **'Stock changed. Retry with current data.'**
  String get stockChangedRetryWithCurrentData;

  /// User-facing Correction reason is required.
  ///
  /// In en, this message translates to:
  /// **'Correction reason is required.'**
  String get correctionReasonIsRequired;

  /// User-facing Receipt cannot be reversed through this flow.
  ///
  /// In en, this message translates to:
  /// **'Receipt cannot be reversed through this flow.'**
  String get receiptCannotBeReversedThroughThisFlow;

  /// User-facing Receipt already reversed.
  ///
  /// In en, this message translates to:
  /// **'Receipt already reversed.'**
  String get receiptAlreadyReversed;

  /// User-facing Stock count reason is required.
  ///
  /// In en, this message translates to:
  /// **'Stock count reason is required.'**
  String get stockCountReasonIsRequired;

  /// User-facing Physical quantity already matches the record.
  ///
  /// In en, this message translates to:
  /// **'Physical quantity already matches the record.'**
  String get physicalQuantityAlreadyMatchesTheRecord;

  /// User-facing Purchase price is required when adding to empty stock.
  ///
  /// In en, this message translates to:
  /// **'Purchase price is required when adding to empty stock.'**
  String get purchasePriceIsRequiredWhenAddingTo;

  /// User-facing Stock removal reason is required.
  ///
  /// In en, this message translates to:
  /// **'Stock removal reason is required.'**
  String get stockRemovalReasonIsRequired;

  /// User-facing Insufficient batch quantity.
  ///
  /// In en, this message translates to:
  /// **'Insufficient batch quantity.'**
  String get insufficientBatchQuantity;

  /// User-facing Batch list changed. Reload.
  ///
  /// In en, this message translates to:
  /// **'Batch list changed. Reload.'**
  String get batchListChangedReload;

  /// User-facing Name is required.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get nameIsRequired;

  /// User-facing Record unavailable. Reload.
  ///
  /// In en, this message translates to:
  /// **'Record unavailable. Reload.'**
  String get recordUnavailableReload;

  /// User-facing Record not found.
  ///
  /// In en, this message translates to:
  /// **'Record not found.'**
  String get recordNotFound;

  /// User-facing History filter changed. Reload.
  ///
  /// In en, this message translates to:
  /// **'History filter changed. Reload.'**
  String get historyFilterChangedReload;

  /// User-facing Filter changed. Reload list.
  ///
  /// In en, this message translates to:
  /// **'Filter changed. Reload list.'**
  String get filterChangedReloadList;

  /// User-facing Management session locked. Enter PIN again.
  ///
  /// In en, this message translates to:
  /// **'Management session locked. Enter PIN again.'**
  String get managementSessionLockedEnterPinAgain;

  /// User-facing PIN must contain four digits.
  ///
  /// In en, this message translates to:
  /// **'PIN must contain four digits.'**
  String get pinMustContainFourDigits;

  /// User-facing PIN confirmation does not match.
  ///
  /// In en, this message translates to:
  /// **'PIN confirmation does not match.'**
  String get pinConfirmationDoesNotMatch;

  /// User-facing Store name is required.
  ///
  /// In en, this message translates to:
  /// **'Store name is required.'**
  String get storeNameIsRequired;

  /// User-facing Create a management PIN first.
  ///
  /// In en, this message translates to:
  /// **'Create a management PIN first.'**
  String get createAManagementPinFirst;

  /// User-facing Unsupported PIN configuration.
  ///
  /// In en, this message translates to:
  /// **'Unsupported PIN configuration.'**
  String get unsupportedPinConfiguration;

  /// User-facing PIN or recovery code does not match.
  ///
  /// In en, this message translates to:
  /// **'PIN or recovery code does not match.'**
  String get pinOrRecoveryCodeDoesNotMatch;

  /// User-facing Session locked. Enter PIN again.
  ///
  /// In en, this message translates to:
  /// **'Session locked. Enter PIN again.'**
  String get sessionLockedEnterPinAgain;

  /// User-facing PIN change is in progress.
  ///
  /// In en, this message translates to:
  /// **'PIN change is in progress.'**
  String get pinChangeIsInProgress;

  /// User-facing Unknown time zone. Example: Asia/Jakarta.
  ///
  /// In en, this message translates to:
  /// **'Unknown time zone. Example: Asia/Jakarta.'**
  String get unknownTimeZoneExampleAsiaJakarta;

  /// User-facing Price change
  ///
  /// In en, this message translates to:
  /// **'Price change'**
  String get priceChange;

  /// User-facing Undo price
  ///
  /// In en, this message translates to:
  /// **'Undo price'**
  String get undoPrice;

  /// Language
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Operation failed. Try again or check device storage.
  ///
  /// In en, this message translates to:
  /// **'Operation failed. Try again or check device storage.'**
  String get operationFailed;

  /// Currency cannot be changed because financial data already exists. A dedicated migration or conversion is required.
  ///
  /// In en, this message translates to:
  /// **'Currency cannot be changed because financial data already exists. A dedicated migration or conversion is required.'**
  String get currencyConversionRequired;

  /// Currency
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// Amount currency differs from the store currency.
  ///
  /// In en, this message translates to:
  /// **'Amount currency differs from the store currency.'**
  String get currencyMismatch;

  /// IDR uses whole rupiah. USD, MYR and EUR use two decimals. Language does not change currency.
  ///
  /// In en, this message translates to:
  /// **'IDR uses whole rupiah. USD, MYR and EUR use two decimals. Language does not change currency.'**
  String get currencyScaleHelp;

  /// Indonesian rupiah · IDR
  ///
  /// In en, this message translates to:
  /// **'IDR · Indonesian rupiah'**
  String get rupiahCurrency;

  /// US dollar · USD
  ///
  /// In en, this message translates to:
  /// **'USD · US dollar'**
  String get dollarCurrency;

  /// Malaysian ringgit · MYR
  ///
  /// In en, this message translates to:
  /// **'MYR · Malaysian ringgit'**
  String get ringgitCurrency;

  /// Euro · EUR
  ///
  /// In en, this message translates to:
  /// **'EUR · Euro'**
  String get euroCurrency;

  /// User-facing Try again in {count, plural, =1{1 second} other{{count} seconds}}.
  ///
  /// In en, this message translates to:
  /// **'Try again in {count, plural, =1{1 second} other{{count} seconds}}.'**
  String retryAfterSeconds(int count);

  /// User-facing {count, plural, =1{1 expired unit} other{{count} expired units}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 expired unit} other{{count} expired units}}'**
  String expiredUnits(int count);

  /// User-facing Physical stock {physical} • Saleable {saleable} • Expired {expired}
  ///
  /// In en, this message translates to:
  /// **'Physical stock {physical} • Saleable {saleable} • Expired {expired}'**
  String stockSummary(int physical, int saleable, int expired);

  /// User-facing {price} • Stock {physical} • Saleable {saleable}
  ///
  /// In en, this message translates to:
  /// **'{price} • Stock {physical} • Saleable {saleable}'**
  String productSummary(String price, int physical, int saleable);

  /// User-facing Selling price {amount}
  ///
  /// In en, this message translates to:
  /// **'Selling price {amount}'**
  String sellingPriceAmount(String amount);

  /// User-facing Average purchase price {amount}
  ///
  /// In en, this message translates to:
  /// **'Average purchase price {amount}'**
  String averageCostAmount(String amount);

  /// User-facing Code {code}
  ///
  /// In en, this message translates to:
  /// **'Code {code}'**
  String storeCodeValue(String code);

  /// User-facing Barcode {code}
  ///
  /// In en, this message translates to:
  /// **'Barcode {code}'**
  String barcodeValue(String code);

  /// User-facing {count, plural, =1{1 unit} other{{count} units}} • {date}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit} other{{count} units}} • {date}'**
  String batchUnits(int count, String date);

  /// User-facing {count} units • {amount}
  ///
  /// In en, this message translates to:
  /// **'{count} units • {amount}'**
  String stockChange(int count, String amount);

  /// User-facing Stock remains. Record removal or a stock count before archiving.
  ///
  /// In en, this message translates to:
  /// **'Stock remains. Record removal or a stock count before archiving.'**
  String get stockRemainsHandleBeforeArchive;

  /// User-facing Subsequent stock movements exist. Use a stock count or the appropriate removal.
  ///
  /// In en, this message translates to:
  /// **'Subsequent stock movements exist. Use a stock count or the appropriate removal.'**
  String get stockDependencyBlocksReversal;

  /// User-facing Batch stock does not match. Check the records.
  ///
  /// In en, this message translates to:
  /// **'Batch stock does not match. Check the records.'**
  String get batchReconciliationRequired;

  /// User-facing Category still in use. Move products to another category first.
  ///
  /// In en, this message translates to:
  /// **'Category still in use. Move products to another category first.'**
  String get categoryStillUsed;

  /// User-facing PIN already configured. Use PIN change or recovery code.
  ///
  /// In en, this message translates to:
  /// **'PIN already configured. Use PIN change or recovery code.'**
  String get pinAlreadyConfigured;

  /// User-facing Cannot load list. Try again.
  ///
  /// In en, this message translates to:
  /// **'Cannot load list. Try again.'**
  String get listLoadFailed;

  /// User-facing Loading…
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// Add category
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// Add supplier
  ///
  /// In en, this message translates to:
  /// **'Add supplier'**
  String get addSupplier;

  /// Insufficient stock quantity.
  ///
  /// In en, this message translates to:
  /// **'Insufficient stock quantity.'**
  String get insufficientStock;

  /// Insufficient saleable stock.
  ///
  /// In en, this message translates to:
  /// **'Insufficient saleable stock.'**
  String get insufficientSaleableStock;

  /// Native name and indicator for Indonesian language
  ///
  /// In en, this message translates to:
  /// **'ID · Bahasa Indonesia'**
  String get indonesianLanguage;

  /// Native name and indicator for English language
  ///
  /// In en, this message translates to:
  /// **'EN · English'**
  String get englishLanguage;

  /// M3 cashier/debt message: m3DraftUnavailable
  ///
  /// In en, this message translates to:
  /// **'The basket draft is unavailable or already completed.'**
  String get m3DraftUnavailable;

  /// M3 cashier/debt message: m3DraftChanged
  ///
  /// In en, this message translates to:
  /// **'The basket changed. Review it before continuing.'**
  String get m3DraftChanged;

  /// M3 cashier/debt message: m3UndoExpired
  ///
  /// In en, this message translates to:
  /// **'Cannot undo: the time limit passed or the basket changed.'**
  String get m3UndoExpired;

  /// M3 cashier/debt message: m3SaleUnavailable
  ///
  /// In en, this message translates to:
  /// **'The sale is unavailable.'**
  String get m3SaleUnavailable;

  /// M3 cashier/debt message: m3AttemptChanged
  ///
  /// In en, this message translates to:
  /// **'This attempt is already saved with different details. Open the saved result.'**
  String get m3AttemptChanged;

  /// M3 cashier/debt message: m3AmbiguousCode
  ///
  /// In en, this message translates to:
  /// **'This code matches more than one product. Choose a search result.'**
  String get m3AmbiguousCode;

  /// M3 cashier/debt message: m3OperationFailed
  ///
  /// In en, this message translates to:
  /// **'The operation failed. Try again; your basket remains saved.'**
  String get m3OperationFailed;

  /// M3 cashier/debt message: m3SearchFailed
  ///
  /// In en, this message translates to:
  /// **'Search failed. Try typing again.'**
  String get m3SearchFailed;

  /// M3 cashier/debt message: m3StockChanged
  ///
  /// In en, this message translates to:
  /// **'Stock changed. Review the basket.'**
  String get m3StockChanged;

  /// M3 cashier/debt message: m3EmptyCart
  ///
  /// In en, this message translates to:
  /// **'Add products before paying.'**
  String get m3EmptyCart;

  /// M3 cashier/debt message: m3InvalidPayment
  ///
  /// In en, this message translates to:
  /// **'Check the payment amount. A partial payment must be above zero and below the total.'**
  String get m3InvalidPayment;

  /// M3 cashier/debt message: m3PricesChanged
  ///
  /// In en, this message translates to:
  /// **'Product prices changed.'**
  String get m3PricesChanged;

  /// M3 cashier/debt message: m3CustomerUnavailable
  ///
  /// In en, this message translates to:
  /// **'The customer is unavailable. Select again.'**
  String get m3CustomerUnavailable;

  /// M3 cashier/debt message: m3CustomerRequired
  ///
  /// In en, this message translates to:
  /// **'A customer name is required to record debt.'**
  String get m3CustomerRequired;

  /// M3 cashier/debt message: m3SaleMovement
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get m3SaleMovement;

  /// M3 cashier/debt message: m3PaymentTooLarge
  ///
  /// In en, this message translates to:
  /// **'Payment cannot exceed the outstanding debt.'**
  String get m3PaymentTooLarge;

  /// M3 cashier/debt message: m3PaymentPlanChanged
  ///
  /// In en, this message translates to:
  /// **'Debt changed since the preview. Review a new payment allocation.'**
  String get m3PaymentPlanChanged;

  /// M3 cashier/debt message: m3RecoveredSale
  ///
  /// In en, this message translates to:
  /// **'Saved sale recovered. This basket is already completed.'**
  String get m3RecoveredSale;

  /// M3 cashier/debt message: m3SaleSaved
  ///
  /// In en, this message translates to:
  /// **'Sale saved.'**
  String get m3SaleSaved;

  /// M3 cashier/debt message: m3ReceiptNumber
  ///
  /// In en, this message translates to:
  /// **'Sale number'**
  String get m3ReceiptNumber;

  /// M3 cashier/debt message: m3Customer
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get m3Customer;

  /// M3 cashier/debt message: m3Paid
  ///
  /// In en, this message translates to:
  /// **'Recorded payment'**
  String get m3Paid;

  /// M3 cashier/debt message: m3RemainingDebt
  ///
  /// In en, this message translates to:
  /// **'Outstanding debt'**
  String get m3RemainingDebt;

  /// M3 cashier/debt message: m3PrintingLater
  ///
  /// In en, this message translates to:
  /// **'Sale saved. Receipt printing is not available yet.'**
  String get m3PrintingLater;

  /// M3 cashier/debt message: m3NextSale
  ///
  /// In en, this message translates to:
  /// **'Next basket'**
  String get m3NextSale;

  /// M3 cashier/debt message: m3PaidFull
  ///
  /// In en, this message translates to:
  /// **'Paid in full'**
  String get m3PaidFull;

  /// M3 cashier/debt message: m3PartialDebt
  ///
  /// In en, this message translates to:
  /// **'Partly on credit'**
  String get m3PartialDebt;

  /// M3 cashier/debt message: m3AllDebt
  ///
  /// In en, this message translates to:
  /// **'Entirely on credit'**
  String get m3AllDebt;

  /// M3 cashier/debt message: m3PaidExplanation
  ///
  /// In en, this message translates to:
  /// **'Payment is recorded for the total. Handle physical money in the store.'**
  String get m3PaidExplanation;

  /// M3 cashier/debt message: m3PaidAmount
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get m3PaidAmount;

  /// M3 cashier/debt message: m3CustomerName
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get m3CustomerName;

  /// M3 cashier/debt message: m3PhoneOptional
  ///
  /// In en, this message translates to:
  /// **'Customer phone (optional)'**
  String get m3PhoneOptional;

  /// M3 cashier/debt message: m3SelectedCustomer
  ///
  /// In en, this message translates to:
  /// **'The selected customer will be used.'**
  String get m3SelectedCustomer;

  /// M3 cashier/debt message: m3ChooseCustomer
  ///
  /// In en, this message translates to:
  /// **'Select an existing customer if appropriate.'**
  String get m3ChooseCustomer;

  /// M3 cashier/debt message: m3NoPhone
  ///
  /// In en, this message translates to:
  /// **'No phone recorded'**
  String get m3NoPhone;

  /// M3 cashier/debt message: m3CreateSeparateCustomer
  ///
  /// In en, this message translates to:
  /// **'Create a new customer, even with the same name'**
  String get m3CreateSeparateCustomer;

  /// M3 cashier/debt message: m3ConfirmSale
  ///
  /// In en, this message translates to:
  /// **'Save sale'**
  String get m3ConfirmSale;

  /// M3 cashier/debt message: m3AcceptPricesExplanation
  ///
  /// In en, this message translates to:
  /// **'The basket still shows the accepted prices. Accept the latest prices to continue payment.'**
  String get m3AcceptPricesExplanation;

  /// M3 cashier/debt message: m3AcceptPrices
  ///
  /// In en, this message translates to:
  /// **'Accept latest prices'**
  String get m3AcceptPrices;

  /// M3 cashier/debt message: m3ClearSearch
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get m3ClearSearch;

  /// M3 cashier/debt message: m3Available
  ///
  /// In en, this message translates to:
  /// **'Saleable stock'**
  String get m3Available;

  /// M3 cashier/debt message: m3ClearCart
  ///
  /// In en, this message translates to:
  /// **'Clear basket'**
  String get m3ClearCart;

  /// M3 cashier/debt message: m3ClearCartExplanation
  ///
  /// In en, this message translates to:
  /// **'Remove all products from the basket? Undo is available for five seconds if the basket has not changed.'**
  String get m3ClearCartExplanation;

  /// M3 cashier/debt message: m3CartRemoved
  ///
  /// In en, this message translates to:
  /// **'Basket updated.'**
  String get m3CartRemoved;

  /// M3 cashier/debt message: m3Decrease
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get m3Decrease;

  /// M3 cashier/debt message: m3Increase
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get m3Increase;

  /// M3 cashier/debt message: m3RemoveItem
  ///
  /// In en, this message translates to:
  /// **'Remove basket item'**
  String get m3RemoveItem;

  /// M3 cashier/debt message: m3Quantity
  ///
  /// In en, this message translates to:
  /// **'Product quantity'**
  String get m3Quantity;

  /// M3 cashier/debt message: m3SearchCustomers
  ///
  /// In en, this message translates to:
  /// **'Search customer name (Enter)'**
  String get m3SearchCustomers;

  /// M3 cashier/debt message: m3NoDebt
  ///
  /// In en, this message translates to:
  /// **'No outstanding debts.'**
  String get m3NoDebt;

  /// M3 cashier/debt message: m3LoadMore
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get m3LoadMore;

  /// M3 cashier/debt message: m3PaymentPreview
  ///
  /// In en, this message translates to:
  /// **'Debt payment details'**
  String get m3PaymentPreview;

  /// M3 cashier/debt message: m3OldestFirst
  ///
  /// In en, this message translates to:
  /// **'Payment is allocated to the oldest sales first.'**
  String get m3OldestFirst;

  /// M3 cashier/debt message: m3ConfirmPayment
  ///
  /// In en, this message translates to:
  /// **'Record this payment'**
  String get m3ConfirmPayment;

  /// M3 cashier/debt message: m3RepaymentAmount
  ///
  /// In en, this message translates to:
  /// **'Repayment amount'**
  String get m3RepaymentAmount;

  /// M3 cashier/debt message: m3RecordPayment
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get m3RecordPayment;

  /// M3 cashier/debt message: m3SaleHistory
  ///
  /// In en, this message translates to:
  /// **'Sale history'**
  String get m3SaleHistory;

  /// M3 cashier/debt message: m3CostSnapshot
  ///
  /// In en, this message translates to:
  /// **'Stored cost of goods sold'**
  String get m3CostSnapshot;

  /// M3 cashier/debt message: m3LaterFeatures
  ///
  /// In en, this message translates to:
  /// **'Full reports, sale corrections, printing and backups are not available yet.'**
  String get m3LaterFeatures;

  /// M3.1 wholesale/packaging: m31WholeQuantity
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number using digits 0–9.'**
  String get m31WholeQuantity;

  /// M3.1 wholesale/packaging: m31PackRequired
  ///
  /// In en, this message translates to:
  /// **'Fill in the box label and pcs per box, or leave both empty.'**
  String get m31PackRequired;

  /// M3.1 wholesale/packaging: m31WholesalePositive
  ///
  /// In en, this message translates to:
  /// **'Wholesale price must be greater than zero. Leave empty if unavailable.'**
  String get m31WholesalePositive;

  /// M3.1 wholesale/packaging: m31ConflictingInput
  ///
  /// In en, this message translates to:
  /// **'Use one input unit for this receipt.'**
  String get m31ConflictingInput;

  /// M3.1 wholesale/packaging: m31WholesaleChange
  ///
  /// In en, this message translates to:
  /// **'Wholesale price change'**
  String get m31WholesaleChange;

  /// M3.1 wholesale/packaging: m31WholesaleUnavailable
  ///
  /// In en, this message translates to:
  /// **'Wholesale price is no longer available. Choose retail or remove this line before paying.'**
  String get m31WholesaleUnavailable;

  /// M3.1 wholesale/packaging: m31Wholesale
  ///
  /// In en, this message translates to:
  /// **'Wholesale'**
  String get m31Wholesale;

  /// M3.1 wholesale/packaging: m31WholesalePerBase
  ///
  /// In en, this message translates to:
  /// **'Price per pcs, applies to the entire quantity on this line.'**
  String get m31WholesalePerBase;

  /// M3.1 wholesale/packaging: m31UseRetail
  ///
  /// In en, this message translates to:
  /// **'Use retail price'**
  String get m31UseRetail;

  /// M3.1 wholesale/packaging: m31WholesaleOptional
  ///
  /// In en, this message translates to:
  /// **'Wholesale price — optional'**
  String get m31WholesaleOptional;

  /// M3.1 wholesale/packaging: m31WholesalePrice
  ///
  /// In en, this message translates to:
  /// **'Wholesale price per pcs'**
  String get m31WholesalePrice;

  /// M3.1 wholesale/packaging: m31WholesaleHelp
  ///
  /// In en, this message translates to:
  /// **'Empty means unavailable. The cashier selects Wholesale manually; this is not a price per box.'**
  String get m31WholesaleHelp;

  /// M3.1 wholesale/packaging: m31PackOptional
  ///
  /// In en, this message translates to:
  /// **'Box packaging — optional'**
  String get m31PackOptional;

  /// M3.1 wholesale/packaging: m31PackLabel
  ///
  /// In en, this message translates to:
  /// **'Box label'**
  String get m31PackLabel;

  /// M3.1 wholesale/packaging: m31PackSize
  ///
  /// In en, this message translates to:
  /// **'Pcs per box'**
  String get m31PackSize;

  /// M3.1 wholesale/packaging: m31PackConfigHelp
  ///
  /// In en, this message translates to:
  /// **'Packaging helps warehouse input. Changing its size does not change stock or old receipts. Sales remain in pcs.'**
  String get m31PackConfigHelp;

  /// M3.1 wholesale/packaging: m31InputUnit
  ///
  /// In en, this message translates to:
  /// **'Input unit'**
  String get m31InputUnit;

  /// M3.1 wholesale/packaging: m31BaseUnit
  ///
  /// In en, this message translates to:
  /// **'Base unit (pcs)'**
  String get m31BaseUnit;

  /// M3.1 wholesale/packaging: m31PackUnit
  ///
  /// In en, this message translates to:
  /// **'Box'**
  String get m31PackUnit;

  /// M3.1 wholesale/packaging: m31PackCount
  ///
  /// In en, this message translates to:
  /// **'Number of boxes'**
  String get m31PackCount;

  /// M3.1 wholesale/packaging: m31DigitsHelp
  ///
  /// In en, this message translates to:
  /// **'Use digits 0–9; signs, fractions and scientific notation are not accepted.'**
  String get m31DigitsHelp;

  /// M3.1 wholesale/packaging: m31ReceiptOverride
  ///
  /// In en, this message translates to:
  /// **'May differ for this receipt/count; the product configuration stays unchanged.'**
  String get m31ReceiptOverride;

  /// M3.1 wholesale/packaging: m31PreviewInvalid
  ///
  /// In en, this message translates to:
  /// **'Enter a valid quantity and pack size to preview pcs.'**
  String get m31PreviewInvalid;

  /// M3.1 wholesale/packaging: m31PurchasePerPack
  ///
  /// In en, this message translates to:
  /// **'Purchase price per box'**
  String get m31PurchasePerPack;

  /// M3.1 wholesale/packaging: m31PriceWarning
  ///
  /// In en, this message translates to:
  /// **'Check wholesale price'**
  String get m31PriceWarning;

  /// M3.1 wholesale/packaging: m31AboveRetail
  ///
  /// In en, this message translates to:
  /// **'Wholesale price exceeds retail. Continue only if this is intentional.'**
  String get m31AboveRetail;

  /// M3.1 wholesale/packaging: m31BelowCost
  ///
  /// In en, this message translates to:
  /// **'Wholesale price is below average cost. A sale may make a loss.'**
  String get m31BelowCost;

  /// M3.1 wholesale/packaging: m31BaseStock
  ///
  /// In en, this message translates to:
  /// **'Base-unit stock'**
  String get m31BaseStock;

  /// M3.1 wholesale/packaging: m31Unavailable
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get m31Unavailable;

  /// M3.1 wholesale/packaging: m31Retail
  ///
  /// In en, this message translates to:
  /// **'Retail'**
  String get m31Retail;

  /// M3.1 wholesale/packaging: m31ReceiptInput
  ///
  /// In en, this message translates to:
  /// **'Receipt input'**
  String get m31ReceiptInput;

  /// M3.1 wholesale/packaging: m31InputPrice
  ///
  /// In en, this message translates to:
  /// **'Purchase cost per input unit'**
  String get m31InputPrice;

  /// M3.1 wholesale/packaging: m31ReceiptValue
  ///
  /// In en, this message translates to:
  /// **'Total receipt value'**
  String get m31ReceiptValue;

  /// M3.1 wholesale/packaging: m31LegacyInput
  ///
  /// In en, this message translates to:
  /// **'The original receipt input unit was not recorded. Stock quantity remains in base units.'**
  String get m31LegacyInput;

  /// M3.1 wholesale/packaging: m31ConversionPreview
  ///
  /// In en, this message translates to:
  /// **'{count} boxes × {size} pcs = {total} pcs'**
  String m31ConversionPreview(String count, String size, String total);

  /// M4 reports/corrections: Reports
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get m4Reports;

  /// M4 reports/corrections: Net sales
  ///
  /// In en, this message translates to:
  /// **'Net sales'**
  String get m4NetSales;

  /// M4 reports/corrections: Gross profit
  ///
  /// In en, this message translates to:
  /// **'Gross profit'**
  String get m4GrossProfit;

  /// M4 reports/corrections: Net payments in period
  ///
  /// In en, this message translates to:
  /// **'Net payments in period'**
  String get m4NetPayments;

  /// M4 reports/corrections: Payments at checkout
  ///
  /// In en, this message translates to:
  /// **'Payments at checkout'**
  String get m4CheckoutPayments;

  /// M4 reports/corrections: Receivable repayments
  ///
  /// In en, this message translates to:
  /// **'Receivable repayments'**
  String get m4Repayments;

  /// M4 reports/corrections: Payments with unknown origin
  ///
  /// In en, this message translates to:
  /// **'Payments with unknown origin'**
  String get m4UnknownPayments;

  /// M4 reports/corrections: Current receivables balance
  ///
  /// In en, this message translates to:
  /// **'Current receivables balance'**
  String get m4CurrentReceivables;

  /// M4 reports/corrections: Current inventory value
  ///
  /// In en, this message translates to:
  /// **'Current inventory value'**
  String get m4InventoryValue;

  /// M4 reports/corrections: Current physical stock quantity
  ///
  /// In en, this message translates to:
  /// **'Current physical stock quantity'**
  String get m4PhysicalStock;

  /// M4 reports/corrections: Current expired quantity
  ///
  /// In en, this message translates to:
  /// **'Current expired quantity'**
  String get m4ExpiredStock;

  /// M4 reports/corrections: Sales recorded in period
  ///
  /// In en, this message translates to:
  /// **'Sales recorded in period'**
  String get m4SalesCount;

  /// M4 reports/corrections: Sales cancelled in period
  ///
  /// In en, this message translates to:
  /// **'Sales cancelled in period'**
  String get m4ReturnsCount;

  /// M4 reports/corrections: Choose period
  ///
  /// In en, this message translates to:
  /// **'Choose period'**
  String get m4SelectPeriod;

  /// M4 reports/corrections: This month
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get m4ThisMonth;

  /// M4 reports/corrections: All time
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get m4AllTime;

  /// M4 reports/corrections: All statuses
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get m4AllStatuses;

  /// M4 reports/corrections: Active
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get m4Active;

  /// M4 reports/corrections: Cancelled
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get m4Cancelled;

  /// M4 reports/corrections: Reversal
  ///
  /// In en, this message translates to:
  /// **'Reversal'**
  String get m4Reversal;

  /// M4 reports/corrections: Sale
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get m4SaleEvent;

  /// M4 reports/corrections: Sales details
  ///
  /// In en, this message translates to:
  /// **'Sales details'**
  String get m4SalesEvents;

  /// M4 reports/corrections: Payment ledger
  ///
  /// In en, this message translates to:
  /// **'Payment ledger'**
  String get m4PaymentLedger;

  /// M4 reports/corrections: All customers
  ///
  /// In en, this message translates to:
  /// **'All customers'**
  String get m4AllCustomers;

  /// M4 reports/corrections: Customer filter
  ///
  /// In en, this message translates to:
  /// **'Customer filter'**
  String get m4CustomerFilter;

  /// M4 reports/corrections: No customer
  ///
  /// In en, this message translates to:
  /// **'No customer'**
  String get m4NoCustomer;

  /// M4 reports/corrections: Cancellations reduce amounts on the reversal date. Repayments are not new sales. Gross profit excludes operating expenses.
  ///
  /// In en, this message translates to:
  /// **'Cancellations reduce amounts on the reversal date. Repayments are not new sales. Gross profit excludes operating expenses.'**
  String get m4PeriodPolicy;

  /// M4 reports/corrections: Receivables show current balances for the selected customers. Inventory shows the current whole-store position, separate from the report period.
  ///
  /// In en, this message translates to:
  /// **'Receivables show current balances for the selected customers. Inventory shows the current whole-store position, separate from the report period.'**
  String get m4CurrentSnapshot;

  /// M4 reports/corrections: Reload from the start
  ///
  /// In en, this message translates to:
  /// **'Reload from the start'**
  String get m4ReloadStart;

  /// M4 reports/corrections: Check records agree
  ///
  /// In en, this message translates to:
  /// **'Check records agree'**
  String get m4Reconcile;

  /// M4 reports/corrections: The checked records agree.
  ///
  /// In en, this message translates to:
  /// **'The checked records agree.'**
  String get m4Consistent;

  /// M4 reports/corrections: Some records disagree. Do not correct them by deleting history.
  ///
  /// In en, this message translates to:
  /// **'Some records disagree. Do not correct them by deleting history.'**
  String get m4Inconsistent;

  /// M4 reports/corrections: Stock quantities
  ///
  /// In en, this message translates to:
  /// **'Stock quantities'**
  String get m4StockCheck;

  /// M4 reports/corrections: Inventory values
  ///
  /// In en, this message translates to:
  /// **'Inventory values'**
  String get m4ValueCheck;

  /// M4 reports/corrections: Sales items
  ///
  /// In en, this message translates to:
  /// **'Sales items'**
  String get m4SaleCheck;

  /// M4 reports/corrections: Batch allocations
  ///
  /// In en, this message translates to:
  /// **'Batch allocations'**
  String get m4BatchCheck;

  /// M4 reports/corrections: Payment allocations
  ///
  /// In en, this message translates to:
  /// **'Payment allocations'**
  String get m4PaymentCheck;

  /// M4 reports/corrections: Receivables balances
  ///
  /// In en, this message translates to:
  /// **'Receivables balances'**
  String get m4DebtCheck;

  /// M4 reports/corrections: Returned-goods records
  ///
  /// In en, this message translates to:
  /// **'Returned-goods records'**
  String get m4ReturnCheck;

  /// M4 reports/corrections: Record relationships
  ///
  /// In en, this message translates to:
  /// **'Record relationships'**
  String get m4RelationsCheck;

  /// M4 reports/corrections: Cancel sale
  ///
  /// In en, this message translates to:
  /// **'Cancel sale'**
  String get m4CancelSale;

  /// M4 reports/corrections: Cancel payment
  ///
  /// In en, this message translates to:
  /// **'Cancel payment'**
  String get m4CancelPayment;

  /// M4 reports/corrections: Correction reason
  ///
  /// In en, this message translates to:
  /// **'Correction reason'**
  String get m4Reason;

  /// M4 reports/corrections: All goods have actually been returned to the store.
  ///
  /// In en, this message translates to:
  /// **'All goods have actually been returned to the store.'**
  String get m4GoodsReturned;

  /// M4 reports/corrections: Any relevant refund or money adjustment is handled in the store; the app only reverses the records.
  ///
  /// In en, this message translates to:
  /// **'Any relevant refund or money adjustment is handled in the store; the app only reverses the records.'**
  String get m4MoneyHandled;

  /// M4 reports/corrections: A correction adds reversal records and keeps the original transaction. Full sale cancellation is refused while a later repayment remains active.
  ///
  /// In en, this message translates to:
  /// **'A correction adds reversal records and keeps the original transaction. Full sale cancellation is refused while a later repayment remains active.'**
  String get m4CorrectionNotice;

  /// M4 reports/corrections: Confirm cancellation
  ///
  /// In en, this message translates to:
  /// **'Confirm cancellation'**
  String get m4ConfirmCancellation;

  /// M4 reports/corrections: Enter a correction reason.
  ///
  /// In en, this message translates to:
  /// **'Enter a correction reason.'**
  String get m4ReasonRequired;

  /// M4 reports/corrections: The reason may contain up to 500 characters.
  ///
  /// In en, this message translates to:
  /// **'The reason may contain up to 500 characters.'**
  String get m4ReasonTooLong;

  /// M4 reports/corrections: Confirm how the money is handled in the store first.
  ///
  /// In en, this message translates to:
  /// **'Confirm how the money is handled in the store first.'**
  String get m4ConfirmMoney;

  /// M4 reports/corrections: A full cancellation requires all goods to have actually been returned.
  ///
  /// In en, this message translates to:
  /// **'A full cancellation requires all goods to have actually been returned.'**
  String get m4ConfirmGoods;

  /// M4 reports/corrections: This record has already been cancelled. Reload to see the result.
  ///
  /// In en, this message translates to:
  /// **'This record has already been cancelled. Reload to see the result.'**
  String get m4AlreadyCancelled;

  /// M4 reports/corrections: A later repayment remains active. Review and reverse that payment first if it was recorded in error; do not delete it.
  ///
  /// In en, this message translates to:
  /// **'A later repayment remains active. Review and reverse that payment first if it was recorded in error; do not delete it.'**
  String get m4ActiveRepayment;

  /// M4 reports/corrections: This payment has no customer to own the reopened debt. Use a full sale cancellation if all goods have actually been returned.
  ///
  /// In en, this message translates to:
  /// **'This payment has no customer to own the reopened debt. Use a full sale cancellation if all goods have actually been returned.'**
  String get m4AnonymousPayment;

  /// M4 reports/corrections: The payment is unavailable or is itself a reversal.
  ///
  /// In en, this message translates to:
  /// **'The payment is unavailable or is itself a reversal.'**
  String get m4PaymentUnavailable;

  /// M4 reports/corrections: Related records disagree. Check reconciliation; no correction was saved.
  ///
  /// In en, this message translates to:
  /// **'Related records disagree. Check reconciliation; no correction was saved.'**
  String get m4InconsistentData;

  /// M4 reports/corrections: The data changed. Reload from the start.
  ///
  /// In en, this message translates to:
  /// **'The data changed. Reload from the start.'**
  String get m4DatasetChanged;

  /// M4 reports/corrections: The period start must precede its end.
  ///
  /// In en, this message translates to:
  /// **'The period start must precede its end.'**
  String get m4InvalidPeriod;

  /// M4 reports/corrections: The report total exceeds the database integer limit. Choose a smaller period or filter.
  ///
  /// In en, this message translates to:
  /// **'The report total exceeds the database integer limit. Choose a smaller period or filter.'**
  String get m4AggregateTooLarge;

  /// M4 reports/corrections: Printing, notifications, backup and restore are planned for the next stage.
  ///
  /// In en, this message translates to:
  /// **'Printing, notifications, backup and restore are planned for the next stage.'**
  String get m4LaterFeatures;

  /// M5 printer, alerts or backup interface: m5OperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation did not complete. Check permissions, connection, or enter your PIN again.'**
  String get m5OperationFailed;

  /// M5 printer, alerts or backup interface: m5PermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission not granted. In-app alerts remain available.'**
  String get m5PermissionDenied;

  /// M5 printer, alerts or backup interface: m5Printer.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth printer'**
  String get m5Printer;

  /// M5 printer, alerts or backup interface: m5PrinterHelp.
  ///
  /// In en, this message translates to:
  /// **'ESC/POS over Bluetooth Classic/SPP. Iware MP-581RL usually appears as RPP02N. Calibrate the profile on real paper. Enter your PIN again after an Android permission dialog if locked.'**
  String get m5PrinterHelp;

  /// M5 printer, alerts or backup interface: m5Paired.
  ///
  /// In en, this message translates to:
  /// **'Paired devices'**
  String get m5Paired;

  /// M5 printer, alerts or backup interface: m5Discover.
  ///
  /// In en, this message translates to:
  /// **'Discover devices'**
  String get m5Discover;

  /// M5 printer, alerts or backup interface: m5Pair.
  ///
  /// In en, this message translates to:
  /// **'Pair'**
  String get m5Pair;

  /// M5 printer, alerts or backup interface: m5PairRequested.
  ///
  /// In en, this message translates to:
  /// **'Pairing requested from Android; check its dialog, then reload paired devices.'**
  String get m5PairRequested;

  /// M5 printer, alerts or backup interface: m5SavedPrinters.
  ///
  /// In en, this message translates to:
  /// **'Saved printers'**
  String get m5SavedPrinters;

  /// M5 printer, alerts or backup interface: m5FirstPage.
  ///
  /// In en, this message translates to:
  /// **'Load first page'**
  String get m5FirstPage;

  /// M5 printer, alerts or backup interface: m5NextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get m5NextPage;

  /// M5 printer, alerts or backup interface: m5PrintableDots.
  ///
  /// In en, this message translates to:
  /// **'Printable width (dots)'**
  String get m5PrintableDots;

  /// M5 printer, alerts or backup interface: m5LeftDots.
  ///
  /// In en, this message translates to:
  /// **'Left margin (dots)'**
  String get m5LeftDots;

  /// M5 printer, alerts or backup interface: m5RightDots.
  ///
  /// In en, this message translates to:
  /// **'Right margin (dots)'**
  String get m5RightDots;

  /// M5 printer, alerts or backup interface: m5ShiftDots.
  ///
  /// In en, this message translates to:
  /// **'Horizontal shift (dots)'**
  String get m5ShiftDots;

  /// M5 printer, alerts or backup interface: m5Feed.
  ///
  /// In en, this message translates to:
  /// **'Blank space after receipt (0–8 lines)'**
  String get m5Feed;

  /// Manual extra blank lines before the receipt header, from zero to eight.
  ///
  /// In en, this message translates to:
  /// **'Blank space before header (0–8 lines)'**
  String get m5TopFeed;

  /// Explicit printer command language selection per saved profile.
  ///
  /// In en, this message translates to:
  /// **'Printer command language'**
  String get m5Protocol;

  /// ESC/POS GS v 0 raster encoder option.
  ///
  /// In en, this message translates to:
  /// **'ESC/POS Raster (common)'**
  String get m5ProtocolRaster;

  /// ESC/POS ESC asterisk column image encoder option.
  ///
  /// In en, this message translates to:
  /// **'ESC/POS Column (alternative)'**
  String get m5ProtocolColumn;

  /// TSPL bitmap continuous-media receipt encoder option.
  ///
  /// In en, this message translates to:
  /// **'TSPL (continuous paper)'**
  String get m5ProtocolTspl;

  /// CPCL graphics continuous-media receipt encoder option.
  ///
  /// In en, this message translates to:
  /// **'CPCL (continuous paper)'**
  String get m5ProtocolCpcl;

  /// User guidance for explicit protocol, continuous media and physical calibration.
  ///
  /// In en, this message translates to:
  /// **'Match the printer mode or manufacturer guide, then Save. Firmware mode is not changed automatically. TSPL/CPCL use continuous paper at 203 dpi; match page height to the printer capability. Test print to check the paper result.'**
  String get m5ProtocolHelp;

  /// Bounded page height for TSPL/CPCL receipts, independent of total receipt length.
  ///
  /// In en, this message translates to:
  /// **'Maximum page height (128–4096 dots)'**
  String get m5PageRows;

  /// Decrease leading blank lines for this printer profile.
  ///
  /// In en, this message translates to:
  /// **'Reduce blank space before header'**
  String get m5TopFeedDecrease;

  /// Increase leading blank lines for this printer profile.
  ///
  /// In en, this message translates to:
  /// **'Increase blank space before header'**
  String get m5TopFeedIncrease;

  /// Decrease the extra trailing blank lines for this printer profile.
  ///
  /// In en, this message translates to:
  /// **'Reduce blank space after receipt'**
  String get m5FeedDecrease;

  /// Increase the extra trailing blank lines for this printer profile.
  ///
  /// In en, this message translates to:
  /// **'Increase blank space after receipt'**
  String get m5FeedIncrease;

  /// M5 printer, alerts or backup interface: m5GeometryHelp.
  ///
  /// In en, this message translates to:
  /// **'203 DPI: 8 dots is about 1 mm. Paper width differs from printable width. Keep shifts within the safe area; the OpenLabel -4 mm setting is not a universal default. Edit header/footer in store settings.'**
  String get m5GeometryHelp;

  /// M5 printer, alerts or backup interface: m5Bold.
  ///
  /// In en, this message translates to:
  /// **'Bold text'**
  String get m5Bold;

  /// M5 printer, alerts or backup interface: m5Logo.
  ///
  /// In en, this message translates to:
  /// **'Print logo when available'**
  String get m5Logo;

  /// M5 printer, alerts or backup interface: m5HeaderAlign.
  ///
  /// In en, this message translates to:
  /// **'Header alignment'**
  String get m5HeaderAlign;

  /// M5 printer, alerts or backup interface: m5FooterAlign.
  ///
  /// In en, this message translates to:
  /// **'Footer alignment'**
  String get m5FooterAlign;

  /// M5 printer, alerts or backup interface: m5AlignLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get m5AlignLeft;

  /// M5 printer, alerts or backup interface: m5AlignCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get m5AlignCenter;

  /// M5 printer, alerts or backup interface: m5AlignRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get m5AlignRight;

  /// M5 printer, alerts or backup interface: m5ResetTemplate.
  ///
  /// In en, this message translates to:
  /// **'Reset profile template'**
  String get m5ResetTemplate;

  /// M5 printer, alerts or backup interface: m5Preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get m5Preview;

  /// M5 printer, alerts or backup interface: m5ProfileInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid template geometry or size. Check printable area and margins.'**
  String get m5ProfileInvalid;

  /// M5 printer, alerts or backup interface: m5PrinterSaved.
  ///
  /// In en, this message translates to:
  /// **'Printer profile saved.'**
  String get m5PrinterSaved;

  /// M5 printer, alerts or backup interface: m5TestPrint.
  ///
  /// In en, this message translates to:
  /// **'Print UJI COBA'**
  String get m5TestPrint;

  /// M5 printer, alerts or backup interface: m5ForgetPrinter.
  ///
  /// In en, this message translates to:
  /// **'Forget in this app'**
  String get m5ForgetPrinter;

  /// M5 printer, alerts or backup interface: m5PrinterForgotten.
  ///
  /// In en, this message translates to:
  /// **'Printer binding removed from this app.'**
  String get m5PrinterForgotten;

  /// M5 printer, alerts or backup interface: m5Disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get m5Disconnect;

  /// M5 printer, alerts or backup interface: m5Disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected.'**
  String get m5Disconnected;

  /// M5 printer, alerts or backup interface: m5PrintReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print receipt'**
  String get m5PrintReceipt;

  /// M5 printer, alerts or backup interface: m5PrintCopy.
  ///
  /// In en, this message translates to:
  /// **'Print SALINAN'**
  String get m5PrintCopy;

  /// M5 printer, alerts or backup interface: m5DataSent.
  ///
  /// In en, this message translates to:
  /// **'Data sent. Check the printed paper.'**
  String get m5DataSent;

  /// M5 printer, alerts or backup interface: m5DeliveryUnknown.
  ///
  /// In en, this message translates to:
  /// **'Delivery is uncertain. Check the printer first; print SALINAN only if needed.'**
  String get m5DeliveryUnknown;

  /// M5 printer, alerts or backup interface: m5NotSent.
  ///
  /// In en, this message translates to:
  /// **'Data was not sent. Check the printer and connection.'**
  String get m5NotSent;

  /// M5 printer, alerts or backup interface: m5PrintPrepared.
  ///
  /// In en, this message translates to:
  /// **'Print job prepared.'**
  String get m5PrintPrepared;

  /// M5 printer, alerts or backup interface: m5PrintSetupRequired.
  ///
  /// In en, this message translates to:
  /// **'Printer is not ready. Open Printer settings. The sale remains saved.'**
  String get m5PrintSetupRequired;

  /// M5 printer, alerts or backup interface: m5ScanCancelled.
  ///
  /// In en, this message translates to:
  /// **'Discovery cancelled.'**
  String get m5ScanCancelled;

  /// M5 printer, alerts or backup interface: m5ScanTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Discovery timed out; discovered devices are shown.'**
  String get m5ScanTimedOut;

  /// M5 printer, alerts or backup interface: m5ScanFinished.
  ///
  /// In en, this message translates to:
  /// **'Discovery finished.'**
  String get m5ScanFinished;

  /// M5 printer, alerts or backup interface: m5Alerts.
  ///
  /// In en, this message translates to:
  /// **'Inventory alerts'**
  String get m5Alerts;

  /// M5 printer, alerts or backup interface: m5AlertsHelp.
  ///
  /// In en, this message translates to:
  /// **'Stock alerts follow each product’s minimum. Expiry uses remaining batches and the shop calendar. Notifications are best effort; tap to open the protected list with your PIN.'**
  String get m5AlertsHelp;

  /// M5 printer, alerts or backup interface: m5ExpiryDays.
  ///
  /// In en, this message translates to:
  /// **'Days before expiry (0–365)'**
  String get m5ExpiryDays;

  /// M5 printer, alerts or backup interface: m5Notifications.
  ///
  /// In en, this message translates to:
  /// **'Enable inventory notifications'**
  String get m5Notifications;

  /// M5 printer, alerts or backup interface: m5SettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved.'**
  String get m5SettingsSaved;

  /// M5 printer, alerts or backup interface: m5NoAlerts.
  ///
  /// In en, this message translates to:
  /// **'No active alerts.'**
  String get m5NoAlerts;

  /// M5 printer, alerts or backup interface: m5Expiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get m5Expiry;

  /// M5 printer, alerts or backup interface: m5Saleable.
  ///
  /// In en, this message translates to:
  /// **'Saleable stock'**
  String get m5Saleable;

  /// M5 printer, alerts or backup interface: m5Minimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get m5Minimum;

  /// M5 printer, alerts or backup interface: m5Backup.
  ///
  /// In en, this message translates to:
  /// **'Backup & Google Drive'**
  String get m5Backup;

  /// M5 printer, alerts or backup interface: m5BackupHelp.
  ///
  /// In en, this message translates to:
  /// **'Backups contain shop data and logo in an encrypted archive. Export with the Android file picker to keep a copy outside the app. Restore replaces all active data. After an Android dialog, enter your PIN again to continue.'**
  String get m5BackupHelp;

  /// M5 printer, alerts or backup interface: m5RecoveryConfigured.
  ///
  /// In en, this message translates to:
  /// **'Backup recovery code is configured.'**
  String get m5RecoveryConfigured;

  /// M5 printer, alerts or backup interface: m5RecoveryRequired.
  ///
  /// In en, this message translates to:
  /// **'Set up and save a recovery code before creating a backup.'**
  String get m5RecoveryRequired;

  /// M5 printer, alerts or backup interface: m5GenerateCode.
  ///
  /// In en, this message translates to:
  /// **'Set up a new code'**
  String get m5GenerateCode;

  /// M5 printer, alerts or backup interface: m5ShowCode.
  ///
  /// In en, this message translates to:
  /// **'Show saved code'**
  String get m5ShowCode;

  /// Copy the explicitly displayed backup recovery code.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get m5CopyCode;

  /// Copy success without revealing secret text.
  ///
  /// In en, this message translates to:
  /// **'Recovery code copied without spaces or hyphens.'**
  String get m5CodeCopied;

  /// Sanitized clipboard failure without upstream details.
  ///
  /// In en, this message translates to:
  /// **'Code was not copied. Show the complete code and retry while the app is active.'**
  String get m5CodeCopyFailed;

  /// M5 printer, alerts or backup interface: m5RecoveryCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'This code differs from your PIN and PIN recovery. Keep a private copy outside the device. Older backups still need the code used when created; a lost code cannot be derived from your PIN.'**
  String get m5RecoveryCodeHelp;

  /// M5 printer, alerts or backup interface: m5ConfirmRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code you saved'**
  String get m5ConfirmRecoveryCode;

  /// M5 printer, alerts or backup interface: m5CodeStored.
  ///
  /// In en, this message translates to:
  /// **'I have saved a copy of this code where I can retrieve it.'**
  String get m5CodeStored;

  /// M5 printer, alerts or backup interface: m5SaveRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Confirm and save code'**
  String get m5SaveRecoveryCode;

  /// M5 printer, alerts or backup interface: m5LocalBackups.
  ///
  /// In en, this message translates to:
  /// **'Encrypted local backups'**
  String get m5LocalBackups;

  /// M5 printer, alerts or backup interface: m5CreateBackup.
  ///
  /// In en, this message translates to:
  /// **'Create local backup'**
  String get m5CreateBackup;

  /// M5 printer, alerts or backup interface: m5Export.
  ///
  /// In en, this message translates to:
  /// **'Export file'**
  String get m5Export;

  /// M5 printer, alerts or backup interface: m5SelectRestore.
  ///
  /// In en, this message translates to:
  /// **'Select for restore'**
  String get m5SelectRestore;

  /// M5 printer, alerts or backup interface: m5Restore.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get m5Restore;

  /// M5 printer, alerts or backup interface: m5ChooseArchive.
  ///
  /// In en, this message translates to:
  /// **'Choose archive from files'**
  String get m5ChooseArchive;

  /// M5 printer, alerts or backup interface: m5ArchiveSelected.
  ///
  /// In en, this message translates to:
  /// **'Archive selected. Enter your PIN again if prompted, then validate with that archive’s recovery code.'**
  String get m5ArchiveSelected;

  /// M5 printer, alerts or backup interface: m5RecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Backup recovery code'**
  String get m5RecoveryCode;

  /// M5 printer, alerts or backup interface: m5ValidateArchive.
  ///
  /// In en, this message translates to:
  /// **'Validate archive'**
  String get m5ValidateArchive;

  /// M5 printer, alerts or backup interface: m5RestoreWarning.
  ///
  /// In en, this message translates to:
  /// **'All active data, including local drafts, will be replaced by the backup. An encrypted safety backup must succeed first. After restore, use the selected backup’s PIN. Reconfigure Google, automatic backups, notifications, and printer bindings; nothing prints automatically.'**
  String get m5RestoreWarning;

  /// M5 printer, alerts or backup interface: m5ReplaceAndDrafts.
  ///
  /// In en, this message translates to:
  /// **'I agree to replace all active data and local drafts with the selected backup.'**
  String get m5ReplaceAndDrafts;

  /// M5 printer, alerts or backup interface: m5RestoreFinalConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Proceed with full restore now?'**
  String get m5RestoreFinalConfirmation;

  /// M5 printer, alerts or backup interface: m5Confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get m5Confirm;

  /// M5 printer, alerts or backup interface: m5GoogleDrive.
  ///
  /// In en, this message translates to:
  /// **'Optional Google Drive'**
  String get m5GoogleDrive;

  /// M5 printer, alerts or backup interface: m5DriveHelp.
  ///
  /// In en, this message translates to:
  /// **'Uses only the app data folder in the selected account. This does not synchronize stock. Manual upload sends an encrypted archive; automation requires separate consent. Seven successful backups are retained per shop and installation origin. OAuth Testing may require authorization again after about seven days.'**
  String get m5DriveHelp;

  /// M5 printer, alerts or backup interface: m5TargetAccount.
  ///
  /// In en, this message translates to:
  /// **'Target account'**
  String get m5TargetAccount;

  /// M5 printer, alerts or backup interface: m5ChooseAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose or switch Google account'**
  String get m5ChooseAccount;

  /// M5 printer, alerts or backup interface: m5PendingAccount.
  ///
  /// In en, this message translates to:
  /// **'Account choice not yet saved'**
  String get m5PendingAccount;

  /// M5 printer, alerts or backup interface: m5UseAccount.
  ///
  /// In en, this message translates to:
  /// **'Use this account'**
  String get m5UseAccount;

  /// M5 printer, alerts or backup interface: m5AutomaticBackup.
  ///
  /// In en, this message translates to:
  /// **'Automatic Drive backup'**
  String get m5AutomaticBackup;

  /// M5 printer, alerts or backup interface: m5AutomaticBackupHelp.
  ///
  /// In en, this message translates to:
  /// **'Targets 21:00 in the shop timezone, best effort. Network, Doze, and device restrictions can delay it; execution after force-stop is not guaranteed.'**
  String get m5AutomaticBackupHelp;

  /// M5 printer, alerts or backup interface: m5AutomaticConsent.
  ///
  /// In en, this message translates to:
  /// **'Allow automatic upload of encrypted shop archives to the displayed target account?'**
  String get m5AutomaticConsent;

  /// M5 printer, alerts or backup interface: m5UploadNow.
  ///
  /// In en, this message translates to:
  /// **'Back up to Drive now'**
  String get m5UploadNow;

  /// M5 printer, alerts or backup interface: m5DriveVersions.
  ///
  /// In en, this message translates to:
  /// **'Drive backup versions'**
  String get m5DriveVersions;

  /// M5 printer, alerts or backup interface: m5Refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get m5Refresh;

  /// M5 printer, alerts or backup interface: m5CodeSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup recovery code saved.'**
  String get m5CodeSaved;

  /// M5 printer, alerts or backup interface: m5LocalBackupReady.
  ///
  /// In en, this message translates to:
  /// **'Validated local backup is ready. Export it to keep a copy outside the app.'**
  String get m5LocalBackupReady;

  /// M5 printer, alerts or backup interface: m5ExportVerified.
  ///
  /// In en, this message translates to:
  /// **'Export file was written and read back successfully.'**
  String get m5ExportVerified;

  /// M5 printer, alerts or backup interface: m5Cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled.'**
  String get m5Cancelled;

  /// M5 printer, alerts or backup interface: m5ArchiveValidated.
  ///
  /// In en, this message translates to:
  /// **'Archive authenticated and data validated. Review metadata before restore.'**
  String get m5ArchiveValidated;

  /// M5 printer, alerts or backup interface: m5RestoreComplete.
  ///
  /// In en, this message translates to:
  /// **'Restore completed. Use the backup’s PIN to open Management.'**
  String get m5RestoreComplete;

  /// M5 printer, alerts or backup interface: m5RestoreOutcomeCheck.
  ///
  /// In en, this message translates to:
  /// **'Restore could not be confirmed complete. Active storage was reopened; check its status and shop contents before continuing.'**
  String get m5RestoreOutcomeCheck;

  /// M5 printer, alerts or backup interface: m5AccountPending.
  ///
  /// In en, this message translates to:
  /// **'Account choice is ready. Enter your PIN again, then confirm the target account.'**
  String get m5AccountPending;

  /// M5 printer, alerts or backup interface: m5AccountConnected.
  ///
  /// In en, this message translates to:
  /// **'Target account saved. Automatic backup remains off.'**
  String get m5AccountConnected;

  /// M5 printer, alerts or backup interface: m5DriveBackupReady.
  ///
  /// In en, this message translates to:
  /// **'Drive archive upload verified.'**
  String get m5DriveBackupReady;

  /// M5 printer, alerts or backup interface: m5DriveNeedsAuth.
  ///
  /// In en, this message translates to:
  /// **'Google needs authorization again. Choose the account on this screen; workers do not open login dialogs.'**
  String get m5DriveNeedsAuth;

  /// M5 printer, alerts or backup interface: m5DriveConsentChanged.
  ///
  /// In en, this message translates to:
  /// **'Operation stopped because the account or consent changed.'**
  String get m5DriveConsentChanged;

  /// M5 printer, alerts or backup interface: m5DriveAccountMismatch.
  ///
  /// In en, this message translates to:
  /// **'Account identity does not match. Choose and confirm the target account again.'**
  String get m5DriveAccountMismatch;

  /// M5 printer, alerts or backup interface: m5DriveQuota.
  ///
  /// In en, this message translates to:
  /// **'Google Drive storage quota is insufficient.'**
  String get m5DriveQuota;

  /// M5 printer, alerts or backup interface: m5DriveOffline.
  ///
  /// In en, this message translates to:
  /// **'Network unavailable or timed out. Try again.'**
  String get m5DriveOffline;

  /// M5 printer, alerts or backup interface: m5DriveFailed.
  ///
  /// In en, this message translates to:
  /// **'Drive operation is incomplete. Check network, authorization, and account configuration.'**
  String get m5DriveFailed;

  /// A structured Google API-disabled response, without upstream identifiers or messages.
  ///
  /// In en, this message translates to:
  /// **'Google Drive API is not enabled or has been disabled in the app\'s Google Cloud project. Enable it in the project that owns the OAuth clients, then retry.'**
  String get m5DriveApiNotEnabled;

  /// Unclassified Drive access rejection; do not imply its exact cause is known.
  ///
  /// In en, this message translates to:
  /// **'Google Drive denied access. Check the app\'s Drive data permission and Google Cloud project configuration. Being listed as a test user alone does not guarantee API access.'**
  String get m5DriveForbidden;

  /// M5 printer, alerts or backup interface: m5ArchiveRejected.
  ///
  /// In en, this message translates to:
  /// **'Code or archive is invalid, damaged, or unreadable. Active data was not replaced.'**
  String get m5ArchiveRejected;

  /// M5 printer, alerts or backup interface: m5CodeRotationWarning.
  ///
  /// In en, this message translates to:
  /// **'A new code applies to future backups. Keep the old code for existing backups. Continue?'**
  String get m5CodeRotationWarning;

  /// M5 printer, alerts or backup interface: m5DatabaseKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'Installation database key is missing. Files are retained; no empty database was created. Use a verified backup on another installation or investigate key recovery.'**
  String get m5DatabaseKeyMissing;

  /// M5 printer, alerts or backup interface: m5DatabaseKeyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Keystore could not unlock the database key. Existing files are retained.'**
  String get m5DatabaseKeyUnavailable;

  /// M5 printer, alerts or backup interface: m5DatabaseUnlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Database could not be opened with the installation key. Files are retained; check backups and storage status.'**
  String get m5DatabaseUnlockFailed;

  /// M5 printer, alerts or backup interface: m5EncryptedExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Encrypted export failed. Source data is retained.'**
  String get m5EncryptedExportFailed;

  /// M5 printer, alerts or backup interface: m5DatabaseInUse.
  ///
  /// In en, this message translates to:
  /// **'Database is still in use. Wait for other operations to finish, then retry.'**
  String get m5DatabaseInUse;

  /// M5 printer, alerts or backup interface: m5PrintSending.
  ///
  /// In en, this message translates to:
  /// **'Sending print data'**
  String get m5PrintSending;

  /// M5 printer, alerts or backup interface: m5BackupRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get m5BackupRunning;

  /// M5 printer, alerts or backup interface: m5BackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get m5BackupFailed;

  /// M5 printer, alerts or backup interface: m5BackupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Succeeded'**
  String get m5BackupSuccess;

  /// M5 printer, alerts or backup interface: m5ChooseLogo.
  ///
  /// In en, this message translates to:
  /// **'Choose shop logo'**
  String get m5ChooseLogo;

  /// M5 printer, alerts or backup interface: m5ApplyLogo.
  ///
  /// In en, this message translates to:
  /// **'Apply selected logo'**
  String get m5ApplyLogo;

  /// M5 printer, alerts or backup interface: m5RemoveLogo.
  ///
  /// In en, this message translates to:
  /// **'Remove shop logo'**
  String get m5RemoveLogo;

  /// M5 printer, alerts or backup interface: m5ReceiptPreview.
  ///
  /// In en, this message translates to:
  /// **'Receipt preview'**
  String get m5ReceiptPreview;

  /// M5 printer, alerts or backup interface: m5HideCode.
  ///
  /// In en, this message translates to:
  /// **'Hide recovery code'**
  String get m5HideCode;

  /// Historical automatic backup failure on this device, potentially for a prior account.
  ///
  /// In en, this message translates to:
  /// **'Last automatic attempt failure on this device'**
  String get m5LastAutomaticFailure;

  /// Avoid attributing persisted device attempt status to the currently selected account.
  ///
  /// In en, this message translates to:
  /// **'This is a device record and may refer to a previous destination account.'**
  String get m5AutomaticFailureHistoryHelp;

  /// M5 printer, alerts or backup interface: m5LastAttempt.
  ///
  /// In en, this message translates to:
  /// **'Last backup attempt'**
  String get m5LastAttempt;

  /// M5 printer, alerts or backup interface: m5LastSuccess.
  ///
  /// In en, this message translates to:
  /// **'Last successful backup'**
  String get m5LastSuccess;

  /// M5 printer, alerts or backup interface: m5NextTarget.
  ///
  /// In en, this message translates to:
  /// **'Next backup target (shop time)'**
  String get m5NextTarget;

  /// M5 printer, alerts or backup interface: m5NotScheduled.
  ///
  /// In en, this message translates to:
  /// **'Not scheduled'**
  String get m5NotScheduled;

  /// M5 printer, alerts or backup interface: m5RunRunning.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get m5RunRunning;

  /// M5 printer, alerts or backup interface: m5RunCompleted.
  ///
  /// In en, this message translates to:
  /// **'Verified complete'**
  String get m5RunCompleted;

  /// M5 printer, alerts or backup interface: m5RunFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed; not a successful backup'**
  String get m5RunFailed;

  /// M5 printer, alerts or backup interface: m5RunUnknown.
  ///
  /// In en, this message translates to:
  /// **'Status needs review'**
  String get m5RunUnknown;

  /// M5 printer, alerts or backup interface: m5RestoreContents.
  ///
  /// In en, this message translates to:
  /// **'Archive contents and shop identity'**
  String get m5RestoreContents;

  /// M5 printer, alerts or backup interface: m5RestoreCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current shop'**
  String get m5RestoreCurrent;

  /// M5 printer, alerts or backup interface: m5LogoSize.
  ///
  /// In en, this message translates to:
  /// **'Logo size within printable area'**
  String get m5LogoSize;

  /// M5 printer, alerts or backup interface: m5LineGap.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get m5LineGap;

  /// M5 printer, alerts or backup interface: m5DatabaseNewerSchema.
  ///
  /// In en, this message translates to:
  /// **'This database requires a newer app version. Use a compatible version; data was not replaced.'**
  String get m5DatabaseNewerSchema;

  /// M5 printer, alerts or backup interface: m5CopyWarning.
  ///
  /// In en, this message translates to:
  /// **'Check any paper already printed. Sent data does not confirm printing, and reprinting can produce duplicates. Continue as SALINAN (copy)?'**
  String get m5CopyWarning;

  /// M5 printer, alerts or backup interface: m5OpenSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get m5OpenSourceLicenses;

  /// M5 printer, alerts or backup interface: m5Connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get m5Connect;

  /// M5 printer, alerts or backup interface: m5Connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting printer…'**
  String get m5Connecting;

  /// M5 printer, alerts or backup interface: m5Connected.
  ///
  /// In en, this message translates to:
  /// **'Connected to printer'**
  String get m5Connected;

  /// M5 printer, alerts or backup interface: m5ConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Printer connection failed. Check the printer and try again.'**
  String get m5ConnectionFailed;

  /// M5 printer, alerts or backup interface: m5ConnectionNotChecked.
  ///
  /// In en, this message translates to:
  /// **'Printer connection has not been checked'**
  String get m5ConnectionNotChecked;

  /// M5 printer, alerts or backup interface: m5CheckConnection.
  ///
  /// In en, this message translates to:
  /// **'Check connection'**
  String get m5CheckConnection;

  /// M5 printer, alerts or backup interface: m5BluetoothUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is unavailable on this device'**
  String get m5BluetoothUnavailable;

  /// M5 printer, alerts or backup interface: m5BluetoothDisabled.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is off. Enable it in device settings.'**
  String get m5BluetoothDisabled;

  /// M5 printer, alerts or backup interface: m5BluetoothPermissionHelp.
  ///
  /// In en, this message translates to:
  /// **'Nearby devices permission (location on older Android) is needed when using the printer. If the permission dialog no longer appears, check app permissions in Android Settings.'**
  String get m5BluetoothPermissionHelp;

  /// M5 printer, alerts or backup interface: driveRetryLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup stopped after three failed attempts. Check the connection and try a manual backup. The next daily schedule remains active.'**
  String get driveRetryLimitReached;

  /// Printer permission denial with explicit Android settings recovery; no automatic permission dialog retry.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth permission is not granted. Allow Nearby devices (Location on older Android) in this app’s Android settings, then try again.'**
  String get m5PrinterPermissionDenied;

  /// Backup export filename dialog; input remains in app above IME before Android destination picker.
  ///
  /// In en, this message translates to:
  /// **'Export file name'**
  String get m5ExportNameTitle;

  /// Backup export filename dialog; input remains in app above IME before Android destination picker.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get m5ExportNameLabel;

  /// Backup export filename dialog; input remains in app above IME before Android destination picker.
  ///
  /// In en, this message translates to:
  /// **'The .kasirbackup extension is added automatically. Choose a location next.'**
  String get m5ExportNameHelp;

  /// Backup export filename dialog; input remains in app above IME before Android destination picker.
  ///
  /// In en, this message translates to:
  /// **'Invalid name. Avoid path separators and special characters; maximum 128 characters including the extension.'**
  String get m5ExportNameInvalid;

  /// Backup export filename dialog; input remains in app above IME before Android destination picker.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get m5ExportChooseLocation;

  /// Backup destination archive listing or device-local cross-account upload history: m5DriveArchiveList.
  ///
  /// In en, this message translates to:
  /// **'Destination account Drive archives'**
  String get m5DriveArchiveList;

  /// Backup destination archive listing or device-local cross-account upload history: m5DriveArchiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'No Drive archives on this page.'**
  String get m5DriveArchiveEmpty;

  /// Backup destination archive listing or device-local cross-account upload history: m5RunHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup history on this device'**
  String get m5RunHistoryTitle;

  /// Backup destination archive listing or device-local cross-account upload history: m5RunHistoryHelp.
  ///
  /// In en, this message translates to:
  /// **'Drive upload records for all accounts on this device. Retention may remove older archives; history is retained.'**
  String get m5RunHistoryHelp;

  /// Backup destination archive listing or device-local cross-account upload history: m5RunCurrentAccount.
  ///
  /// In en, this message translates to:
  /// **'Current destination account'**
  String get m5RunCurrentAccount;

  /// Backup destination archive listing or device-local cross-account upload history: m5RunOtherAccount.
  ///
  /// In en, this message translates to:
  /// **'Another or previous destination account'**
  String get m5RunOtherAccount;

  /// Backup destination archive listing or device-local cross-account upload history: m5RunUnknownAccount.
  ///
  /// In en, this message translates to:
  /// **'Destination account not recorded'**
  String get m5RunUnknownAccount;

  /// M5.1 management, printer or inventory interface. English meaning: Optional product attributes
  ///
  /// In en, this message translates to:
  /// **'Optional product attributes'**
  String get m51Attributes;

  /// M5.1 management, printer or inventory interface. English meaning: Weight / volume
  ///
  /// In en, this message translates to:
  /// **'Weight / volume'**
  String get m51Size;

  /// M5.1 management, printer or inventory interface. English meaning: Up to 3 decimals, no grouping. Example: 0.5
  ///
  /// In en, this message translates to:
  /// **'Up to 3 decimals, no grouping. Example: 0.5'**
  String get m51SizeHelp;

  /// M5.1 management, printer or inventory interface. English meaning: Size unit
  ///
  /// In en, this message translates to:
  /// **'Size unit'**
  String get m51Unit;

  /// M5.1 management, printer or inventory interface. English meaning: No unit
  ///
  /// In en, this message translates to:
  /// **'No unit'**
  String get m51NoUnit;

  /// M5.1 management, printer or inventory interface. English meaning: liter
  ///
  /// In en, this message translates to:
  /// **'liter'**
  String get m51Liter;

  /// Indonesian metadata unit, not an ounce or fractional stock unit.
  ///
  /// In en, this message translates to:
  /// **'ons (100 g)'**
  String get m53Ons;

  /// Reminder while canonical price equals last purchase suggestion.
  ///
  /// In en, this message translates to:
  /// **'This price comes from the last purchase. Check and change it if the current price differs.'**
  String get m53LastPurchaseReminder;

  /// Reference cost is not presented as a purchase.
  ///
  /// In en, this message translates to:
  /// **'Reference cost, not the last purchase price. Check the current price.'**
  String get m53ReceiptReferenceHint;

  /// Unknown price remains blank.
  ///
  /// In en, this message translates to:
  /// **'The last purchase price is unknown. Enter the current price.'**
  String get m53ReceiptUnknownHint;

  /// Do not round unit price conversion.
  ///
  /// In en, this message translates to:
  /// **'The previous price cannot be entered exactly in this unit. Enter the current price or change the unit.'**
  String get m53ReceiptInexactHint;

  /// Historical pack size label.
  ///
  /// In en, this message translates to:
  /// **'Pack size on the previous purchase'**
  String get m53ReceiptOriginalPack;

  /// Received quantity field error.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole received quantity greater than 0.'**
  String get m53ReceiptQuantityInvalid;

  /// Pack size field error.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole pack size greater than 0.'**
  String get m53ReceiptPackInvalid;

  /// Empty purchase price field error.
  ///
  /// In en, this message translates to:
  /// **'Enter the purchase price for the selected unit.'**
  String get m53ReceiptCostRequired;

  /// Invalid purchase price field error.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid purchase price for the selected unit.'**
  String get m53ReceiptCostInvalid;

  /// Warehouse cursor must be refreshed.
  ///
  /// In en, this message translates to:
  /// **'Warehouse data or date changed. Reload the list.'**
  String get m53WarehouseChanged;

  /// Warehouse stock status filter label.
  ///
  /// In en, this message translates to:
  /// **'Stock condition'**
  String get m53WarehouseStockFilter;

  /// All stock states.
  ///
  /// In en, this message translates to:
  /// **'All conditions'**
  String get m53WarehouseAll;

  /// Expired stock or reference date.
  ///
  /// In en, this message translates to:
  /// **'Expired stock / reference date'**
  String get m53WarehouseExpired;

  /// Only tracked products with zero physical stock.
  ///
  /// In en, this message translates to:
  /// **'Tracked stock is empty'**
  String get m53WarehouseEmpty;

  /// Warehouse relation filters.
  ///
  /// In en, this message translates to:
  /// **'Filter category, shelf and master supplier'**
  String get m53WarehouseRelations;

  /// Untracked expiry without fictitious count.
  ///
  /// In en, this message translates to:
  /// **'Expired reference date; physical quantity is not tracked'**
  String get m53WarehouseReferenceExpired;

  /// Distinguish master and transaction suppliers.
  ///
  /// In en, this message translates to:
  /// **'The optional master supplier groups products. Each receipt records its own transaction supplier.'**
  String get m53MasterSupplierHelp;

  /// Gesture help with accessible alternative.
  ///
  /// In en, this message translates to:
  /// **'Long-press to rename a category; an edit button is also available.'**
  String get m53CategoryLongPress;

  /// M5.1 management, printer or inventory interface. English meaning: Shelf location
  ///
  /// In en, this message translates to:
  /// **'Shelf location'**
  String get m51Shelf;

  /// M5.1 management, printer or inventory interface. English meaning: Product note
  ///
  /// In en, this message translates to:
  /// **'Product note'**
  String get m51Note;

  /// M5.1 management, printer or inventory interface. English meaning: Size is descriptive; stock stays in pcs. Shelf: 80 characters; note: 1,000. Clear both value and unit to remove size.
  ///
  /// In en, this message translates to:
  /// **'Size is descriptive; stock stays in pcs. Shelf: 80 characters; note: 1,000. Clear both value and unit to remove size.'**
  String get m51AttributesHelp;

  /// M5.1 management, printer or inventory interface. English meaning: Enter a positive size with its unit (up to 3 decimals, no grouping). Check shelf 80 and note 1,000 character limits.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive size with its unit (up to 3 decimals, no grouping). Check shelf 80 and note 1,000 character limits.'**
  String get m51AttributesInvalid;

  /// M5.1 management, printer or inventory interface. English meaning: Management security
  ///
  /// In en, this message translates to:
  /// **'Management security'**
  String get m51Security;

  /// M5.1 management, printer or inventory interface. English meaning: Fresh authentication required
  ///
  /// In en, this message translates to:
  /// **'Fresh authentication required'**
  String get m51FreshAuthentication;

  /// M5.1 management, printer or inventory interface. English meaning: Authenticate again to approve this sensitive action.
  ///
  /// In en, this message translates to:
  /// **'Authenticate again to approve this sensitive action.'**
  String get m51FreshAuthenticationRequired;

  /// M5.1 management, printer or inventory interface. English meaning: Complete or cancel the current system dialog.
  ///
  /// In en, this message translates to:
  /// **'Complete or cancel the current system dialog.'**
  String get m51SystemOperationPending;

  /// M5.1 management, printer or inventory interface. English meaning: Use app PIN
  ///
  /// In en, this message translates to:
  /// **'Use app PIN'**
  String get m51UseAppPin;

  /// M5.1 management, printer or inventory interface. English meaning: Use strong biometrics
  ///
  /// In en, this message translates to:
  /// **'Use strong biometrics'**
  String get m51UseBiometric;

  /// M5.1 management, printer or inventory interface. English meaning: Class 3 biometrics are unavailable or not enrolled. Use the app PIN.
  ///
  /// In en, this message translates to:
  /// **'Class 3 biometrics are unavailable or not enrolled. Use the app PIN.'**
  String get m51BiometricUnavailable;

  /// M5.1 management, printer or inventory interface. English meaning: Biometric authentication cancelled. You can use the app PIN.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication cancelled. You can use the app PIN.'**
  String get m51BiometricCancelled;

  /// M5.1 management, printer or inventory interface. English meaning: Android has locked biometric authentication. Use the app PIN or try later.
  ///
  /// In en, this message translates to:
  /// **'Android has locked biometric authentication. Use the app PIN or try later.'**
  String get m51BiometricLockout;

  /// M5.1 management, printer or inventory interface. English meaning: Biometric binding changed. Use the app PIN and enable it again if desired.
  ///
  /// In en, this message translates to:
  /// **'Biometric binding changed. Use the app PIN and enable it again if desired.'**
  String get m51BiometricInvalidated;

  /// M5.1 management, printer or inventory interface. English meaning: Optional, Class 3 only. Every enrolled device biometric can authenticate; the app cannot identify individual owners or staff. App PIN remains available. Re-enable with PIN after enrollment changes or restore.
  ///
  /// In en, this message translates to:
  /// **'Optional, Class 3 only. Every enrolled device biometric can authenticate; the app cannot identify individual owners or staff. App PIN remains available. Re-enable with PIN after enrollment changes or restore.'**
  String get m51BiometricHelp;

  /// M5.1 management, printer or inventory interface. English meaning: Management session policy
  ///
  /// In en, this message translates to:
  /// **'Management session policy'**
  String get m51SessionPolicy;

  /// M5.1 management, printer or inventory interface. English meaning: Effective policy
  ///
  /// In en, this message translates to:
  /// **'Effective policy'**
  String get m51CurrentPolicy;

  /// M5.1 management, printer or inventory interface. English meaning: Legacy default retained: lock on minimize, 5-minute idle limit.
  ///
  /// In en, this message translates to:
  /// **'Legacy default retained: lock on minimize, 5-minute idle limit.'**
  String get m51LegacyPolicy;

  /// M5.1 management, printer or inventory interface. English meaning: Lock immediately on minimize
  ///
  /// In en, this message translates to:
  /// **'Lock immediately on minimize'**
  String get m51SessionImmediate;

  /// M5.1 management, printer or inventory interface. English meaning: 1 minute idle
  ///
  /// In en, this message translates to:
  /// **'1 minute idle'**
  String get m51Session1;

  /// M5.1 management, printer or inventory interface. English meaning: 5 minutes idle
  ///
  /// In en, this message translates to:
  /// **'5 minutes idle'**
  String get m51Session5;

  /// M5.1 management, printer or inventory interface. English meaning: 15 minutes idle
  ///
  /// In en, this message translates to:
  /// **'15 minutes idle'**
  String get m51Session15;

  /// M5.1 management, printer or inventory interface. English meaning: Timed choices include background inactivity; returning does not extend the session. Immediate lock also has a 5-minute idle limit. App dialogs are bounded to 60 seconds; full file/account pickers may require PIN once on return. Screen lock, restart, manual lock, PIN changes and restore invalidate access. Cashier stays open. Grace is a convenience choice retaining temporary access.
  ///
  /// In en, this message translates to:
  /// **'Timed choices include background inactivity; returning does not extend the session. Immediate lock also has a 5-minute idle limit. App dialogs are bounded to 60 seconds; full file/account pickers may require PIN once on return. Screen lock, restart, manual lock, PIN changes and restore invalidate access. Cashier stays open. Grace is a convenience choice retaining temporary access.'**
  String get m51SessionHelp;

  /// M5.1 management, printer or inventory interface. English meaning: Print recovery code
  ///
  /// In en, this message translates to:
  /// **'Print recovery code'**
  String get m51PrintRecovery;

  /// M5.1 management, printer or inventory interface. English meaning: The paper contains a secret that unlocks backups. Check that you own this destination, collect the paper and store it separately from archives/the device. Printer transport and memory are not guaranteed confidential. There is no automatic retry.
  ///
  /// In en, this message translates to:
  /// **'The paper contains a secret that unlocks backups. Check that you own this destination, collect the paper and store it separately from archives/the device. Printer transport and memory are not guaranteed confidential. There is no automatic retry.'**
  String get m51RecoveryPrintWarning;

  /// M5.1 management, printer or inventory interface. English meaning: Prints the saved code. For a new or rotated code, confirm and save it first; printing is optional.
  ///
  /// In en, this message translates to:
  /// **'Prints the saved code. For a new or rotated code, confirm and save it first; printing is optional.'**
  String get m51RecoveryPrintStoredOnly;

  /// M5.1 management, printer or inventory interface. English meaning: Select and save a printer profile in printer settings first.
  ///
  /// In en, this message translates to:
  /// **'Select and save a printer profile in printer settings first.'**
  String get m51RecoveryPrinterRequired;

  /// M5.1 management, printer or inventory interface. English meaning: The printer profile changed. Check and confirm the destination again.
  ///
  /// In en, this message translates to:
  /// **'The printer profile changed. Check and confirm the destination again.'**
  String get m51RecoveryPrinterChanged;

  /// M5.1 management, printer or inventory interface. English meaning: Print data submitted. Check the paper and all 64 characters; submitted bytes do not prove complete paper output.
  ///
  /// In en, this message translates to:
  /// **'Print data submitted. Check the paper and all 64 characters; submitted bytes do not prove complete paper output.'**
  String get m51RecoveryPrintSubmitted;

  /// M5.1 management, printer or inventory interface. English meaning: The code was not sent. Check the printer/connection. Reprinting requires new authentication and confirmation.
  ///
  /// In en, this message translates to:
  /// **'The code was not sent. Check the printer/connection. Reprinting requires new authentication and confirmation.'**
  String get m51RecoveryPrintNotSent;

  /// M5.1 management, printer or inventory interface. English meaning: Print outcome is uncertain; part of the code may be on paper. No automatic retry. Secure the paper, check the printer, then authenticate again if choosing to reprint.
  ///
  /// In en, this message translates to:
  /// **'Print outcome is uncertain; part of the code may be on paper. No automatic retry. Secure the paper, check the printer, then authenticate again if choosing to reprint.'**
  String get m51RecoveryPrintUnknown;

  /// M5.1 management, printer or inventory interface. English meaning: I checked the entire code on paper and stored my copy privately.
  ///
  /// In en, this message translates to:
  /// **'I checked the entire code on paper and stored my copy privately.'**
  String get m51RecoveryPaperStored;

  /// M5.1 management, printer or inventory interface. English meaning: Record copy storage confirmation
  ///
  /// In en, this message translates to:
  /// **'Record copy storage confirmation'**
  String get m51ConfirmPaperStored;

  /// M5.1 management, printer or inventory interface. English meaning: Copy storage confirmation recorded without retaining its contents.
  ///
  /// In en, this message translates to:
  /// **'Copy storage confirmation recorded without retaining its contents.'**
  String get m51RecoveryCopyStored;

  /// M5.1 management, printer or inventory interface. English meaning: Bluetooth / USB printer
  ///
  /// In en, this message translates to:
  /// **'Bluetooth / USB printer'**
  String get m51PrinterTitle;

  /// M5.1 management, printer or inventory interface. English meaning: USB OTG needs USB Host, a data cable, power and an ESC/POS USB printer-class device. Select a device before granting access. Vendor USB serial is not supported. Avoid unplugging during output; failed delivery never retries automatically.
  ///
  /// In en, this message translates to:
  /// **'USB OTG needs USB Host, a data cable, power and an ESC/POS USB printer-class device. Select a device before granting access. Vendor USB serial is not supported. Avoid unplugging during output; failed delivery never retries automatically.'**
  String get m51UsbHelp;

  /// M5.1 management, printer or inventory interface. English meaning: Load USB devices
  ///
  /// In en, this message translates to:
  /// **'Load USB devices'**
  String get m51UsbLoad;

  /// M5.1 management, printer or inventory interface. English meaning: No supported class 7/1 USB printer detected. Check OTG, data cable and power.
  ///
  /// In en, this message translates to:
  /// **'No supported class 7/1 USB printer detected. Check OTG, data cable and power.'**
  String get m51UsbEmpty;

  /// M5.1 management, printer or inventory interface. English meaning: Select a USB printer, then Connect to request access to that device only.
  ///
  /// In en, this message translates to:
  /// **'Select a USB printer, then Connect to request access to that device only.'**
  String get m51UsbSelect;

  /// M5.1 management, printer or inventory interface. English meaning: Temporary identity: a printer without a unique serial must be reselected after detach or app restart. An old profile never automatically connects to a similar printer.
  ///
  /// In en, this message translates to:
  /// **'Temporary identity: a printer without a unique serial must be reselected after detach or app restart. An old profile never automatically connects to a similar printer.'**
  String get m51UsbTemporary;

  /// M5.1 management, printer or inventory interface. English meaning: USB Host unavailable. Cashier and Bluetooth remain usable.
  ///
  /// In en, this message translates to:
  /// **'USB Host unavailable. Cashier and Bluetooth remain usable.'**
  String get m51UsbUnavailable;

  /// M5.1 management, printer or inventory interface. English meaning: USB permission was denied or interrupted. Re-enter the app PIN if locked. Use Retry USB permission only to request it explicitly.
  ///
  /// In en, this message translates to:
  /// **'USB permission was denied or interrupted. Re-enter the app PIN if locked. Use Retry USB permission only to request it explicitly.'**
  String get m51UsbPermissionDenied;

  /// M5.1 management, printer or inventory interface. English meaning: Retry USB permission
  ///
  /// In en, this message translates to:
  /// **'Retry USB permission'**
  String get m51UsbRetryPermission;

  /// M5.1 management, printer or inventory interface. English meaning: USB printer detached, changed identity or is ambiguous. Reload and reselect; no automatic reprint.
  ///
  /// In en, this message translates to:
  /// **'USB printer detached, changed identity or is ambiguous. Reload and reselect; no automatic reprint.'**
  String get m51UsbSelectAgain;

  /// M5.1 management, printer or inventory interface. English meaning: USB interface is busy or cannot be claimed without displacing a driver. Close other app connections, then retry explicitly.
  ///
  /// In en, this message translates to:
  /// **'USB interface is busy or cannot be claimed without displacing a driver. Close other app connections, then retry explicitly.'**
  String get m51UsbBusy;

  /// M5.1 management, printer or inventory interface. English meaning: USB operation failed. Check power, OTG, data cable, permission and printer compatibility. No automatic reprint.
  ///
  /// In en, this message translates to:
  /// **'USB operation failed. Check power, OTG, data cable, permission and printer compatibility. No automatic reprint.'**
  String get m51UsbFailed;

  /// M5.1 management, printer or inventory interface. English meaning: Cash received
  ///
  /// In en, this message translates to:
  /// **'Cash received'**
  String get m51Tender;

  /// M5.1 management, printer or inventory interface. English meaning: Payment applied
  ///
  /// In en, this message translates to:
  /// **'Payment applied'**
  String get m51Applied;

  /// M5.1 management, printer or inventory interface. English meaning: Change
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get m51Change;

  /// M5.1 management, printer or inventory interface. English meaning: Numpad
  ///
  /// In en, this message translates to:
  /// **'Numpad'**
  String get m51Numpad;

  /// M5.1 management, printer or inventory interface. English meaning: Quick cash
  ///
  /// In en, this message translates to:
  /// **'Quick cash'**
  String get m51QuickCash;

  /// M5.1 management, printer or inventory interface. English meaning: Exact amount
  ///
  /// In en, this message translates to:
  /// **'Exact amount'**
  String get m51ExactCash;

  /// M5.1 management, printer or inventory interface. English meaning: Enter cash received, choose Exact amount, or explicitly choose All debt.
  ///
  /// In en, this message translates to:
  /// **'Enter cash received, choose Exact amount, or explicitly choose All debt.'**
  String get m51TenderRequired;

  /// M5.1 management, printer or inventory interface. English meaning: Backspace
  ///
  /// In en, this message translates to:
  /// **'Backspace'**
  String get m51Backspace;

  /// M5.1 management, printer or inventory interface. English meaning: Clear amount
  ///
  /// In en, this message translates to:
  /// **'Clear amount'**
  String get m51ClearTender;

  /// M5.1 management, printer or inventory interface. English meaning: Confirm amount
  ///
  /// In en, this message translates to:
  /// **'Confirm amount'**
  String get m51ConfirmTender;

  /// M5.1 management, printer or inventory interface. English meaning: Quick cash amounts
  ///
  /// In en, this message translates to:
  /// **'Quick cash amounts'**
  String get m51QuickSettings;

  /// M5.1 management, printer or inventory interface. English meaning: Reset defaults
  ///
  /// In en, this message translates to:
  /// **'Reset defaults'**
  String get m51ResetQuick;

  /// M5.1 management, printer or inventory interface. English meaning: Export report
  ///
  /// In en, this message translates to:
  /// **'Export report'**
  String get m51Export;

  /// M5.1 management, printer or inventory interface. English meaning: Export the full selected period and customer filter. Inventory and receivables are current snapshots, not historical positions. Files contain store data. UTF-8 CSV: import barcodes, IDs and amounts as text to preserve precision; formula-like text is prefixed with an apostrophe. Not an official tax form.
  ///
  /// In en, this message translates to:
  /// **'Export the full selected period and customer filter. Inventory and receivables are current snapshots, not historical positions. Files contain store data. UTF-8 CSV: import barcodes, IDs and amounts as text to preserve precision; formula-like text is prefixed with an apostrophe. Not an official tax form.'**
  String get m51ExportPolicy;

  /// M5.1 management, printer or inventory interface. English meaning: Rows prepared
  ///
  /// In en, this message translates to:
  /// **'Rows prepared'**
  String get m51ExportRows;

  /// M5.1 management, printer or inventory interface. English meaning: Prepare and choose destination
  ///
  /// In en, this message translates to:
  /// **'Prepare and choose destination'**
  String get m51ExportCreate;

  /// M5.1 management, printer or inventory interface. English meaning: Destination selected. Re-enter PIN if requested, then press Write file. Destination expires in two minutes.
  ///
  /// In en, this message translates to:
  /// **'Destination selected. Re-enter PIN if requested, then press Write file. Destination expires in two minutes.'**
  String get m51ExportSelected;

  /// M5.1 management, printer or inventory interface. English meaning: Write file
  ///
  /// In en, this message translates to:
  /// **'Write file'**
  String get m51ExportWrite;

  /// M5.1 management, printer or inventory interface. English meaning: Report written and verified by reading it back.
  ///
  /// In en, this message translates to:
  /// **'Report written and verified by reading it back.'**
  String get m51ExportVerified;

  /// M5.1 management, printer or inventory interface. English meaning: Export did not complete. Check PIN session, storage and destination. Select again if the destination expired.
  ///
  /// In en, this message translates to:
  /// **'Export did not complete. Check PIN session, storage and destination. Select again if the destination expired.'**
  String get m51ExportFailed;

  /// M5.1 management, printer or inventory interface. English meaning: Space maintenance is scheduled after a valid backup, while idle and charging. It skips low benefit, busy operations or insufficient storage. History is never deleted.
  ///
  /// In en, this message translates to:
  /// **'Space maintenance is scheduled after a valid backup, while idle and charging. It skips low benefit, busy operations or insufficient storage. History is never deleted.'**
  String get m51MaintenancePolicy;

  /// M5.1 management, printer or inventory interface. English meaning: Space maintenance
  ///
  /// In en, this message translates to:
  /// **'Space maintenance'**
  String get m51MaintenanceStatus;

  /// M5.1 management, printer or inventory interface. English meaning: Last attempt
  ///
  /// In en, this message translates to:
  /// **'Last attempt'**
  String get m51MaintenanceAttempt;

  /// M5.1 management, printer or inventory interface. English meaning: Last success
  ///
  /// In en, this message translates to:
  /// **'Last success'**
  String get m51MaintenanceSuccess;

  /// Database space-maintenance status or outcome. English meaning: Database is in use; maintenance was skipped.
  ///
  /// In en, this message translates to:
  /// **'Database is in use; maintenance was skipped.'**
  String get m51Space_databaseBusy;

  /// Database space-maintenance status or outcome. English meaning: Not scheduled
  ///
  /// In en, this message translates to:
  /// **'Not scheduled'**
  String get m51Space_none;

  /// Database space-maintenance status or outcome. English meaning: Waiting for idle conditions
  ///
  /// In en, this message translates to:
  /// **'Waiting for idle conditions'**
  String get m51Space_pending;

  /// Database space-maintenance status or outcome. English meaning: Running
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get m51Space_running;

  /// Database space-maintenance status or outcome. English meaning: Successful
  ///
  /// In en, this message translates to:
  /// **'Successful'**
  String get m51Space_success;

  /// Database space-maintenance status or outcome. English meaning: Skipped
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get m51Space_skipped;

  /// Database space-maintenance status or outcome. English meaning: Did not complete
  ///
  /// In en, this message translates to:
  /// **'Did not complete'**
  String get m51Space_error;

  /// Database space-maintenance status or outcome. English meaning: Maintenance cooldown is active.
  ///
  /// In en, this message translates to:
  /// **'Maintenance cooldown is active.'**
  String get m51Space_cooldown;

  /// Database space-maintenance status or outcome. English meaning: Previous process was interrupted; waiting for the next valid backup.
  ///
  /// In en, this message translates to:
  /// **'Previous process was interrupted; waiting for the next valid backup.'**
  String get m51Space_interrupted;

  /// Database space-maintenance status or outcome. English meaning: Reclaimable space is below the threshold.
  ///
  /// In en, this message translates to:
  /// **'Reclaimable space is below the threshold.'**
  String get m51Space_lowBenefit;

  /// Database space-maintenance status or outcome. English meaning: Insufficient temporary space.
  ///
  /// In en, this message translates to:
  /// **'Insufficient temporary space.'**
  String get m51Space_insufficientSpace;

  /// Database space-maintenance status or outcome. English meaning: Device is in use or not charging.
  ///
  /// In en, this message translates to:
  /// **'Device is in use or not charging.'**
  String get m51Space_deviceInUse;

  /// Database space-maintenance status or outcome. English meaning: Database compacted and integrity verified.
  ///
  /// In en, this message translates to:
  /// **'Database compacted and integrity verified.'**
  String get m51Space_compacted;

  /// Database space-maintenance status or outcome. English meaning: Maintenance failed. The previous valid backup remains available.
  ///
  /// In en, this message translates to:
  /// **'Maintenance failed. The previous valid backup remains available.'**
  String get m51Space_maintenanceFailed;

  /// M5.2 operational form or validation. English meaning: Pay full balance
  ///
  /// In en, this message translates to:
  /// **'Pay full balance'**
  String get m52PayAll;

  /// M5.2 operational form or validation. English meaning: Invalid phone number for this country. Use digits and an optional leading +.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number for this country. Use digits and an optional leading +.'**
  String get m52PhoneInvalid;

  /// M5.2 operational form or validation. English meaning: Invalid email format.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format.'**
  String get m52EmailInvalid;

  /// M5.2 operational form or validation. English meaning: Enter a domain or http/https URL with a valid host.
  ///
  /// In en, this message translates to:
  /// **'Enter a domain or http/https URL with a valid host.'**
  String get m52WebsiteInvalid;

  /// M5.2 operational form or validation. English meaning: Initial quantity must be 0–999999 base units, at most six digits.
  ///
  /// In en, this message translates to:
  /// **'Initial quantity must be 0–999999 base units, at most six digits.'**
  String get m52InitialQuantityLimit;

  /// M5.2 operational form or validation. English meaning: Purchase cost per unit must not exceed the retail selling price.
  ///
  /// In en, this message translates to:
  /// **'Purchase cost per unit must not exceed the retail selling price.'**
  String get m52PurchaseAboveRetail;

  /// M5.2 operational form or validation. English meaning: Wholesale price must not exceed the retail selling price.
  ///
  /// In en, this message translates to:
  /// **'Wholesale price must not exceed the retail selling price.'**
  String get m52WholesaleAboveRetail;

  /// M5.2 operational form or validation. English meaning: Enter the reference purchase cost per unit, including an explicit zero if free.
  ///
  /// In en, this message translates to:
  /// **'Enter the reference purchase cost per unit, including an explicit zero if free.'**
  String get m52ReferenceCostRequired;

  /// M5.2 operational form or validation. English meaning: This shelf name/code already exists.
  ///
  /// In en, this message translates to:
  /// **'This shelf name/code already exists.'**
  String get m52ShelfDuplicate;

  /// M5.2 operational form or validation. English meaning: Unsaved changes
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get m52UnsavedTitle;

  /// M5.2 operational form or validation. English meaning: There are unsaved changes. Going back now will discard changes to this form. Continue?
  ///
  /// In en, this message translates to:
  /// **'There are unsaved changes. Going back now will discard changes to this form. Continue?'**
  String get m52UnsavedBody;

  /// M5.2 operational form or validation. English meaning: Continue editing
  ///
  /// In en, this message translates to:
  /// **'Continue editing'**
  String get m52KeepEditing;

  /// M5.2 operational form or validation. English meaning: Go back without saving
  ///
  /// In en, this message translates to:
  /// **'Go back without saving'**
  String get m52Discard;

  /// M5.2 operational form or validation. English meaning: Select a product and name, a positive minimum quantity and a discount of 0.01–100%.
  ///
  /// In en, this message translates to:
  /// **'Select a product and name, a positive minimum quantity and a discount of 0.01–100%.'**
  String get m52PromoInvalid;

  /// M5.2 operational form or validation. English meaning: This product already has an active promotion. Disable the old promotion first.
  ///
  /// In en, this message translates to:
  /// **'This product already has an active promotion. Disable the old promotion first.'**
  String get m52PromoConflict;

  /// M5.2 operational form or validation. English meaning: 999 — Fictitious stock (not tracked)
  ///
  /// In en, this message translates to:
  /// **'999 — Fictitious stock (not tracked)'**
  String get m52Untracked;

  /// M5.2 operational form or validation. English meaning: Initial quantity is empty. The system will store fictitious stock 999 because this product is not tracked. This is not a real quantity and is excluded from inventory value.
  ///
  /// In en, this message translates to:
  /// **'Initial quantity is empty. The system will store fictitious stock 999 because this product is not tracked. This is not a real quantity and is excluded from inventory value.'**
  String get m52UntrackedNote;

  /// M5.2 operational form or validation. English meaning: Physical inventory operations require stock tracking.
  ///
  /// In en, this message translates to:
  /// **'Physical inventory operations require stock tracking.'**
  String get m52StockOperationRequiresTracking;

  /// M5.2 operational form or validation. English meaning: Reconcile physical stock and batches before changing tracking mode.
  ///
  /// In en, this message translates to:
  /// **'Reconcile physical stock and batches before changing tracking mode.'**
  String get m52StockTransition;

  /// M5.2 operational form or validation. English meaning: Reference purchase cost per unit (not tracked)
  ///
  /// In en, this message translates to:
  /// **'Reference purchase cost per unit (not tracked)'**
  String get m52ReferenceCost;

  /// M5.2 operational form or validation. English meaning: Stock tracked
  ///
  /// In en, this message translates to:
  /// **'Stock tracked'**
  String get m52Tracked;

  /// M5.2 operational form or validation. English meaning: Cost basis
  ///
  /// In en, this message translates to:
  /// **'Cost basis'**
  String get m52CostSource;

  /// M5.2 operational form or validation. English meaning: Retail quantity promotion
  ///
  /// In en, this message translates to:
  /// **'Retail quantity promotion'**
  String get m52Promo;

  /// M5.2 operational form or validation. English meaning: Promotion name
  ///
  /// In en, this message translates to:
  /// **'Promotion name'**
  String get m52PromoName;

  /// M5.2 operational form or validation. English meaning: Minimum base-unit quantity
  ///
  /// In en, this message translates to:
  /// **'Minimum base-unit quantity'**
  String get m52PromoMinimum;

  /// M5.2 operational form or validation. English meaning: Discount (%)
  ///
  /// In en, this message translates to:
  /// **'Discount (%)'**
  String get m52PromoPercent;

  /// M5.2 operational form or validation. English meaning: Active
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get m52PromoActive;

  /// M5.2 operational form or validation. English meaning: Archive this promotion?
  ///
  /// In en, this message translates to:
  /// **'Archive this promotion?'**
  String get m52PromoArchive;

  /// M5.2 operational form or validation. English meaning: Gross amount
  ///
  /// In en, this message translates to:
  /// **'Gross amount'**
  String get m52Gross;

  /// M5.2 operational form or validation. English meaning: Discount
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get m52Discount;

  /// M5.2 operational form or validation. English meaning: The promoted price is below cost. Review the margin before enabling it.
  ///
  /// In en, this message translates to:
  /// **'The promoted price is below cost. Review the margin before enabling it.'**
  String get m52PromoLoss;

  /// M5.2 operational form or validation. English meaning: Shelf (optional)
  ///
  /// In en, this message translates to:
  /// **'Shelf (optional)'**
  String get m52Shelf;

  /// M5.2 operational form or validation. English meaning: Add / edit shelves
  ///
  /// In en, this message translates to:
  /// **'Add / edit shelves'**
  String get m52Shelves;

  /// M5.2 operational form or validation. English meaning: Shelf code/name
  ///
  /// In en, this message translates to:
  /// **'Shelf code/name'**
  String get m52ShelfName;

  /// M5.2 operational form or validation. English meaning: Email (optional)
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get m52Email;

  /// M5.2 operational form or validation. English meaning: Website (optional)
  ///
  /// In en, this message translates to:
  /// **'Website (optional)'**
  String get m52Website;

  /// M5.2 operational form or validation. English meaning: Local phone region (ISO code, e.g. ID)
  ///
  /// In en, this message translates to:
  /// **'Local phone region (ISO code, e.g. ID)'**
  String get m52PhoneRegion;

  /// M5.2 operational form or validation. English meaning: A new date must be tomorrow or later in the device calendar.
  ///
  /// In en, this message translates to:
  /// **'A new date must be tomorrow or later in the device calendar.'**
  String get m52DateTomorrow;

  /// M5.2 operational form or validation. English meaning: Review low price
  ///
  /// In en, this message translates to:
  /// **'Review low price'**
  String get m52LowPriceTitle;

  /// M5.2 operational form or validation. English meaning: This price is low for this currency. Review the amount. Save anyway?
  ///
  /// In en, this message translates to:
  /// **'This price is low for this currency. Review the amount. Save anyway?'**
  String get m52LowPriceBody;

  /// M5.2 operational form or validation. English meaning: Review again
  ///
  /// In en, this message translates to:
  /// **'Review again'**
  String get m52Review;

  /// M5.2 operational form or validation. English meaning: Save anyway
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get m52SaveAnyway;

  /// M5.2 operational form or validation. English meaning: Do not show the low-price warning again for this currency in this shop
  ///
  /// In en, this message translates to:
  /// **'Do not show the low-price warning again for this currency in this shop'**
  String get m52SuppressLowPrice;

  /// M5.2 operational form or validation. English meaning: Low-price warning preferences
  ///
  /// In en, this message translates to:
  /// **'Low-price warning preferences'**
  String get m52LowPriceSettings;

  /// M5.2 operational form or validation. English meaning: Low-price threshold
  ///
  /// In en, this message translates to:
  /// **'Low-price threshold'**
  String get m52Threshold;

  /// M5.2 operational form or validation. English meaning: Paper width
  ///
  /// In en, this message translates to:
  /// **'Paper width'**
  String get m52PaperWidth;

  /// M5.2 operational form or validation. English meaning: Try Iware 58: 3 feed lines (this profile only)
  ///
  /// In en, this message translates to:
  /// **'Try Iware 58: 3 feed lines (this profile only)'**
  String get m52IwareFeed;

  /// M5.2 operational form or validation. English meaning: Adjust feed after the footer. Inspect paper before saving calibration; old profiles retain their values.
  ///
  /// In en, this message translates to:
  /// **'Enter the number of lines or use −/+. 0 adds no extra blank space. Press Save for this printer. Line length varies by printer; the printhead-to-tear distance remains.'**
  String get m52FeedHelp;

  /// M5.2 operational form or validation. English meaning: 21:00 backup is a best-effort target. Battery/background restrictions can delay it. On HyperOS, No restrictions (if available) may help without guaranteeing timing. Scheduling cannot be relied on after force-stop.
  ///
  /// In en, this message translates to:
  /// **'21:00 backup is a best-effort target. Battery/background restrictions can delay it. On HyperOS, No restrictions (if available) may help without guaranteeing timing. Scheduling cannot be relied on after force-stop.'**
  String get m52BatteryHelp;

  /// M5.2 operational form or validation. English meaning: Open App info / battery settings
  ///
  /// In en, this message translates to:
  /// **'Open App info / battery settings'**
  String get m52AppSettings;

  /// M5.2 operational form or validation. English meaning: Products without stock tracking
  ///
  /// In en, this message translates to:
  /// **'Products without stock tracking'**
  String get m52UntrackedCount;

  /// M5.2 operational form or validation. English meaning: Change stock tracking mode
  ///
  /// In en, this message translates to:
  /// **'Change stock tracking mode'**
  String get m52TrackingChange;

  /// M5.2 operational form or validation. English meaning: Enable tracking with an actual opening quantity (enter 0 if empty) and purchase cost per unit. Past sales retain their original mode and cost.
  ///
  /// In en, this message translates to:
  /// **'Enable tracking with an actual opening quantity (enter 0 if empty) and purchase cost per unit. Past sales retain their original mode and cost.'**
  String get m52TrackedOpening;

  /// M5.2 operational form or validation. English meaning: Cannot open this destination. Check the number/address and the device's WhatsApp/browser app.
  ///
  /// In en, this message translates to:
  /// **'Cannot open this destination. Check the number/address and the device\'s WhatsApp/browser app.'**
  String get m52ContactOpenFailed;

  /// Action to add a row or item.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Action to remove an editable quick-cash amount.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Validation error when saving a negative per-currency low-price threshold.
  ///
  /// In en, this message translates to:
  /// **'The low-price threshold must not be negative.'**
  String get m52LowPriceThreshold;

  /// M5.3 store policy and PIN verification: m53Features
  ///
  /// In en, this message translates to:
  /// **'Features and stock tracking'**
  String get m53Features;

  /// M5.3 store policy and PIN verification: m53StockMode
  ///
  /// In en, this message translates to:
  /// **'Store stock tracking'**
  String get m53StockMode;

  /// M5.3 store policy and PIN verification: m53Stockoff
  ///
  /// In en, this message translates to:
  /// **'Do not track stock'**
  String get m53Stockoff;

  /// M5.3 store policy and PIN verification: m53Stockpartial
  ///
  /// In en, this message translates to:
  /// **'Track selected products'**
  String get m53Stockpartial;

  /// M5.3 store policy and PIN verification: m53Stockall
  ///
  /// In en, this message translates to:
  /// **'Track all products'**
  String get m53Stockall;

  /// M5.3 store policy and PIN verification: m53TrackThisProduct
  ///
  /// In en, this message translates to:
  /// **'Track stock for this product'**
  String get m53TrackThisProduct;

  /// M5.3 store policy and PIN verification: m53StockHelp
  ///
  /// In en, this message translates to:
  /// **'Untracked stock does not show the quantity in the store and does not decrease after a sale. Check availability. For tracked stock, record receipts, sales, returns and corrections to match physical stock. Record or reconcile sales made outside the app. Reconcile conflicting products before changing the store mode.'**
  String get m53StockHelp;

  /// M5.3 store policy and PIN verification: m53PolicyPreview
  ///
  /// In en, this message translates to:
  /// **'Review changes'**
  String get m53PolicyPreview;

  /// M5.3 store policy and PIN verification: m53PolicyImpact
  ///
  /// In en, this message translates to:
  /// **'Products requiring reconciliation before changing mode'**
  String get m53PolicyImpact;

  /// M5.3 store policy and PIN verification: m53PreserveFeatures
  ///
  /// In en, this message translates to:
  /// **'Hiding a feature preserves stored wholesale prices, packaging, barcodes, dates and history. Sale eligibility rules still apply.'**
  String get m53PreserveFeatures;

  /// M5.3 store policy and PIN verification: m53WholesaleHelp
  ///
  /// In en, this message translates to:
  /// **'Configure wholesale prices per product. Enabling this feature does not assign wholesale prices automatically.'**
  String get m53WholesaleHelp;

  /// M5.3 store policy and PIN verification: m53BarcodeHelp
  ///
  /// In en, this message translates to:
  /// **'Use barcodes with a supported camera or external scanner. Products without barcodes can use automatic internal codes.'**
  String get m53BarcodeHelp;

  /// M5.3 store policy and PIN verification: m53ExpiryHelp
  ///
  /// In en, this message translates to:
  /// **'Dates and batches help with reminders and sale eligibility. Check physical condition. Hiding these inputs does not erase dates or make expired stock saleable.'**
  String get m53ExpiryHelp;

  /// M5.3 store policy and PIN verification: m53PolicyChanged
  ///
  /// In en, this message translates to:
  /// **'Settings changed. Reopen to review the latest data.'**
  String get m53PolicyChanged;

  /// M5.3 store policy and PIN verification: m53StockReconciliationRequired
  ///
  /// In en, this message translates to:
  /// **'Some products conflict with this stock mode. Reconcile them using product tracking changes, then review again. No balances were changed.'**
  String get m53StockReconciliationRequired;

  /// M5.3 store policy and PIN verification: m53StockModeConflict
  ///
  /// In en, this message translates to:
  /// **'Product tracking conflicts with the store policy. Reload settings and choose a compatible mode.'**
  String get m53StockModeConflict;

  /// M5.3 store policy and PIN verification: m53InitialQuantityRequired
  ///
  /// In en, this message translates to:
  /// **'Enter an explicit initial quantity, including 0 if there is no stock.'**
  String get m53InitialQuantityRequired;

  /// M5.3 store policy and PIN verification: m53PinRequired72Hours
  ///
  /// In en, this message translates to:
  /// **'Use the app PIN to unlock management. A PIN is required again after 72 hours; biometrics do not restart this interval.'**
  String get m53PinRequired72Hours;

  /// M5.3 store policy and PIN verification: m53RoleSetupRequired
  ///
  /// In en, this message translates to:
  /// **'Changing task assignments requires the corresponding PIN and access setup.'**
  String get m53RoleSetupRequired;

  /// M5.3 store policy and PIN verification: m53UnknownCostPending
  ///
  /// In en, this message translates to:
  /// **'This setting requires explicit unknown-cost accounting. Existing costs are preserved.'**
  String get m53UnknownCostPending;

  /// M5.3 separated local access: m53OwnerRequired
  ///
  /// In en, this message translates to:
  /// **'Owner/Reports access is required for this action.'**
  String get m53OwnerRequired;

  /// M5.3 separated local access: m53WarehouseNotConfigured
  ///
  /// In en, this message translates to:
  /// **'Warehouse access has not been configured for this task pattern.'**
  String get m53WarehouseNotConfigured;

  /// M5.3 separated local access: m53PinsMustDiffer
  ///
  /// In en, this message translates to:
  /// **'Warehouse and Owner/Reports PINs must differ.'**
  String get m53PinsMustDiffer;

  /// M5.3 separated local access: m53ChooseAccess
  ///
  /// In en, this message translates to:
  /// **'Choose the access to unlock'**
  String get m53ChooseAccess;

  /// M5.3 separated local access: m53OwnerRole
  ///
  /// In en, this message translates to:
  /// **'Owner/Reports'**
  String get m53OwnerRole;

  /// M5.3 separated local access: m53WarehouseRole
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get m53WarehouseRole;

  /// M5.3 separated local access: m53TaskPattern
  ///
  /// In en, this message translates to:
  /// **'How is your store managed?'**
  String get m53TaskPattern;

  /// M5.3 separated local access: m53TaskHelp
  ///
  /// In en, this message translates to:
  /// **'These are task and access patterns on the same app/device, not employee limits or personal accounts. Changes revoke existing management sessions.'**
  String get m53TaskHelp;

  /// M5.3 separated local access: m53Pattern1
  ///
  /// In en, this message translates to:
  /// **'1 — Owner handles checkout and management'**
  String get m53Pattern1;

  /// M5.3 separated local access: m53Pattern2
  ///
  /// In en, this message translates to:
  /// **'2 — Cashier and manager'**
  String get m53Pattern2;

  /// M5.3 separated local access: m53Pattern3
  ///
  /// In en, this message translates to:
  /// **'3 or more — Separate responsibilities'**
  String get m53Pattern3;

  /// M5.3 separated local access: m53WarehousePinHelp
  ///
  /// In en, this message translates to:
  /// **'All products must be tracked. Reconcile untracked products before selecting this pattern. The Warehouse PIN must differ from the Owner/Reports PIN. Biometrics are for Owner/Reports only; device biometrics do not prove an employee role. The owner can reset the Warehouse PIN on this page.'**
  String get m53WarehousePinHelp;

  /// M5.3 separated local access: m53WarehousePin
  ///
  /// In en, this message translates to:
  /// **'Create Warehouse PIN'**
  String get m53WarehousePin;

  /// M5.3 explicit stock valuation: m53ZeroCostConfirmation
  ///
  /// In en, this message translates to:
  /// **'Confirm that this purchase is intentionally free before recording zero cost.'**
  String get m53ZeroCostConfirmation;

  /// M5.3 explicit stock valuation: m53ValuationQuantityMismatch
  ///
  /// In en, this message translates to:
  /// **'Cost reconciliation quantity must match the confirmed stock quantity.'**
  String get m53ValuationQuantityMismatch;

  /// User clarification M5.3 locked dirty exit: m53LockedUnsavedBody
  ///
  /// In en, this message translates to:
  /// **'There are unsaved management changes. Stay on the locked screen, or discard the changes and return to the cashier. Authenticate with the appropriate access to resume editing.'**
  String get m53LockedUnsavedBody;

  /// User clarification M5.3 locked dirty exit: m53StayLocked
  ///
  /// In en, this message translates to:
  /// **'Stay on locked screen'**
  String get m53StayLocked;

  /// User clarification M5.3 locked dirty exit: m53DiscardToCashier
  ///
  /// In en, this message translates to:
  /// **'Discard and return to cashier'**
  String get m53DiscardToCashier;

  /// M5.3 explicit cost knowledge and reconciliation
  ///
  /// In en, this message translates to:
  /// **'Incomplete — cost unknown'**
  String get m53CostIncomplete;

  /// M5.3 explicit cost knowledge and reconciliation
  ///
  /// In en, this message translates to:
  /// **'Sale/reversal documents with incomplete cost'**
  String get m53IncompleteSaleEvents;

  /// M5.3 explicit cost knowledge and reconciliation
  ///
  /// In en, this message translates to:
  /// **'Stock products with incomplete value'**
  String get m53IncompleteInventoryProducts;

  /// M5.3 explicit cost knowledge and reconciliation
  ///
  /// In en, this message translates to:
  /// **'Cost supports cost of sales, inventory value and estimated profit. Revenue is still recorded without cost; cost/profit is marked incomplete. Empty cost differs from zero cost.'**
  String get m53CostHelp;

  /// M5.3 explicit cost knowledge and reconciliation
  ///
  /// In en, this message translates to:
  /// **'Free acquisition?'**
  String get m53ConfirmFreeTitle;

  /// M5.3 explicit cost knowledge and reconciliation
  ///
  /// In en, this message translates to:
  /// **'I intentionally record zero cost. These goods were acquired free of charge; their cost is not unknown.'**
  String get m53ConfirmFreeBody;

  /// M5.3 explicit cost knowledge and reconciliation
  ///
  /// In en, this message translates to:
  /// **'Reconcile entire stock value'**
  String get m53ReconcileValuation;

  /// M5.3 explicit cost knowledge and reconciliation
  ///
  /// In en, this message translates to:
  /// **'Enter the total cost of the entire current physical balance and its supporting reason. Previous sale cost snapshots stay unchanged.'**
  String get m53ReconcileValuationHelp;

  /// M5.3 explicit cost knowledge and reconciliation
  ///
  /// In en, this message translates to:
  /// **'Total cost of entire stock'**
  String get m53PoolTotalCost;

  /// M5.3 append-only whole-pool reconciliation history including zero-valued events
  ///
  /// In en, this message translates to:
  /// **'Stock valuation history'**
  String get m53ValuationHistory;

  /// M5.3 explicit stock tracking scope transition, preserving physical history
  ///
  /// In en, this message translates to:
  /// **'Review the balance and confirm ending tracking with a reason.'**
  String get m53TrackingClosureRequired;

  /// M5.3 explicit stock tracking scope transition, preserving physical history
  ///
  /// In en, this message translates to:
  /// **'Tracking ended; the last balance was archived, not lost goods'**
  String get m53TrackingClosed;

  /// M5.3 explicit stock tracking scope transition, preserving physical history
  ///
  /// In en, this message translates to:
  /// **'Stock tracking change'**
  String get m53TrackingChangeRecorded;

  /// M5.3 explicit stock tracking scope transition, preserving physical history
  ///
  /// In en, this message translates to:
  /// **'Tracking history'**
  String get m53TrackingHistory;

  /// M5.3 explicit stock tracking scope transition, preserving physical history
  ///
  /// In en, this message translates to:
  /// **'The physical goods remain. The last balance and batches are archived, then excluded from tracked stock/value. This is not a stocktake loss or cost of sales. Reopening tracking requires a new physical count.'**
  String get m53TrackingClosureHelp;

  /// M5.3 explicit stock tracking scope transition, preserving physical history
  ///
  /// In en, this message translates to:
  /// **'Use the last average cost as the per-unit reference'**
  String get m53HistoricalAverageReference;

  /// M5.3 explicit stock tracking scope transition, preserving physical history
  ///
  /// In en, this message translates to:
  /// **'I understand these goods are not treated as lost and confirm ending tracking for this balance'**
  String get m53ConfirmTrackingClosure;

  /// M5.3 explicit stock tracking scope transition, preserving physical history
  ///
  /// In en, this message translates to:
  /// **'The earliest date of closed batches is retained. Changing tracking does not make expired goods saleable.'**
  String get m53TrackingExpiryPreserved;

  /// M5.3 explicit stock tracking scope transition, preserving physical history
  ///
  /// In en, this message translates to:
  /// **'Start reconciliation using partial tracking'**
  String get m53StartPartialTransition;

  /// M5.3 explicit stock tracking scope transition, preserving physical history
  ///
  /// In en, this message translates to:
  /// **'The store will use partial tracking so each product can be reviewed. Change product tracking and enter physical counts as needed, then select the target mode here again. Balances are not changed in bulk.'**
  String get m53PartialTransitionHelp;

  /// M5.3 tracking transition evidence reason length validation
  ///
  /// In en, this message translates to:
  /// **'The reason must not exceed 1000 characters.'**
  String get m53CorrectionReasonLimit;

  /// Dynamic reconciliation result label shown in reports
  ///
  /// In en, this message translates to:
  /// **'Sale cost snapshot completeness'**
  String get m53CostKnowledgeCheck;

  /// Dynamic reconciliation result label shown in reports
  ///
  /// In en, this message translates to:
  /// **'Empty stock valuation'**
  String get m53EmptyCostCheck;

  /// M5.3 resumable new-store setup: m53SetupTitle
  ///
  /// In en, this message translates to:
  /// **'Store setup'**
  String get m53SetupTitle;

  /// M5.3 resumable new-store setup: m53SetupIdentity
  ///
  /// In en, this message translates to:
  /// **'Store identity'**
  String get m53SetupIdentity;

  /// M5.3 resumable new-store setup: m53SetupSecurity
  ///
  /// In en, this message translates to:
  /// **'Management security'**
  String get m53SetupSecurity;

  /// M5.3 resumable new-store setup: m53SetupFeatures
  ///
  /// In en, this message translates to:
  /// **'Visible features'**
  String get m53SetupFeatures;

  /// M5.3 resumable new-store setup: m53SetupPrinter
  ///
  /// In en, this message translates to:
  /// **'Set up a receipt printer now?'**
  String get m53SetupPrinter;

  /// M5.3 resumable new-store setup: m53SetupReview
  ///
  /// In en, this message translates to:
  /// **'Review setup'**
  String get m53SetupReview;

  /// M5.3 resumable new-store setup: m53SetupStep
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get m53SetupStep;

  /// M5.3 resumable new-store setup: m53SetupNext
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get m53SetupNext;

  /// M5.3 resumable new-store setup: m53SetupBack
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get m53SetupBack;

  /// M5.3 resumable new-store setup: m53SetupFinish
  ///
  /// In en, this message translates to:
  /// **'Finish and open Cashier'**
  String get m53SetupFinish;

  /// M5.3 resumable new-store setup: m53SetupAddress
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get m53SetupAddress;

  /// M5.3 resumable new-store setup: m53SetupContact
  ///
  /// In en, this message translates to:
  /// **'WhatsApp/phone (optional)'**
  String get m53SetupContact;

  /// M5.3 resumable new-store setup: m53SetupSelfManaged
  ///
  /// In en, this message translates to:
  /// **'I manage the store myself'**
  String get m53SetupSelfManaged;

  /// M5.3 resumable new-store setup: m53SetupTaskHelp
  ///
  /// In en, this message translates to:
  /// **'These are access patterns on the same app/device, not personal employee accounts. Pattern 1: the owner handles checkout and management. Pattern 2: cashier and inventory/reports manager. Pattern 3 or more: Cashier, Warehouse and Owner/Reports are separate.'**
  String get m53SetupTaskHelp;

  /// M5.3 resumable new-store setup: m53SetupPinHelp
  ///
  /// In en, this message translates to:
  /// **'The PIN protects management; Cashier stays open unless the optional cashier lock is enabled. Owner/manager biometrics can be enabled later in Security. Biometrics do not identify Warehouse staff.'**
  String get m53SetupPinHelp;

  /// M5.3 resumable new-store setup: m53SetupOwnerPin
  ///
  /// In en, this message translates to:
  /// **'Create Owner/Management PIN'**
  String get m53SetupOwnerPin;

  /// M5.3 resumable new-store setup: m53SetupOwnerConfirm
  ///
  /// In en, this message translates to:
  /// **'Confirm Owner/Management PIN'**
  String get m53SetupOwnerConfirm;

  /// M5.3 resumable new-store setup: m53SetupWarehouseConfirm
  ///
  /// In en, this message translates to:
  /// **'Confirm Warehouse PIN'**
  String get m53SetupWarehouseConfirm;

  /// M5.3 resumable new-store setup: m53SetupPreparePin
  ///
  /// In en, this message translates to:
  /// **'Save security setup'**
  String get m53SetupPreparePin;

  /// M5.3 resumable new-store setup: m53SetupPinsReady
  ///
  /// In en, this message translates to:
  /// **'Security is prepared. Raw PINs are not stored in the draft.'**
  String get m53SetupPinsReady;

  /// M5.3 resumable new-store setup: m53SetupRedoPin
  ///
  /// In en, this message translates to:
  /// **'Prepare PINs again'**
  String get m53SetupRedoPin;

  /// M5.3 resumable new-store setup: m53SetupStockRequired
  ///
  /// In en, this message translates to:
  /// **'Stock tracking is active for warehouse task separation.'**
  String get m53SetupStockRequired;

  /// M5.3 resumable new-store setup: m53SetupPrinterHelp
  ///
  /// In en, this message translates to:
  /// **'You can set up a printer later. Select a profile/transport, connect and try a test print on the printer page. Profiles change only after saving. Failed or cancelled printing does not block setup.'**
  String get m53SetupPrinterHelp;

  /// M5.3 resumable new-store setup: m53SetupOpenPrinter
  ///
  /// In en, this message translates to:
  /// **'Set up printer'**
  String get m53SetupOpenPrinter;

  /// M5.3 resumable new-store setup: m53SetupSkipPrinter
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get m53SetupSkipPrinter;

  /// M5.3 resumable new-store setup: m53SetupOffline
  ///
  /// In en, this message translates to:
  /// **'Setup needs no internet or Google account. The initial currency is IDR; currency settings remain available in store settings.'**
  String get m53SetupOffline;

  /// M5.3 resumable new-store setup: m53SetupVisiblePin
  ///
  /// In en, this message translates to:
  /// **'Show PIN'**
  String get m53SetupVisiblePin;

  /// M5.3 resumable new-store setup: m53SetupShowRecovery
  ///
  /// In en, this message translates to:
  /// **'Show recovery code'**
  String get m53SetupShowRecovery;

  /// M5.3 resumable new-store setup: m53SetupDraftInvalid
  ///
  /// In en, this message translates to:
  /// **'The setup draft is invalid. Check the fields and try again.'**
  String get m53SetupDraftInvalid;

  /// M5.3 resumable new-store setup: m53SetupChanged
  ///
  /// In en, this message translates to:
  /// **'Setup progress changed. Reopen setup to load the latest progress.'**
  String get m53SetupChanged;

  /// M5.3 resumable new-store setup: m53SetupUnavailable
  ///
  /// In en, this message translates to:
  /// **'New-store setup is unavailable for a configured store or a store with business data.'**
  String get m53SetupUnavailable;

  /// M5.3 resumable new-store setup: m53SetupPinsRequired
  ///
  /// In en, this message translates to:
  /// **'Complete security setup and save the recovery code first.'**
  String get m53SetupPinsRequired;

  /// M5.3 resumable new-store setup: m53SetupSaved
  ///
  /// In en, this message translates to:
  /// **'Progress is saved on this device.'**
  String get m53SetupSaved;

  /// M5.3 resumable new-store setup: m53SetupWholesale
  ///
  /// In en, this message translates to:
  /// **'Wholesale prices'**
  String get m53SetupWholesale;

  /// M5.3 resumable new-store setup: m53SetupPackaging
  ///
  /// In en, this message translates to:
  /// **'Carton/box packaging'**
  String get m53SetupPackaging;

  /// M5.3 resumable new-store setup: m53SetupCost
  ///
  /// In en, this message translates to:
  /// **'Purchase price/cost'**
  String get m53SetupCost;

  /// M5.3 resumable new-store setup: m53SetupBarcode
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get m53SetupBarcode;

  /// M5.3 resumable new-store setup: m53SetupExpiry
  ///
  /// In en, this message translates to:
  /// **'Expiry tracking'**
  String get m53SetupExpiry;

  /// M5.3 resumable new-store setup: m53SetupPackagingHelp
  ///
  /// In en, this message translates to:
  /// **'Enter package quantity and units per package. Base stock stays in pieces; configuration changes do not alter old transactions.'**
  String get m53SetupPackagingHelp;

  /// M5.3 resumable new-store setup: m53SetupOptionalFeatures
  ///
  /// In en, this message translates to:
  /// **'Additional features can be enabled later in feature settings.'**
  String get m53SetupOptionalFeatures;

  /// M5.3 resumable new-store setup: m53SetupSecurityHidden
  ///
  /// In en, this message translates to:
  /// **'Setup is hidden while the app is inactive.'**
  String get m53SetupSecurityHidden;

  /// M5.3 separate cashier authorization: m53CashierLockSettings
  ///
  /// In en, this message translates to:
  /// **'Optional cashier lock'**
  String get m53CashierLockSettings;

  /// M5.3 separate cashier authorization: m53CashierEnable
  ///
  /// In en, this message translates to:
  /// **'Enable cashier lock'**
  String get m53CashierEnable;

  /// M5.3 separate cashier authorization: m53CashierLockNow
  ///
  /// In en, this message translates to:
  /// **'Lock cashier'**
  String get m53CashierLockNow;

  /// M5.3 separate cashier authorization: m53CashierScreenLock
  ///
  /// In en, this message translates to:
  /// **'Lock cashier when the device screen locks'**
  String get m53CashierScreenLock;

  /// M5.3 separate cashier authorization: m53CashierPinSource
  ///
  /// In en, this message translates to:
  /// **'PIN used to unlock Cashier'**
  String get m53CashierPinSource;

  /// M5.3 separate cashier authorization: m53CashierOwnerReference
  ///
  /// In en, this message translates to:
  /// **'Use Owner/Management PIN'**
  String get m53CashierOwnerReference;

  /// M5.3 separate cashier authorization: m53CashierOwnPin
  ///
  /// In en, this message translates to:
  /// **'Use a separate cashier PIN'**
  String get m53CashierOwnPin;

  /// M5.3 separate cashier authorization: m53CashierPin
  ///
  /// In en, this message translates to:
  /// **'Cashier PIN'**
  String get m53CashierPin;

  /// M5.3 separate cashier authorization: m53CashierNewPin
  ///
  /// In en, this message translates to:
  /// **'New cashier PIN'**
  String get m53CashierNewPin;

  /// M5.3 separate cashier authorization: m53CashierOwnerPin
  ///
  /// In en, this message translates to:
  /// **'Owner/Management PIN'**
  String get m53CashierOwnerPin;

  /// M5.3 separate cashier authorization: m53CashierLocked
  ///
  /// In en, this message translates to:
  /// **'Cashier locked'**
  String get m53CashierLocked;

  /// M5.3 separate cashier authorization: m53CashierUnlock
  ///
  /// In en, this message translates to:
  /// **'Unlock Cashier'**
  String get m53CashierUnlock;

  /// M5.3 separate cashier authorization: m53CashierUnlockHelp
  ///
  /// In en, this message translates to:
  /// **'Enter the cashier PIN. Unlocking Cashier does not grant management access. Your cart and tender draft are retained.'**
  String get m53CashierUnlockHelp;

  /// M5.3 separate cashier authorization: m53CashierOwnerReferenceHelp
  ///
  /// In en, this message translates to:
  /// **'This setting uses the Owner/Management PIN to unlock Cashier only. It does not grant management access or restart the management biometric PIN interval.'**
  String get m53CashierOwnerReferenceHelp;

  /// M5.3 separate cashier authorization: m53CashierPolicyHelp
  ///
  /// In en, this message translates to:
  /// **'Off by default. The owner can choose a separate cashier PIN or reference the management PIN. The Lock cashier shortcut works whenever enabled. The screen option uses Android lock/noninteractive state; permission dialogs, notifications and briefly switching apps do not by themselves lock Cashier. Cart and tender are retained.'**
  String get m53CashierPolicyHelp;

  /// M5.3 separate cashier authorization: m53CashierOwnPinHelp
  ///
  /// In en, this message translates to:
  /// **'A four-digit PIN is required when enabling or switching to a separate cashier PIN. While that PIN is already active, leave both fields empty to retain it. The owner can disable the lock if the cashier PIN is forgotten.'**
  String get m53CashierOwnPinHelp;

  /// M5.3 separate cashier authorization: m53CashierPinRequired
  ///
  /// In en, this message translates to:
  /// **'Set up a four-digit cashier PIN first.'**
  String get m53CashierPinRequired;

  /// M5.3 separate cashier authorization: m53CashierForgotPin
  ///
  /// In en, this message translates to:
  /// **'Forgot cashier PIN? Owner help'**
  String get m53CashierForgotPin;

  /// M5.3 separate cashier authorization: m53CashierUsePin
  ///
  /// In en, this message translates to:
  /// **'Return to cashier PIN'**
  String get m53CashierUsePin;

  /// M5.3 separate cashier authorization: m53CashierOwnerDisableHelp
  ///
  /// In en, this message translates to:
  /// **'Only the owner can disable this lock with the Owner/Management PIN. A Warehouse or cashier PIN does not grant this right. Store data is retained.'**
  String get m53CashierOwnerDisableHelp;

  /// M5.3 separate cashier authorization: m53CashierDisableConsent
  ///
  /// In en, this message translates to:
  /// **'I am the owner and confirm disabling the cashier lock.'**
  String get m53CashierDisableConsent;

  /// M5.3 separate cashier authorization: m53CashierDisable
  ///
  /// In en, this message translates to:
  /// **'Disable cashier lock'**
  String get m53CashierDisable;

  /// M5.3 separate cashier authorization: m53CashierScreenUnavailable
  ///
  /// In en, this message translates to:
  /// **'Automatic screen-lock detection is unavailable right now. Use the Lock cashier shortcut; the manual cashier PIN gate still applies.'**
  String get m53CashierScreenUnavailable;

  /// M5.3 additive tender editor: m53QuickAmountsInvalid
  ///
  /// In en, this message translates to:
  /// **'Quick cash amounts must be positive, unique, and contain 1 to 8 values.'**
  String get m53QuickAmountsInvalid;

  /// M5.3 additive tender editor: m53RemoveDenomination
  ///
  /// In en, this message translates to:
  /// **'Remove one note/coin of this denomination'**
  String get m53RemoveDenomination;

  /// M5.3 additive tender editor: m53EditQuickAmounts
  ///
  /// In en, this message translates to:
  /// **'Edit amounts'**
  String get m53EditQuickAmounts;

  /// M5.3 additive tender editor: m53UnclassifiedTender
  ///
  /// In en, this message translates to:
  /// **'Amount without denomination details'**
  String get m53UnclassifiedTender;

  /// M5.3 additive tender editor: m53TenderCompositionRetained
  ///
  /// In en, this message translates to:
  /// **'Denomination details are retained. Manually editing the amount replaces them with an amount without denomination details.'**
  String get m53TenderCompositionRetained;

  /// M5.3 stable member identity and transactional selection: m53MemberFieldsInvalid
  ///
  /// In en, this message translates to:
  /// **'Enter a member name (up to 200 characters), a phone number up to 128 characters, and an address up to 4096 characters.'**
  String get m53MemberFieldsInvalid;

  /// M5.3 stable member identity and transactional selection: m53MemberPhoneRequired
  ///
  /// In en, this message translates to:
  /// **'A phone number is required for a new member.'**
  String get m53MemberPhoneRequired;

  /// M5.3 stable member identity and transactional selection: m53MemberPhoneUsed
  ///
  /// In en, this message translates to:
  /// **'Another member already uses this number. Select the correct member or ask the owner to correct the profile.'**
  String get m53MemberPhoneUsed;

  /// M5.3 stable member identity and transactional selection: m53MemberRepairRequired
  ///
  /// In en, this message translates to:
  /// **'The owner must complete this member profile before a new credit sale. Existing debts can still be paid.'**
  String get m53MemberRepairRequired;

  /// M5.3 stable member identity and transactional selection: m53MemberNameRequired
  ///
  /// In en, this message translates to:
  /// **'Enter the member name.'**
  String get m53MemberNameRequired;

  /// M5.3 stable member identity and transactional selection: m53Members
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get m53Members;

  /// M5.3 stable member identity and transactional selection: m53MemberName
  ///
  /// In en, this message translates to:
  /// **'Member name'**
  String get m53MemberName;

  /// M5.3 stable member identity and transactional selection: m53MemberPhone
  ///
  /// In en, this message translates to:
  /// **'Member phone number'**
  String get m53MemberPhone;

  /// M5.3 stable member identity and transactional selection: m53MemberAddress
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get m53MemberAddress;

  /// M5.3 stable member identity and transactional selection: m53UseMember
  ///
  /// In en, this message translates to:
  /// **'Link to a member'**
  String get m53UseMember;

  /// M5.3 stable member identity and transactional selection: m53MemberVisits
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get m53MemberVisits;

  /// M5.3 stable member identity and transactional selection: m53MemberVisitHelp
  ///
  /// In en, this message translates to:
  /// **'Purchases count completed sales that have not been reversed. Debt repayments do not count as new purchases.'**
  String get m53MemberVisitHelp;

  /// M5.3 stable member identity and transactional selection: m53NoMembers
  ///
  /// In en, this message translates to:
  /// **'No matching members.'**
  String get m53NoMembers;

  /// M5.3 stable member identity and transactional selection: m53ArchivedMembers
  ///
  /// In en, this message translates to:
  /// **'Archived members'**
  String get m53ArchivedMembers;

  /// M5.3 stable member identity and transactional selection: m53ArchiveMember
  ///
  /// In en, this message translates to:
  /// **'Archive member'**
  String get m53ArchiveMember;

  /// M5.3 stable member identity and transactional selection: m53RestoreMember
  ///
  /// In en, this message translates to:
  /// **'Restore member'**
  String get m53RestoreMember;

  /// M5.3 stable member identity and transactional selection: m53MemberSelected
  ///
  /// In en, this message translates to:
  /// **'Selected member'**
  String get m53MemberSelected;

  /// M5.3 stable member identity and transactional selection: m53ChangeMember
  ///
  /// In en, this message translates to:
  /// **'Change member / create new'**
  String get m53ChangeMember;

  /// M5.3 stable member identity and transactional selection: m53MemberSaved
  ///
  /// In en, this message translates to:
  /// **'Member profile saved.'**
  String get m53MemberSaved;

  /// M5.3 stable member identity and transactional selection: m53MemberSearch
  ///
  /// In en, this message translates to:
  /// **'Search name or phone number'**
  String get m53MemberSearch;

  /// M5.3 stable member identity and transactional selection: m53MemberCreate
  ///
  /// In en, this message translates to:
  /// **'Create member'**
  String get m53MemberCreate;

  /// M5.3 stable member identity and transactional selection: m53GuestHelp
  ///
  /// In en, this message translates to:
  /// **'Paid sales may use a guest. Credit sales must select or create a member.'**
  String get m53GuestHelp;

  /// M5.3 stable member identity and transactional selection: m53MemberPhoneHelp
  ///
  /// In en, this message translates to:
  /// **'Use a valid, unique number. Include a country code, such as +62, if it differs from the shop phone region.'**
  String get m53MemberPhoneHelp;

  /// M5.3 stable member identity and transactional selection: m53ArchiveMemberHelp
  ///
  /// In en, this message translates to:
  /// **'Archiving hides the member from new sales. History and debts remain, and existing debts can still be paid. The phone number remains linked to this profile.'**
  String get m53ArchiveMemberHelp;

  /// M5.3 stable member identity and transactional selection: m53Guest
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get m53Guest;

  /// M5.3 product search ranking: m53SearchFrequent
  ///
  /// In en, this message translates to:
  /// **'Most frequently sold'**
  String get m53SearchFrequent;

  /// M5.3 product search ranking: m53SearchRelevance
  ///
  /// In en, this message translates to:
  /// **'Most relevant'**
  String get m53SearchRelevance;

  /// M5.3 product search ranking: m53SearchOrder
  ///
  /// In en, this message translates to:
  /// **'Result order'**
  String get m53SearchOrder;

  /// M5.3 product search ranking: m53SearchHelpTitle
  ///
  /// In en, this message translates to:
  /// **'Product search order'**
  String get m53SearchHelpTitle;

  /// M5.3 product search ranking: m53SearchHelp
  ///
  /// In en, this message translates to:
  /// **'Eligible products appear first. An exact code or barcode stays first even when unavailable; unavailable products cannot be added. Most frequently sold counts completed sales containing the product in the last 30 days, then net quantity and search relevance. Cancelled sales are excluded. Multiple units in one sale still count as one sale. Debt repayments are not new sales. Only matching products appear. The snapshot refreshes after a sale/cancellation, when returning to the app, or when the next search is more than 60 seconds later. Use Refresh to update the current results.'**
  String get m53SearchHelp;

  /// M5.3 product search ranking: m53SearchRefresh
  ///
  /// In en, this message translates to:
  /// **'Refresh results'**
  String get m53SearchRefresh;

  /// M5.3 product search ranking: m53SearchMore
  ///
  /// In en, this message translates to:
  /// **'More results'**
  String get m53SearchMore;

  /// M5.3 physical cash declarations and session accounting: m53CashDrawer
  ///
  /// In en, this message translates to:
  /// **'Cash drawer and pieces'**
  String get m53CashDrawer;

  /// M5.3 physical cash declarations and session accounting: m53CashPolicy
  ///
  /// In en, this message translates to:
  /// **'Cash recording policy'**
  String get m53CashPolicy;

  /// M5.3 physical cash declarations and session accounting: m53CashOff
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get m53CashOff;

  /// M5.3 physical cash declarations and session accounting: m53CashNotes
  ///
  /// In en, this message translates to:
  /// **'Cashier notes'**
  String get m53CashNotes;

  /// M5.3 physical cash declarations and session accounting: m53CashAudit
  ///
  /// In en, this message translates to:
  /// **'Owner required audit'**
  String get m53CashAudit;

  /// M5.3 physical cash declarations and session accounting: m53CashAuditHelp
  ///
  /// In en, this message translates to:
  /// **'The owner requires piece counts for cash. Cashiers cannot disable this. Piece counts are cashier declarations, not proof of the physical cash. A difference does not automatically mean misconduct.'**
  String get m53CashAuditHelp;

  /// M5.3 physical cash declarations and session accounting: m53CashNotesHelp
  ///
  /// In en, this message translates to:
  /// **'Enable this to help record daily cash. Records remain when the date changes or recording is disabled. Close open sessions before disabling recording.'**
  String get m53CashNotesHelp;

  /// M5.3 physical cash declarations and session accounting: m53CashReasonRequired
  ///
  /// In en, this message translates to:
  /// **'Enter a reason of at most 1,000 characters.'**
  String get m53CashReasonRequired;

  /// M5.3 physical cash declarations and session accounting: m53CashPolicyChanged
  ///
  /// In en, this message translates to:
  /// **'The cash policy changed. Reload and review your choice.'**
  String get m53CashPolicyChanged;

  /// M5.3 physical cash declarations and session accounting: m53CashCloseSessionsFirst
  ///
  /// In en, this message translates to:
  /// **'Close the open cash sessions before changing this policy.'**
  String get m53CashCloseSessionsFirst;

  /// M5.3 physical cash declarations and session accounting: m53CashAuditRequired
  ///
  /// In en, this message translates to:
  /// **'Recording is required by the owner and cannot be disabled by the cashier.'**
  String get m53CashAuditRequired;

  /// M5.3 physical cash declarations and session accounting: m53CashRecordingOff
  ///
  /// In en, this message translates to:
  /// **'Cash recording is off.'**
  String get m53CashRecordingOff;

  /// M5.3 physical cash declarations and session accounting: m53CashSessionChanged
  ///
  /// In en, this message translates to:
  /// **'The cash session, date, or settings changed. Reload and review your entries before trying again.'**
  String get m53CashSessionChanged;

  /// M5.3 physical cash declarations and session accounting: m53CashSessionAlreadyOpen
  ///
  /// In en, this message translates to:
  /// **'A cash session is already open today. Reload to view it.'**
  String get m53CashSessionAlreadyOpen;

  /// M5.3 physical cash declarations and session accounting: m53CashPreviousUnclosed
  ///
  /// In en, this message translates to:
  /// **'A session from another day is still open. Review the warning before opening a new one.'**
  String get m53CashPreviousUnclosed;

  /// M5.3 physical cash declarations and session accounting: m53CashClockChanged
  ///
  /// In en, this message translates to:
  /// **'The device time is earlier than the latest cash record. Check the device time before continuing.'**
  String get m53CashClockChanged;

  /// M5.3 physical cash declarations and session accounting: m53CashOldSession
  ///
  /// In en, this message translates to:
  /// **'This session belongs to an earlier date or settings. A current count cannot be treated as the physical count from that time.'**
  String get m53CashOldSession;

  /// M5.3 physical cash declarations and session accounting: m53CashCountRequired
  ///
  /// In en, this message translates to:
  /// **'Enter the physical piece counts before closing the session.'**
  String get m53CashCountRequired;

  /// M5.3 physical cash declarations and session accounting: m53CashPiecesUnavailable
  ///
  /// In en, this message translates to:
  /// **'The outgoing pieces are not available in the records. Recount the drawer with a reason or correct the piece details, then try again. The balance has not been reduced.'**
  String get m53CashPiecesUnavailable;

  /// M5.3 physical cash declarations and session accounting: m53CashCompositionRequired
  ///
  /// In en, this message translates to:
  /// **'Active recording requires complete cash piece counts. An amount alone or Exact cash is insufficient.'**
  String get m53CashCompositionRequired;

  /// M5.3 physical cash declarations and session accounting: m53CashCompositionMismatch
  ///
  /// In en, this message translates to:
  /// **'The piece total must exactly match the required amount. No automatic rounding is applied.'**
  String get m53CashCompositionMismatch;

  /// M5.3 physical cash declarations and session accounting: m53CashSessionRequired
  ///
  /// In en, this message translates to:
  /// **'Open today’s cash session and review the opening balance before recording cash.'**
  String get m53CashSessionRequired;

  /// M5.3 physical cash declarations and session accounting: m53CashCountInvalid
  ///
  /// In en, this message translates to:
  /// **'Check the piece counts. Use whole numbers from 0 to 1,000,000.'**
  String get m53CashCountInvalid;

  /// M5.3 physical cash declarations and session accounting: m53CashDeclarationHelp
  ///
  /// In en, this message translates to:
  /// **'Enter the number of pieces you observe for each denomination. The + button adds one note or coin. These are declared counts, not sensor readings.'**
  String get m53CashDeclarationHelp;

  /// M5.3 physical cash declarations and session accounting: m53CashRequiredTotal
  ///
  /// In en, this message translates to:
  /// **'Required total'**
  String get m53CashRequiredTotal;

  /// M5.3 physical cash declarations and session accounting: m53CashClearCounts
  ///
  /// In en, this message translates to:
  /// **'Clear counts'**
  String get m53CashClearCounts;

  /// M5.3 physical cash declarations and session accounting: m53CashPieceCount
  ///
  /// In en, this message translates to:
  /// **'Piece count'**
  String get m53CashPieceCount;

  /// M5.3 physical cash declarations and session accounting: m53CashAddPiece
  ///
  /// In en, this message translates to:
  /// **'Add one piece'**
  String get m53CashAddPiece;

  /// M5.3 physical cash declarations and session accounting: m53CashIncoming
  ///
  /// In en, this message translates to:
  /// **'Pieces received'**
  String get m53CashIncoming;

  /// M5.3 physical cash declarations and session accounting: m53CashChangeCounts
  ///
  /// In en, this message translates to:
  /// **'Change pieces'**
  String get m53CashChangeCounts;

  /// M5.3 physical cash declarations and session accounting: m53CashOpeningCounts
  ///
  /// In en, this message translates to:
  /// **'Opening piece count'**
  String get m53CashOpeningCounts;

  /// M5.3 physical cash declarations and session accounting: m53CashObservedCounts
  ///
  /// In en, this message translates to:
  /// **'Current physical count'**
  String get m53CashObservedCounts;

  /// M5.3 physical cash declarations and session accounting: m53CashRefundCounts
  ///
  /// In en, this message translates to:
  /// **'Refund pieces'**
  String get m53CashRefundCounts;

  /// M5.3 physical cash declarations and session accounting: m53CashJournalCounts
  ///
  /// In en, this message translates to:
  /// **'Pieces for this entry'**
  String get m53CashJournalCounts;

  /// M5.3 physical cash declarations and session accounting: m53CashOpeningKnown
  ///
  /// In en, this message translates to:
  /// **'Opening balance counted'**
  String get m53CashOpeningKnown;

  /// M5.3 physical cash declarations and session accounting: m53CashOpeningUnknown
  ///
  /// In en, this message translates to:
  /// **'Opening balance unknown'**
  String get m53CashOpeningUnknown;

  /// M5.3 physical cash declarations and session accounting: m53CashUnknownHelp
  ///
  /// In en, this message translates to:
  /// **'Unknown is different from empty. The expected amount is uncertain. Outgoing cash is limited to pieces already counted or recorded as received. Recount with a reason to correct the records.'**
  String get m53CashUnknownHelp;

  /// M5.3 physical cash declarations and session accounting: m53CashOpenSession
  ///
  /// In en, this message translates to:
  /// **'Open cash session'**
  String get m53CashOpenSession;

  /// M5.3 physical cash declarations and session accounting: m53CashCloseSession
  ///
  /// In en, this message translates to:
  /// **'Close cash session'**
  String get m53CashCloseSession;

  /// M5.3 physical cash declarations and session accounting: m53CashRecount
  ///
  /// In en, this message translates to:
  /// **'Recount and record correction'**
  String get m53CashRecount;

  /// M5.3 physical cash declarations and session accounting: m53CashExpected
  ///
  /// In en, this message translates to:
  /// **'Expected pieces'**
  String get m53CashExpected;

  /// M5.3 physical cash declarations and session accounting: m53CashLowerBound
  ///
  /// In en, this message translates to:
  /// **'Minimum pieces already recorded'**
  String get m53CashLowerBound;

  /// M5.3 physical cash declarations and session accounting: m53CashBalance
  ///
  /// In en, this message translates to:
  /// **'Recorded piece value'**
  String get m53CashBalance;

  /// M5.3 physical cash declarations and session accounting: m53CashSessionDate
  ///
  /// In en, this message translates to:
  /// **'Session date'**
  String get m53CashSessionDate;

  /// M5.3 physical cash declarations and session accounting: m53CashPendingDays
  ///
  /// In en, this message translates to:
  /// **'Other days have unclosed sessions'**
  String get m53CashPendingDays;

  /// M5.3 physical cash declarations and session accounting: m53CashPendingHelp
  ///
  /// In en, this message translates to:
  /// **'A new date does not close or delete an older session. Review the new opening balance independently; an older balance is not copied automatically.'**
  String get m53CashPendingHelp;

  /// M5.3 physical cash declarations and session accounting: m53CashAcceptPending
  ///
  /// In en, this message translates to:
  /// **'I understand that another day has an unclosed session'**
  String get m53CashAcceptPending;

  /// M5.3 physical cash declarations and session accounting: m53CashNoSession
  ///
  /// In en, this message translates to:
  /// **'There is no open cash session for today.'**
  String get m53CashNoSession;

  /// M5.3 physical cash declarations and session accounting: m53CashSessionClosed
  ///
  /// In en, this message translates to:
  /// **'This session is closed. Its records and counts remain stored.'**
  String get m53CashSessionClosed;

  /// M5.3 physical cash declarations and session accounting: m53CashCashIn
  ///
  /// In en, this message translates to:
  /// **'Cash in excluding sales'**
  String get m53CashCashIn;

  /// M5.3 physical cash declarations and session accounting: m53CashCashOut
  ///
  /// In en, this message translates to:
  /// **'Cash out'**
  String get m53CashCashOut;

  /// M5.3 physical cash declarations and session accounting: m53CashHandover
  ///
  /// In en, this message translates to:
  /// **'Deposit or cash handover'**
  String get m53CashHandover;

  /// M5.3 physical cash declarations and session accounting: m53CashReason
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get m53CashReason;

  /// M5.3 physical cash declarations and session accounting: m53CashHistory
  ///
  /// In en, this message translates to:
  /// **'Session and journal history'**
  String get m53CashHistory;

  /// M5.3 physical cash declarations and session accounting: m53CashDifference
  ///
  /// In en, this message translates to:
  /// **'Count difference'**
  String get m53CashDifference;

  /// M5.3 physical cash declarations and session accounting: m53CashDifferenceHelp
  ///
  /// In en, this message translates to:
  /// **'A difference compares recorded cash with the declared count. It does not change sales and is not proof of theft.'**
  String get m53CashDifferenceHelp;

  /// M5.3 physical cash declarations and session accounting: m53CashOwnerException
  ///
  /// In en, this message translates to:
  /// **'Close without historical count — owner'**
  String get m53CashOwnerException;

  /// M5.3 physical cash declarations and session accounting: m53CashOwnerExceptionHelp
  ///
  /// In en, this message translates to:
  /// **'Use this when the physical count from an older session is unavailable. The owner PIN and a reason are required. The record is marked unverified, not treated as a zero difference.'**
  String get m53CashOwnerExceptionHelp;

  /// M5.3 physical cash declarations and session accounting: m53CashSourceDrawer
  ///
  /// In en, this message translates to:
  /// **'Cash from/to drawer'**
  String get m53CashSourceDrawer;

  /// M5.3 physical cash declarations and session accounting: m53CashSourceExternal
  ///
  /// In en, this message translates to:
  /// **'Outside drawer / noncash'**
  String get m53CashSourceExternal;

  /// M5.3 physical cash declarations and session accounting: m53CashSourceUnknown
  ///
  /// In en, this message translates to:
  /// **'Legacy payment source unknown'**
  String get m53CashSourceUnknown;

  /// M5.3 physical cash declarations and session accounting: m53CashEditReceived
  ///
  /// In en, this message translates to:
  /// **'Enter or review received pieces'**
  String get m53CashEditReceived;

  /// M5.3 physical cash declarations and session accounting: m53CashCurrentSession
  ///
  /// In en, this message translates to:
  /// **'Cash session used'**
  String get m53CashCurrentSession;

  /// M5.3 physical cash declarations and session accounting: m53CashReviewSession
  ///
  /// In en, this message translates to:
  /// **'Review and use this session'**
  String get m53CashReviewSession;

  /// M5.3 physical cash declarations and session accounting: m53CashMissingDetails
  ///
  /// In en, this message translates to:
  /// **'The piece details are incomplete. The previous amount is retained until you replace it.'**
  String get m53CashMissingDetails;

  /// M5.3 physical cash declarations and session accounting: m53CashPaymentDeclaration
  ///
  /// In en, this message translates to:
  /// **'Payment source and details'**
  String get m53CashPaymentDeclaration;

  /// M5.3 physical cash declarations and session accounting: m53CashRefundPieces
  ///
  /// In en, this message translates to:
  /// **'Refund pieces'**
  String get m53CashRefundPieces;

  /// M5.3 physical cash declarations and session accounting: m53CashDetailsUnknown
  ///
  /// In en, this message translates to:
  /// **'Details or count unknown'**
  String get m53CashDetailsUnknown;

  /// M5.3 physical cash declarations and session accounting: m53CashPublicHistoryHelp
  ///
  /// In en, this message translates to:
  /// **'Cashier notes remain available here. The owner opens audit history from Management.'**
  String get m53CashPublicHistoryHelp;

  /// M5.3 physical cash declarations and session accounting: m53CashClosingCounts
  ///
  /// In en, this message translates to:
  /// **'Physical count at closing'**
  String get m53CashClosingCounts;

  /// M5.3 physical cash declarations and session accounting: m53CashReference
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get m53CashReference;

  /// M5.3 physical cash declarations and session accounting: m53CashSaleAudit
  ///
  /// In en, this message translates to:
  /// **'Transaction cash details'**
  String get m53CashSaleAudit;

  /// M5.3 physical cash declarations and session accounting: m53CashApplied
  ///
  /// In en, this message translates to:
  /// **'Applied payment'**
  String get m53CashApplied;

  /// M5.3 physical cash declarations and session accounting: m53CashUnclassified
  ///
  /// In en, this message translates to:
  /// **'Amount without piece details'**
  String get m53CashUnclassified;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraScan
  ///
  /// In en, this message translates to:
  /// **'Scan with camera'**
  String get m53CameraScan;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraHelp
  ///
  /// In en, this message translates to:
  /// **'Aim one code at the camera. Review the selected text and tap Use code. Tap Scan again for the next item, including the same code. A product barcode cannot prove that a physical item was scanned only once.'**
  String get m53CameraHelp;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraUnavailable
  ///
  /// In en, this message translates to:
  /// **'The camera is unavailable or could not open. Use manual search or an external scanner.'**
  String get m53CameraUnavailable;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraInvalidCode
  ///
  /// In en, this message translates to:
  /// **'The code is invalid or its format is unsupported. Use manual entry.'**
  String get m53CameraInvalidCode;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraPermissionDenied
  ///
  /// In en, this message translates to:
  /// **'Camera permission has not been granted. Manual search and external scanners remain available. You can retry after allowing camera access.'**
  String get m53CameraPermissionDenied;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraStoreChanged
  ///
  /// In en, this message translates to:
  /// **'The store data was replaced. Close the scanner and reopen it from the current store.'**
  String get m53CameraStoreChanged;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraFeatureOff
  ///
  /// In en, this message translates to:
  /// **'The barcode feature is disabled in store preferences. Manual entry remains available.'**
  String get m53CameraFeatureOff;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraLookupFailed
  ///
  /// In en, this message translates to:
  /// **'The code could not be processed. Review the result and try scanning again.'**
  String get m53CameraLookupFailed;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraStart
  ///
  /// In en, this message translates to:
  /// **'Start camera'**
  String get m53CameraStart;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraScanAgain
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get m53CameraScanAgain;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraAim
  ///
  /// In en, this message translates to:
  /// **'Camera active. Aim a code at the scan area.'**
  String get m53CameraAim;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraPaused
  ///
  /// In en, this message translates to:
  /// **'Scanning is paused until you start or scan again.'**
  String get m53CameraPaused;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraSelectedCode
  ///
  /// In en, this message translates to:
  /// **'Selected code'**
  String get m53CameraSelectedCode;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraUseCode
  ///
  /// In en, this message translates to:
  /// **'Use code'**
  String get m53CameraUseCode;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraRegisterProduct
  ///
  /// In en, this message translates to:
  /// **'Register product using the form'**
  String get m53CameraRegisterProduct;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraManualFallback
  ///
  /// In en, this message translates to:
  /// **'Back to manual entry / external scanner'**
  String get m53CameraManualFallback;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraAdded
  ///
  /// In en, this message translates to:
  /// **'One item added to the cart.'**
  String get m53CameraAdded;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraProductOpened
  ///
  /// In en, this message translates to:
  /// **'Product details opened. Stock is unchanged.'**
  String get m53CameraProductOpened;

  /// M5.3 offline barcode camera and guarded intentional scan: m53CameraCodeCopied
  ///
  /// In en, this message translates to:
  /// **'The code was filled in the form. The product has not been saved.'**
  String get m53CameraCodeCopied;

  /// M5.3 explicit choice for equivalent UPC-A/EAN13 bars without silent zero removal
  ///
  /// In en, this message translates to:
  /// **'A zero-prefixed EAN-13 and UPC-A can use the same bars. Select the exact code text stored for your product; the app does not silently change it.'**
  String get m53CameraEquivalentCodes;

  /// M5.3 durable bounded receiving draft: m53ReceiptDrafts
  ///
  /// In en, this message translates to:
  /// **'Receiving drafts'**
  String get m53ReceiptDrafts;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftNew
  ///
  /// In en, this message translates to:
  /// **'New receiving draft'**
  String get m53ReceiptDraftNew;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraft
  ///
  /// In en, this message translates to:
  /// **'Receiving draft'**
  String get m53ReceiptDraft;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftSaved
  ///
  /// In en, this message translates to:
  /// **'Draft saved. Stock has not changed.'**
  String get m53ReceiptDraftSaved;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftNoStockYet
  ///
  /// In en, this message translates to:
  /// **'Scanning and editing change only the draft. Stock changes once when the entire document is confirmed. A product barcode does not identify its physical batch.'**
  String get m53ReceiptDraftNoStockYet;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftPosted
  ///
  /// In en, this message translates to:
  /// **'Receiving confirmed. Stock and history have been recorded.'**
  String get m53ReceiptDraftPosted;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftChanged
  ///
  /// In en, this message translates to:
  /// **'The draft changed or is closed. Reload and review before continuing.'**
  String get m53ReceiptDraftChanged;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftLimit
  ///
  /// In en, this message translates to:
  /// **'A draft supports up to 100 lines. Finish or split this document.'**
  String get m53ReceiptDraftLimit;

  /// M5.3 durable bounded receiving draft: m53ReceiptChooseLine
  ///
  /// In en, this message translates to:
  /// **'Choose a receiving line or batch'**
  String get m53ReceiptChooseLine;

  /// M5.3 durable bounded receiving draft: m53ReceiptSeparateLine
  ///
  /// In en, this message translates to:
  /// **'Several lines could receive this code. Create a separate line, then enter the correct quantity and batch?'**
  String get m53ReceiptSeparateLine;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftEmpty
  ///
  /// In en, this message translates to:
  /// **'Add at least one product before confirming.'**
  String get m53ReceiptDraftEmpty;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftCode
  ///
  /// In en, this message translates to:
  /// **'Exact barcode or SKU (external scanner supported)'**
  String get m53ReceiptDraftCode;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftAddCode
  ///
  /// In en, this message translates to:
  /// **'Add 1 base unit'**
  String get m53ReceiptDraftAddCode;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftScanAdded
  ///
  /// In en, this message translates to:
  /// **'One base unit added to the draft. Stock has not changed.'**
  String get m53ReceiptDraftScanAdded;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftConfirm
  ///
  /// In en, this message translates to:
  /// **'Confirm receiving'**
  String get m53ReceiptDraftConfirm;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftConfirmHelp
  ///
  /// In en, this message translates to:
  /// **'Review every quantity, unit, pack size, cost, purchase supplier and expiry. Confirmation posts all lines together; any failed line rolls back the entire posting.'**
  String get m53ReceiptDraftConfirmHelp;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftReview
  ///
  /// In en, this message translates to:
  /// **'Review current product data'**
  String get m53ReceiptDraftReview;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftReviewHelp
  ///
  /// In en, this message translates to:
  /// **'Refresh product and stock baselines to their current state. Draft input is retained; review prices, units and quantities before confirming again.'**
  String get m53ReceiptDraftReviewHelp;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftCancel
  ///
  /// In en, this message translates to:
  /// **'Cancel receiving draft'**
  String get m53ReceiptDraftCancel;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftCancelHelp
  ///
  /// In en, this message translates to:
  /// **'Close this draft without changing stock? Cancelled drafts are retained as a record and cannot be edited again.'**
  String get m53ReceiptDraftCancelHelp;

  /// M5.3 durable bounded receiving draft: m53ReceiptRegisterUnknown
  ///
  /// In en, this message translates to:
  /// **'This code is not registered. Create a product with opening stock 0, then return to the draft?'**
  String get m53ReceiptRegisterUnknown;

  /// M5.3 durable bounded receiving draft: m53ReceiptNewProductZero
  ///
  /// In en, this message translates to:
  /// **'New products for this draft use opening stock 0. Enter and confirm received quantities in the receiving document.'**
  String get m53ReceiptNewProductZero;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftExistingCost
  ///
  /// In en, this message translates to:
  /// **'The cost already entered in this draft is shown so editing units or quantity does not erase it.'**
  String get m53ReceiptDraftExistingCost;

  /// M5.3 durable bounded receiving draft: m53ReceiptReverseWholeDocument
  ///
  /// In en, this message translates to:
  /// **'This receipt belongs to a complete document. Open it and review all lines before reversing.'**
  String get m53ReceiptReverseWholeDocument;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftReversed
  ///
  /// In en, this message translates to:
  /// **'The entire receipt has been reversed; original records are retained.'**
  String get m53ReceiptDraftReversed;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftReverse
  ///
  /// In en, this message translates to:
  /// **'Reverse this entire receipt'**
  String get m53ReceiptDraftReverse;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftReverseHelp
  ///
  /// In en, this message translates to:
  /// **'This reverses every line in the document, not just one product. It is allowed only when no later stock or cost mutation depends on it. Original history is retained.'**
  String get m53ReceiptDraftReverseHelp;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftCancelled
  ///
  /// In en, this message translates to:
  /// **'Draft cancelled without posting stock.'**
  String get m53ReceiptDraftCancelled;

  /// M5.3 durable bounded receiving draft: m53ReceiptStatusPosted
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get m53ReceiptStatusPosted;

  /// M5.3 durable bounded receiving draft: m53ReceiptStatusCancelled
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get m53ReceiptStatusCancelled;

  /// M5.3 durable bounded receiving draft: m53ReceiptDraftHelp
  ///
  /// In en, this message translates to:
  /// **'Using this draft'**
  String get m53ReceiptDraftHelp;

  /// Stocktake message: Stocktake sessions
  ///
  /// In en, this message translates to:
  /// **'Stocktake sessions'**
  String get m53Stocktakes;

  /// Stocktake message: Stocktake
  ///
  /// In en, this message translates to:
  /// **'Stocktake'**
  String get m53Stocktake;

  /// Stocktake message: Create stocktake draft
  ///
  /// In en, this message translates to:
  /// **'Create stocktake draft'**
  String get m53StocktakeNew;

  /// Stocktake message: Saved draft · stock unchanged
  ///
  /// In en, this message translates to:
  /// **'Saved draft · stock unchanged'**
  String get m53StocktakeDraft;

  /// Stocktake message: Completed stocktake · snapshot saved
  ///
  /// In en, this message translates to:
  /// **'Completed stocktake · snapshot saved'**
  String get m53StocktakePosted;

  /// Stocktake message: System stock at baseline
  ///
  /// In en, this message translates to:
  /// **'System stock at baseline'**
  String get m53StocktakeSystem;

  /// Stocktake message: Counted physical quantity
  ///
  /// In en, this message translates to:
  /// **'Counted physical quantity'**
  String get m53StocktakePhysical;

  /// Stocktake message: Physical difference
  ///
  /// In en, this message translates to:
  /// **'Physical difference'**
  String get m53StocktakeDifference;

  /// Stocktake message: Not yet counted
  ///
  /// In en, this message translates to:
  /// **'Not yet counted'**
  String get m53StocktakeUncounted;

  /// Stocktake message: Edit physical count
  ///
  /// In en, this message translates to:
  /// **'Edit physical count'**
  String get m53StocktakeEdit;

  /// Stocktake message: Observed expiry date
  ///
  /// In en, this message translates to:
  /// **'Observed expiry date'**
  String get m53StocktakeExpiry;

  /// Stocktake message: Blank means not yet counted. Enter 0 only after checking that the stock is absent.
  ///
  /// In en, this message translates to:
  /// **'Blank means not yet counted. Enter 0 only after checking that the stock is absent.'**
  String get m53StocktakeZeroHelp;

  /// Stocktake message: Scan +1 base unit
  ///
  /// In en, this message translates to:
  /// **'Scan +1 base unit'**
  String get m53StocktakeScan;

  /// Stocktake message: Draft count increased by 1 base unit.
  ///
  /// In en, this message translates to:
  /// **'Draft count increased by 1 base unit.'**
  String get m53StocktakeScanAdded;

  /// Stocktake message: Include without counting
  ///
  /// In en, this message translates to:
  /// **'Include without counting'**
  String get m53StocktakeInclude;

  /// Stocktake message: Undo last count
  ///
  /// In en, this message translates to:
  /// **'Undo last count'**
  String get m53StocktakeUndo;

  /// Stocktake message: +1 base unit
  ///
  /// In en, this message translates to:
  /// **'+1 base unit'**
  String get m53StocktakePlus;

  /// Stocktake message: −1 base unit
  ///
  /// In en, this message translates to:
  /// **'−1 base unit'**
  String get m53StocktakeMinus;

  /// Stocktake message: Set physical count to 0
  ///
  /// In en, this message translates to:
  /// **'Set physical count to 0'**
  String get m53StocktakeZero;

  /// Stocktake message: Reset to not counted
  ///
  /// In en, this message translates to:
  /// **'Reset to not counted'**
  String get m53StocktakeReset;

  /// Stocktake message: Counting guide
  ///
  /// In en, this message translates to:
  /// **'Counting guide'**
  String get m53StocktakeHelp;

  /// Stocktake message: Drafts are saved without changing stock. A barcode identifies a product type, not each unique piece: the same piece can be counted twice. Choose the physical batch when several exist. Not counted is not 0. After a sale, receipt, product or time zone change, review and recount before finalization. Differences may arise from counting errors, unrecorded transactions, damage or other causes; they are not evidence of theft.
  ///
  /// In en, this message translates to:
  /// **'Drafts are saved without changing stock. A barcode identifies a product type, not each unique piece: the same piece can be counted twice. Choose the physical batch when several exist. Not counted is not 0. After a sale, receipt, product or time zone change, review and recount before finalization. Differences may arise from counting errors, unrecorded transactions, damage or other causes; they are not evidence of theft.'**
  String get m53StocktakeHelpBody;

  /// Stocktake message: Choose the correct batch using physical evidence. Quantities here are in base units. Found units retain the observed expiry date, including past dates; costing remains the product moving average.
  ///
  /// In en, this message translates to:
  /// **'Choose the correct batch using physical evidence. Quantities here are in base units. Found units retain the observed expiry date, including past dates; costing remains the product moving average.'**
  String get m53StocktakeBatchHelp;

  /// Stocktake message: Batch observations
  ///
  /// In en, this message translates to:
  /// **'Batch observations'**
  String get m53StocktakeBatches;

  /// Stocktake message: Several batches exist. Choose the physical batch for +1; this scan has not increased the count.
  ///
  /// In en, this message translates to:
  /// **'Several batches exist. Choose the physical batch for +1; this scan has not increased the count.'**
  String get m53StocktakeBatchChoice;

  /// Stocktake message: Add a found physical batch
  ///
  /// In en, this message translates to:
  /// **'Add a found physical batch'**
  String get m53StocktakeNewBatch;

  /// Stocktake message: Capture new baseline and recount
  ///
  /// In en, this message translates to:
  /// **'Capture new baseline and recount'**
  String get m53StocktakeRecount;

  /// Stocktake message: This product’s counts, entered value and undo will be cleared. Stock and batch baselines will be captured again from current data. Count the physical stock again. Stock is unchanged.
  ///
  /// In en, this message translates to:
  /// **'This product’s counts, entered value and undo will be cleared. Stock and batch baselines will be captured again from current data. Count the physical stock again. Stock is unchanged.'**
  String get m53StocktakeRecountHelp;

  /// Stocktake message: Remove product from this draft
  ///
  /// In en, this message translates to:
  /// **'Remove product from this draft'**
  String get m53StocktakeRemove;

  /// Stocktake message: Total value of all found stock
  ///
  /// In en, this message translates to:
  /// **'Total value of all found stock'**
  String get m53StocktakeValue;

  /// Stocktake message: System stock started at 0, so no previous average exists. Enter the TOTAL value for the full counted quantity, not a price per piece or pack. Blank means unknown and is allowed only when purchase cost is optional. Zero requires free-cost confirmation. Review the value again if the count changes. This is not a new purchase or supplier debt.
  ///
  /// In en, this message translates to:
  /// **'System stock started at 0, so no previous average exists. Enter the TOTAL value for the full counted quantity, not a price per piece or pack. Blank means unknown and is allowed only when purchase cost is optional. Zero requires free-cost confirmation. Review the value again if the count changes. This is not a new purchase or supplier debt.'**
  String get m53StocktakeValueHelp;

  /// Stocktake message: Estimated value difference
  ///
  /// In en, this message translates to:
  /// **'Estimated value difference'**
  String get m53StocktakeValueDifference;

  /// Stocktake message: Review and finalize stocktake
  ///
  /// In en, this message translates to:
  /// **'Review and finalize stocktake'**
  String get m53StocktakeFinalize;

  /// Stocktake message: Check every product’s baseline, physical count and difference. Stock, batches, value and history update atomically only if the baseline still matches. Results and reason become permanent snapshots. A shortage is not evidence of theft.
  ///
  /// In en, this message translates to:
  /// **'Check every product’s baseline, physical count and difference. Stock, batches, value and history update atomically only if the baseline still matches. Results and reason become permanent snapshots. A shortage is not evidence of theft.'**
  String get m53StocktakeFinalizeHelp;

  /// Stocktake message: Cancel stocktake draft
  ///
  /// In en, this message translates to:
  /// **'Cancel stocktake draft'**
  String get m53StocktakeCancel;

  /// Stocktake message: Keep the session as cancelled. Stock is unchanged and previous input remains in the cancelled draft.
  ///
  /// In en, this message translates to:
  /// **'Keep the session as cancelled. Stock is unchanged and previous input remains in the cancelled draft.'**
  String get m53StocktakeCancelHelp;

  /// Stocktake message: No products yet. Scan a code or include a product without entering a count.
  ///
  /// In en, this message translates to:
  /// **'No products yet. Scan a code or include a product without entering a count.'**
  String get m53StocktakeEmpty;

  /// Stocktake message: Product is not registered. Register it with initial stock 0, then include it in the draft and count its physical stock.
  ///
  /// In en, this message translates to:
  /// **'Product is not registered. Register it with initial stock 0, then include it in the draft and count its physical stock.'**
  String get m53StocktakeRegister;

  /// Stocktake message: The stocktake draft or page changed. Reload and review your input before retrying.
  ///
  /// In en, this message translates to:
  /// **'The stocktake draft or page changed. Reload and review your input before retrying.'**
  String get m53StocktakeChanged;

  /// Stocktake message: Stock, product, batches or time zone changed since the baseline. Open the affected product, capture a new baseline and recount. Old input stays saved until you choose to recount.
  ///
  /// In en, this message translates to:
  /// **'Stock, product, batches or time zone changed since the baseline. Open the affected product, capture a new baseline and recount. Old input stays saved until you choose to recount.'**
  String get m53StocktakeConflict;

  /// Stocktake message: Explicitly count every batch before finalizing. Not counted is not 0.
  ///
  /// In en, this message translates to:
  /// **'Explicitly count every batch before finalizing. Not counted is not 0.'**
  String get m53StocktakeIncomplete;

  /// Stocktake message: A draft supports up to 100 products. Continue remaining products in another session.
  ///
  /// In en, this message translates to:
  /// **'A draft supports up to 100 products. Continue remaining products in another session.'**
  String get m53StocktakeLineLimit;

  /// Stocktake message: This product is untracked; sentinel 999 is not physical stock. Use the tracking activation flow if needed.
  ///
  /// In en, this message translates to:
  /// **'This product is untracked; sentinel 999 is not physical stock. Use the tracking activation flow if needed.'**
  String get m53StocktakeUntracked;

  /// Stocktake message: A baseline batch date cannot be changed by a count. Add a found physical batch if its date differs.
  ///
  /// In en, this message translates to:
  /// **'A baseline batch date cannot be changed by a count. Add a found physical batch if its date differs.'**
  String get m53StocktakeFrozenBatch;

  /// Stocktake message: No count can be undone. Up to the last 50 count changes are retained.
  ///
  /// In en, this message translates to:
  /// **'No count can be undone. Up to the last 50 count changes are retained.'**
  String get m53StocktakeNothingUndo;

  /// Stocktake message: Enter the total value of found stock because purchase cost is enabled.
  ///
  /// In en, this message translates to:
  /// **'Enter the total value of found stock because purchase cost is enabled.'**
  String get m53StocktakeValueRequired;

  /// Stocktake message: The physical quantity changed after valuation. Review and save the total value for the current count.
  ///
  /// In en, this message translates to:
  /// **'The physical quantity changed after valuation. Review and save the total value for the current count.'**
  String get m53StocktakeValueReview;

  /// Stocktake message: This total value applies only when system stock started at 0, every batch is counted and physical quantity is positive.
  ///
  /// In en, this message translates to:
  /// **'This total value applies only when system stock started at 0, every batch is counted and physical quantity is positive.'**
  String get m53StocktakeValueScope;

  /// Stocktake message: Review count or value
  ///
  /// In en, this message translates to:
  /// **'Review count or value'**
  String get m53StocktakeReviewLine;

  /// Supplier terms: Supplier payment terms
  ///
  /// In en, this message translates to:
  /// **'Supplier payment terms'**
  String get m53SupplierTerms;

  /// Supplier terms: Supplier allows payment on credit
  ///
  /// In en, this message translates to:
  /// **'Supplier allows payment on credit'**
  String get m53SupplierAllowsCredit;

  /// Supplier terms: This records the agreement at the store, not automatic supplier approval. It defaults to off. Turning it off only blocks new credit invoices; it does not erase existing debts or payments. Historical receipts are not automatically treated as paid or owed.
  ///
  /// In en, this message translates to:
  /// **'This records the agreement at the store, not automatic supplier approval. It defaults to off. Turning it off only blocks new credit invoices; it does not erase existing debts or payments. Historical receipts are not automatically treated as paid or owed.'**
  String get m53SupplierTermsHelp;

  /// Supplier terms: Warehouse can view these terms. Only the owner can change them.
  ///
  /// In en, this message translates to:
  /// **'Warehouse can view these terms. Only the owner can change them.'**
  String get m53SupplierTermsReadOnly;

  /// Supplier terms: Supplier terms changed. Reload and review your choice before saving.
  ///
  /// In en, this message translates to:
  /// **'Supplier terms changed. Reload and review your choice before saving.'**
  String get m53SupplierTermsChanged;

  /// Supplier terms: Supplier not found. Reload the supplier list.
  ///
  /// In en, this message translates to:
  /// **'Supplier not found. Reload the supplier list.'**
  String get m53SupplierMissing;

  /// Supplier finance: Check the invoice or payment fields.
  ///
  /// In en, this message translates to:
  /// **'Check the invoice or payment fields.'**
  String get m53SupplierInputInvalid;

  /// Supplier finance: Access changed while saving. Unlock and review the result before retrying.
  ///
  /// In en, this message translates to:
  /// **'Access changed while saving. Unlock and review the result before retrying.'**
  String get m53SupplierAccessChanged;

  /// Supplier finance: Invoice not found.
  ///
  /// In en, this message translates to:
  /// **'Invoice not found.'**
  String get m53SupplierInvoiceMissing;

  /// Supplier finance: The invoice or list changed. Reload and review before continuing.
  ///
  /// In en, this message translates to:
  /// **'The invoice or list changed. Reload and review before continuing.'**
  String get m53SupplierInvoiceChanged;

  /// Supplier finance: Receipt not found or contains no items.
  ///
  /// In en, this message translates to:
  /// **'Receipt not found or contains no items.'**
  String get m53SupplierReceiptMissing;

  /// Supplier finance: This document is not a purchase receipt eligible for invoicing.
  ///
  /// In en, this message translates to:
  /// **'This document is not a purchase receipt eligible for invoicing.'**
  String get m53SupplierReceiptNotPurchase;

  /// Supplier finance: Supplier must match the receiving document.
  ///
  /// In en, this message translates to:
  /// **'Supplier must match the receiving document.'**
  String get m53SupplierInvoiceSourceMismatch;

  /// Supplier finance: Choose a supplier on the document before creating an invoice.
  ///
  /// In en, this message translates to:
  /// **'Choose a supplier on the document before creating an invoice.'**
  String get m53SupplierInvoiceNeedsSupplier;

  /// Supplier finance: Supplier is archived. Reactivate it before creating a new invoice.
  ///
  /// In en, this message translates to:
  /// **'Supplier is archived. Reactivate it before creating a new invoice.'**
  String get m53SupplierArchived;

  /// Supplier finance: This supplier does not allow credit yet. The owner can update supplier terms.
  ///
  /// In en, this message translates to:
  /// **'This supplier does not allow credit yet. The owner can update supplier terms.'**
  String get m53SupplierCreditNotAllowed;

  /// Supplier finance: Credit requires a due date on or after the invoice date.
  ///
  /// In en, this message translates to:
  /// **'Credit requires a due date on or after the invoice date.'**
  String get m53SupplierDueInvalid;

  /// Supplier finance: Complete the costs of all receiving lines to create an invoice. The owner can separately reconcile a historical total if old costs are incomplete.
  ///
  /// In en, this message translates to:
  /// **'Complete the costs of all receiving lines to create an invoice. The owner can separately reconcile a historical total if old costs are incomplete.'**
  String get m53SupplierInvoiceCostUnknown;

  /// Supplier finance: The source total is finer than one minor currency unit. Review document costs; debt cannot be silently rounded.
  ///
  /// In en, this message translates to:
  /// **'The source total is finer than one minor currency unit. Review document costs; debt cannot be silently rounded.'**
  String get m53SupplierInvoicePrecision;

  /// Supplier finance: Amount must be positive, within the remaining balance, with matching cash details.
  ///
  /// In en, this message translates to:
  /// **'Amount must be positive, within the remaining balance, with matching cash details.'**
  String get m53SupplierPaymentInvalid;

  /// Supplier finance: This receipt already has an active invoice. Open that invoice.
  ///
  /// In en, this message translates to:
  /// **'This receipt already has an active invoice. Open that invoice.'**
  String get m53SupplierInvoiceExists;

  /// Supplier finance: Payment date cannot be in the future.
  ///
  /// In en, this message translates to:
  /// **'Payment date cannot be in the future.'**
  String get m53SupplierPaymentDateInvalid;

  /// Supplier finance: Payment not found.
  ///
  /// In en, this message translates to:
  /// **'Payment not found.'**
  String get m53SupplierPaymentMissing;

  /// Supplier finance: This payment has already been reversed.
  ///
  /// In en, this message translates to:
  /// **'This payment has already been reversed.'**
  String get m53SupplierPaymentReversed;

  /// Supplier finance: Record the cash actually returned to the drawer, with exact pieces and an active cash session.
  ///
  /// In en, this message translates to:
  /// **'Record the cash actually returned to the drawer, with exact pieces and an active cash session.'**
  String get m53SupplierCashReturnRequired;

  /// Supplier finance: Reverse effective payments or credits before voiding the invoice.
  ///
  /// In en, this message translates to:
  /// **'Reverse effective payments or credits before voiding the invoice.'**
  String get m53SupplierInvoiceDependencies;

  /// Supplier finance: The owner must void the linked invoice before reversing the receipt.
  ///
  /// In en, this message translates to:
  /// **'The owner must void the linked invoice before reversing the receipt.'**
  String get m53SupplierInvoiceBlocksReceiptReversal;

  /// Supplier finance: The archive contains inconsistent supplier invoice, payment or cash relationships.
  ///
  /// In en, this message translates to:
  /// **'The archive contains inconsistent supplier invoice, payment or cash relationships.'**
  String get backupSupplierFinanceInvalid;

  /// Supplier finance: Cash pieces paid from drawer
  ///
  /// In en, this message translates to:
  /// **'Cash pieces paid from drawer'**
  String get m53SupplierCashOut;

  /// Supplier finance: Confirm payment already made for this single invoice. The app does not execute transfers.
  ///
  /// In en, this message translates to:
  /// **'Confirm payment already made for this single invoice. The app does not execute transfers.'**
  String get m53SupplierPaymentConfirm;

  /// Supplier finance: From cash drawer
  ///
  /// In en, this message translates to:
  /// **'From cash drawer'**
  String get m53SupplierSourcedrawer;

  /// Supplier finance: Transfer / bank
  ///
  /// In en, this message translates to:
  /// **'Transfer / bank'**
  String get m53SupplierSourcebank;

  /// Supplier finance: Owner funds
  ///
  /// In en, this message translates to:
  /// **'Owner funds'**
  String get m53SupplierSourceownerFunds;

  /// Supplier finance: Record payment
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get m53SupplierPay;

  /// Supplier finance: Record an actual payment for one invoice. Transfers do not change drawer balance. When cash tracking is active, drawer payments require a session and outgoing pieces.
  ///
  /// In en, this message translates to:
  /// **'Record an actual payment for one invoice. Transfers do not change drawer balance. When cash tracking is active, drawer payments require a session and outgoing pieces.'**
  String get m53SupplierPaymentHelp;

  /// Supplier finance: Fill remaining balance
  ///
  /// In en, this message translates to:
  /// **'Fill remaining balance'**
  String get m53SupplierPayRemaining;

  /// Supplier finance: Payment date
  ///
  /// In en, this message translates to:
  /// **'Payment date'**
  String get m53SupplierPaymentDate;

  /// Supplier finance: Payment source
  ///
  /// In en, this message translates to:
  /// **'Payment source'**
  String get m53SupplierPaymentSource;

  /// Supplier finance: Payment reference (optional)
  ///
  /// In en, this message translates to:
  /// **'Payment reference (optional)'**
  String get m53SupplierPaymentReference;

  /// Supplier finance: Payment note (optional)
  ///
  /// In en, this message translates to:
  /// **'Payment note (optional)'**
  String get m53SupplierPaymentNote;

  /// Supplier finance: Initial payment confirmed by owner
  ///
  /// In en, this message translates to:
  /// **'Initial payment confirmed by owner'**
  String get m53SupplierInitialActual;

  /// Supplier finance: Save an invoice from this document? Existing stock is not received again. For a new draft, receipt and invoice are posted together.
  ///
  /// In en, this message translates to:
  /// **'Save an invoice from this document? Existing stock is not received again. For a new draft, receipt and invoice are posted together.'**
  String get m53SupplierInvoiceConfirm;

  /// Supplier finance: Create / reconcile invoice
  ///
  /// In en, this message translates to:
  /// **'Create / reconcile invoice'**
  String get m53SupplierInvoiceNew;

  /// Supplier finance: Invoicing is optional. Its value follows document costs. Cash terms alone do not prove payment; only actual payments reduce the balance.
  ///
  /// In en, this message translates to:
  /// **'Invoicing is optional. Its value follows document costs. Cash terms alone do not prove payment; only actual payments reduce the balance.'**
  String get m53SupplierInvoiceHelp;

  /// Supplier finance: The historical document has no supplier or incomplete item costs. Only the owner can confirm the supplier, financial total and reconciliation reason. This does not complete HPP or guess per-item cost allocations.
  ///
  /// In en, this message translates to:
  /// **'The historical document has no supplier or incomplete item costs. Only the owner can confirm the supplier, financial total and reconciliation reason. This does not complete HPP or guess per-item cost allocations.'**
  String get m53SupplierHistoricalHelp;

  /// Supplier finance: Invoice number (optional)
  ///
  /// In en, this message translates to:
  /// **'Invoice number (optional)'**
  String get m53SupplierInvoiceNumber;

  /// Supplier finance: Invoice date
  ///
  /// In en, this message translates to:
  /// **'Invoice date'**
  String get m53SupplierInvoiceDate;

  /// Supplier finance: Payment terms
  ///
  /// In en, this message translates to:
  /// **'Payment terms'**
  String get m53SupplierInvoiceTerms;

  /// Supplier finance: Cash / paid in full
  ///
  /// In en, this message translates to:
  /// **'Cash / paid in full'**
  String get m53SupplierTermsCash;

  /// Supplier finance: Credit / partial payment
  ///
  /// In en, this message translates to:
  /// **'Credit / partial payment'**
  String get m53SupplierTermsCredit;

  /// Supplier finance: Due date
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get m53SupplierDue;

  /// Supplier finance: Reported paid amount (optional)
  ///
  /// In en, this message translates to:
  /// **'Reported paid amount (optional)'**
  String get m53SupplierReportedInitial;

  /// Supplier finance: This reported amount is not an actual payment and does not reduce debt. The owner must separately confirm an actual payment.
  ///
  /// In en, this message translates to:
  /// **'This reported amount is not an actual payment and does not reduce debt. The owner must separately confirm an actual payment.'**
  String get m53SupplierReportedHelp;

  /// Supplier finance: Costs are shown for invoicing even when purchase prices are hidden. Tap a line to complete costs.
  ///
  /// In en, this message translates to:
  /// **'Costs are shown for invoicing even when purchase prices are hidden. Tap a line to complete costs.'**
  String get m53SupplierBillingCostsHelp;

  /// Supplier finance: Confirm receipt + invoice (optional)
  ///
  /// In en, this message translates to:
  /// **'Confirm receipt + invoice (optional)'**
  String get m53SupplierReceiveInvoice;

  /// Supplier finance: Supplier invoices
  ///
  /// In en, this message translates to:
  /// **'Supplier invoices'**
  String get m53SupplierInvoices;

  /// Supplier finance: Unreconciled receipts
  ///
  /// In en, this message translates to:
  /// **'Unreconciled receipts'**
  String get m53SupplierUnreconciled;

  /// Supplier finance: All invoices
  ///
  /// In en, this message translates to:
  /// **'All invoices'**
  String get m53SupplierFilterall;

  /// Supplier finance: Open balance
  ///
  /// In en, this message translates to:
  /// **'Open balance'**
  String get m53SupplierFilteropen;

  /// Supplier finance: Paid
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get m53SupplierFilterpaid;

  /// Supplier finance: Overdue
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get m53SupplierFilteroverdue;

  /// Supplier finance: Unpaid
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get m53SupplierStatusunpaid;

  /// Supplier finance: Partly paid
  ///
  /// In en, this message translates to:
  /// **'Partly paid'**
  String get m53SupplierStatuspartial;

  /// Supplier finance: Paid
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get m53SupplierStatuspaid;

  /// Supplier finance: Voided
  ///
  /// In en, this message translates to:
  /// **'Voided'**
  String get m53SupplierStatusvoided;

  /// Supplier finance: Next page
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get m53SupplierNext;

  /// Supplier finance: Back to first page
  ///
  /// In en, this message translates to:
  /// **'Back to first page'**
  String get m53SupplierFirst;

  /// Supplier finance: No documents match this filter.
  ///
  /// In en, this message translates to:
  /// **'No documents match this filter.'**
  String get m53SupplierEmpty;

  /// Supplier finance: Effective payments
  ///
  /// In en, this message translates to:
  /// **'Effective payments'**
  String get m53SupplierPaid;

  /// Supplier finance: Applied credit
  ///
  /// In en, this message translates to:
  /// **'Applied credit'**
  String get m53SupplierCredit;

  /// Supplier finance: Remaining balance
  ///
  /// In en, this message translates to:
  /// **'Remaining balance'**
  String get m53SupplierRemaining;

  /// Supplier finance: Due today
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get m53SupplierDueToday;

  /// Supplier finance: Not due yet
  ///
  /// In en, this message translates to:
  /// **'Not due yet'**
  String get m53SupplierNotDue;

  /// Supplier finance: Past due
  ///
  /// In en, this message translates to:
  /// **'Past due'**
  String get m53SupplierOverdue;

  /// Supplier finance: Void invoice
  ///
  /// In en, this message translates to:
  /// **'Void invoice'**
  String get m53SupplierInvoiceVoid;

  /// Supplier finance: Amend due date with reason
  ///
  /// In en, this message translates to:
  /// **'Amend due date with reason'**
  String get m53SupplierAmendDue;

  /// Supplier finance: Payment history
  ///
  /// In en, this message translates to:
  /// **'Payment history'**
  String get m53SupplierPayments;

  /// Supplier finance: Reverse payment
  ///
  /// In en, this message translates to:
  /// **'Reverse payment'**
  String get m53SupplierReversePayment;

  /// Supplier finance: Payment reversed
  ///
  /// In en, this message translates to:
  /// **'Payment reversed'**
  String get m53SupplierPaymentReversedLabel;

  /// Supplier finance: Cash pieces actually returned
  ///
  /// In en, this message translates to:
  /// **'Cash pieces actually returned'**
  String get m53SupplierCashReturned;

  /// Supplier finance: Corrections append a new trace. Enter a reason before voiding, reversing payment or changing the due date.
  ///
  /// In en, this message translates to:
  /// **'Corrections append a new trace. Enter a reason before voiding, reversing payment or changing the due date.'**
  String get m53SupplierCorrectionHelp;

  /// Supplier finance: Retry the same payment
  ///
  /// In en, this message translates to:
  /// **'Retry the same payment'**
  String get m53SupplierRetryPayment;

  /// Supplier finance: Discard pending payment input
  ///
  /// In en, this message translates to:
  /// **'Discard pending payment input'**
  String get m53SupplierCancelPendingPayment;

  /// Supplier finance: Source document items
  ///
  /// In en, this message translates to:
  /// **'Source document items'**
  String get m53SupplierItems;

  /// Supplier finance: All active invoices for this supplier, current balance; effective payments net of reversals. Unreconciled receipts are separate.
  ///
  /// In en, this message translates to:
  /// **'All active invoices for this supplier, current balance; effective payments net of reversals. Unreconciled receipts are separate.'**
  String get m53SupplierSummaryScope;

  /// Supplier finance: Gross invoiced purchases
  ///
  /// In en, this message translates to:
  /// **'Gross invoiced purchases'**
  String get m53SupplierPurchases;

  /// Supplier return: The source receipt, item or batch cannot be traced for this return. Do not guess a batch; review the source document.
  ///
  /// In en, this message translates to:
  /// **'The source receipt, item or batch cannot be traced for this return. Do not guess a batch; review the source document.'**
  String get m53ReturnSourceUnavailable;

  /// Supplier return: The historical document has no supplier. The owner must explicitly reconcile its supplier before a return can be created.
  ///
  /// In en, this message translates to:
  /// **'The historical document has no supplier. The owner must explicitly reconcile its supplier before a return can be created.'**
  String get m53ReturnSupplierRequired;

  /// Supplier return: Quantity must be positive and within the source quantity still eligible for return.
  ///
  /// In en, this message translates to:
  /// **'Quantity must be positive and within the source quantity still eligible for return.'**
  String get m53ReturnQuantityInvalid;

  /// Supplier return: The source batch has insufficient physical stock for this return.
  ///
  /// In en, this message translates to:
  /// **'The source batch has insufficient physical stock for this return.'**
  String get m53ReturnStockUnavailable;

  /// Supplier return: The return draft, document or list changed. Reload and review before continuing.
  ///
  /// In en, this message translates to:
  /// **'The return draft, document or list changed. Reload and review before continuing.'**
  String get m53ReturnChanged;

  /// Supplier return: A return document is limited to 100 lines. Create another document for additional items.
  ///
  /// In en, this message translates to:
  /// **'A return document is limited to 100 lines. Create another document for additional items.'**
  String get m53ReturnLimit;

  /// Supplier return: This source item is already in the draft. Tap its line to change the quantity.
  ///
  /// In en, this message translates to:
  /// **'This source item is already in the draft. Tap its line to change the quantity.'**
  String get m53ReturnLineExists;

  /// Supplier return: Add at least one item from the source receipt.
  ///
  /// In en, this message translates to:
  /// **'Add at least one item from the source receipt.'**
  String get m53ReturnEmpty;

  /// Supplier return: Stock or product data changed since the line was selected. Review the quantity and balance before confirming; stock is not overwritten.
  ///
  /// In en, this message translates to:
  /// **'Stock or product data changed since the line was selected. Review the quantity and balance before confirming; stock is not overwritten.'**
  String get m53ReturnConflict;

  /// Supplier return: This return document has already been reversed.
  ///
  /// In en, this message translates to:
  /// **'This return document has already been reversed.'**
  String get m53ReturnAlreadyReversed;

  /// Supplier return: This return has approved supplier credit. The owner must resolve credit reversal and its allocations first.
  ///
  /// In en, this message translates to:
  /// **'This return has approved supplier credit. The owner must resolve credit reversal and its allocations first.'**
  String get m53ReturnCreditDependency;

  /// Supplier return: Stock or batch changes occurred after this return. An exact reversal is unavailable; review the history and goods.
  ///
  /// In en, this message translates to:
  /// **'Stock or batch changes occurred after this return. An exact reversal is unavailable; review the history and goods.'**
  String get m53ReturnReversalDependency;

  /// Supplier return: This receipt has an active physical return. Resolve a valid return reversal before reversing the receipt.
  ///
  /// In en, this message translates to:
  /// **'This receipt has an active physical return. Resolve a valid return reversal before reversing the receipt.'**
  String get m53ReturnBlocksReceiptReversal;

  /// Supplier return: The archive contains inconsistent supplier return sources, batches, values or event order.
  ///
  /// In en, this message translates to:
  /// **'The archive contains inconsistent supplier return sources, batches, values or event order.'**
  String get backupSupplierReturnsInvalid;

  /// Supplier return: Return to supplier
  ///
  /// In en, this message translates to:
  /// **'Return to supplier'**
  String get m53SupplierReturn;

  /// Supplier return: Supplier returns
  ///
  /// In en, this message translates to:
  /// **'Supplier returns'**
  String get m53SupplierReturns;

  /// Supplier return: Return quantity (base units)
  ///
  /// In en, this message translates to:
  /// **'Return quantity (base units)'**
  String get m53ReturnQuantity;

  /// Supplier return: Confirm the entire return document? Source batch stock will be removed at its current average inventory value. This return is not yet approved credit or incoming money.
  ///
  /// In en, this message translates to:
  /// **'Confirm the entire return document? Source batch stock will be removed at its current average inventory value. This return is not yet approved credit or incoming money.'**
  String get m53ReturnConfirmHelp;

  /// Supplier return: Reverse this entire return with the entered reason? This requires no dependent stock changes or credit. History is retained and customer sales are not cancelled.
  ///
  /// In en, this message translates to:
  /// **'Reverse this entire return with the entered reason? This requires no dependent stock changes or credit. History is retained and customer sales are not cancelled.'**
  String get m53ReturnUndoHelp;

  /// Supplier return: Physical returns and supplier credit approval are separate events. Returning goods does not automatically reduce debt or add drawer cash.
  ///
  /// In en, this message translates to:
  /// **'Physical returns and supplier credit approval are separate events. Returning goods does not automatically reduce debt or add drawer cash.'**
  String get m53ReturnNoAutomaticCredit;

  /// Supplier return: Return draft — stock unchanged
  ///
  /// In en, this message translates to:
  /// **'Return draft — stock unchanged'**
  String get m53ReturnStatusdraft;

  /// Supplier return: Return posted
  ///
  /// In en, this message translates to:
  /// **'Return posted'**
  String get m53ReturnStatusposted;

  /// Supplier return: Return draft cancelled
  ///
  /// In en, this message translates to:
  /// **'Return draft cancelled'**
  String get m53ReturnStatuscancelled;

  /// Supplier return: Untracked: physical balance not validated
  ///
  /// In en, this message translates to:
  /// **'Untracked: physical balance not validated'**
  String get m53ReturnUntrackedHelp;

  /// Supplier return: Save reason to draft
  ///
  /// In en, this message translates to:
  /// **'Save reason to draft'**
  String get m53ReturnSaveReason;

  /// Supplier return: Confirm physical return
  ///
  /// In en, this message translates to:
  /// **'Confirm physical return'**
  String get m53ReturnConfirm;

  /// Supplier return: Review draft balances and quantities
  ///
  /// In en, this message translates to:
  /// **'Review draft balances and quantities'**
  String get m53ReturnReview;

  /// Supplier return: Cancel return draft
  ///
  /// In en, this message translates to:
  /// **'Cancel return draft'**
  String get m53ReturnCancel;

  /// Supplier return: Cancel this draft? Stock is unchanged and the draft remains recorded as cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancel this draft? Stock is unchanged and the draft remains recorded as cancelled.'**
  String get m53ReturnCancelHelp;

  /// Supplier return: Choose items from the source receipt
  ///
  /// In en, this message translates to:
  /// **'Choose items from the source receipt'**
  String get m53ReturnSourceItems;

  /// Supplier return: Still eligible for return
  ///
  /// In en, this message translates to:
  /// **'Still eligible for return'**
  String get m53ReturnEligible;

  /// Supplier return: Available in source batch
  ///
  /// In en, this message translates to:
  /// **'Available in source batch'**
  String get m53ReturnPhysicalAvailable;

  /// Supplier return: Return reversed
  ///
  /// In en, this message translates to:
  /// **'Return reversed'**
  String get m53ReturnReversed;

  /// Supplier return: Physical return recorded; credit value not approved
  ///
  /// In en, this message translates to:
  /// **'Physical return recorded; credit value not approved'**
  String get m53ReturnPendingCredit;

  /// Supplier return: Inventory value removed
  ///
  /// In en, this message translates to:
  /// **'Inventory value removed'**
  String get m53ReturnInventoryValue;

  /// Supplier return: Reverse return with reason
  ///
  /// In en, this message translates to:
  /// **'Reverse return with reason'**
  String get m53ReturnUndo;

  /// Supplier return: Return drafts
  ///
  /// In en, this message translates to:
  /// **'Return drafts'**
  String get m53ReturnListdrafts;

  /// Supplier return: Return history
  ///
  /// In en, this message translates to:
  /// **'Return history'**
  String get m53ReturnListposted;

  /// Supplier return: Source receipts
  ///
  /// In en, this message translates to:
  /// **'Source receipts'**
  String get m53ReturnListreceipts;

  /// Supplier return: Create a draft from this receipt
  ///
  /// In en, this message translates to:
  /// **'Create a draft from this receipt'**
  String get m53ReturnChooseReceipt;

  /// Supplier credit: Supplier credit not found.
  ///
  /// In en, this message translates to:
  /// **'Supplier credit not found.'**
  String get m53CreditMissing;

  /// Supplier credit: The credit balance or history changed. Reload and review before continuing.
  ///
  /// In en, this message translates to:
  /// **'The credit balance or history changed. Reload and review before continuing.'**
  String get m53CreditChanged;

  /// Supplier credit: The physical return is unavailable or reversed. New credit cannot be approved.
  ///
  /// In en, this message translates to:
  /// **'The physical return is unavailable or reversed. New credit cannot be approved.'**
  String get m53CreditReturnUnavailable;

  /// Supplier credit: This return already has approved credit. Open that credit.
  ///
  /// In en, this message translates to:
  /// **'This return already has approved credit. Open that credit.'**
  String get m53CreditAlreadyApproved;

  /// Supplier credit: Check the date. It cannot be in the future or before the approval or original reversed event.
  ///
  /// In en, this message translates to:
  /// **'Check the date. It cannot be in the future or before the approval or original reversed event.'**
  String get m53CreditDateInvalid;

  /// Supplier credit: Amount must be positive and within both available credit and the target invoice balance.
  ///
  /// In en, this message translates to:
  /// **'Amount must be positive and within both available credit and the target invoice balance.'**
  String get m53CreditAmountInvalid;

  /// Supplier credit: Choose an active invoice for the same supplier and currency.
  ///
  /// In en, this message translates to:
  /// **'Choose an active invoice for the same supplier and currency.'**
  String get m53CreditTargetInvalid;

  /// Supplier credit: Credit allocation not found.
  ///
  /// In en, this message translates to:
  /// **'Credit allocation not found.'**
  String get m53CreditAllocationMissing;

  /// Supplier credit: Credit allocation reversed.
  ///
  /// In en, this message translates to:
  /// **'Credit allocation reversed.'**
  String get m53CreditAllocationReversed;

  /// Supplier credit: Reverse effective allocations and refunds before reversing credit approval.
  ///
  /// In en, this message translates to:
  /// **'Reverse effective allocations and refunds before reversing credit approval.'**
  String get m53CreditDependencies;

  /// Supplier credit: Supplier refund not found.
  ///
  /// In en, this message translates to:
  /// **'Supplier refund not found.'**
  String get m53CreditRefundMissing;

  /// Supplier credit: This refund has already been reversed.
  ///
  /// In en, this message translates to:
  /// **'This refund has already been reversed.'**
  String get m53CreditRefundReversed;

  /// Supplier credit: Enter the cash pieces actually sent back to the supplier from an active drawer session.
  ///
  /// In en, this message translates to:
  /// **'Enter the cash pieces actually sent back to the supplier from an active drawer session.'**
  String get m53CreditCashOutRequired;

  /// Supplier credit: The archive contains inconsistent supplier credit approvals, allocations, refunds or balances.
  ///
  /// In en, this message translates to:
  /// **'The archive contains inconsistent supplier credit approvals, allocations, refunds or balances.'**
  String get backupSupplierCreditInvalid;

  /// Supplier credit: Approve supplier credit value
  ///
  /// In en, this message translates to:
  /// **'Approve supplier credit value'**
  String get m53CreditApprove;

  /// Supplier credit: Confirm the value actually approved by the supplier? This is separate from inventory removed. Allocation to the original invoice is posted together, without automatically receiving money.
  ///
  /// In en, this message translates to:
  /// **'Confirm the value actually approved by the supplier? This is separate from inventory removed. Allocation to the original invoice is posted together, without automatically receiving money.'**
  String get m53CreditApproveConfirm;

  /// Supplier credit: Applied to original invoice now
  ///
  /// In en, this message translates to:
  /// **'Applied to original invoice now'**
  String get m53CreditAppliedNow;

  /// Supplier credit: Unallocated credit
  ///
  /// In en, this message translates to:
  /// **'Unallocated credit'**
  String get m53CreditAvailable;

  /// Supplier credit: Enter a value and reason based on supplier approval, not an estimated goods price. It may differ from inventory removed. Allocation is capped by the original invoice balance; excess stays unallocated.
  ///
  /// In en, this message translates to:
  /// **'Enter a value and reason based on supplier approval, not an estimated goods price. It may differ from inventory removed. Allocation is capped by the original invoice balance; excess stays unallocated.'**
  String get m53CreditApprovalHelp;

  /// Supplier credit: No active original invoice exists. Approved credit is kept separately for later allocation or refund.
  ///
  /// In en, this message translates to:
  /// **'No active original invoice exists. Approved credit is kept separately for later allocation or refund.'**
  String get m53CreditNoInvoice;

  /// Supplier credit: Approved credit value
  ///
  /// In en, this message translates to:
  /// **'Approved credit value'**
  String get m53CreditApprovedValue;

  /// Supplier credit: Supplier approval date
  ///
  /// In en, this message translates to:
  /// **'Supplier approval date'**
  String get m53CreditApprovalDate;

  /// Supplier credit: Reason / supplier agreement evidence
  ///
  /// In en, this message translates to:
  /// **'Reason / supplier agreement evidence'**
  String get m53CreditAgreementReason;

  /// Supplier credit: Supplier credits and refunds
  ///
  /// In en, this message translates to:
  /// **'Supplier credits and refunds'**
  String get m53SupplierCredits;

  /// Supplier credit: Record refund received
  ///
  /// In en, this message translates to:
  /// **'Record refund received'**
  String get m53CreditRefund;

  /// Supplier credit: Apply to one invoice
  ///
  /// In en, this message translates to:
  /// **'Apply to one invoice'**
  String get m53CreditAllocate;

  /// Supplier credit: Refund cash pieces received in drawer
  ///
  /// In en, this message translates to:
  /// **'Refund cash pieces received in drawer'**
  String get m53CreditCashReceived;

  /// Supplier credit: Record refund money already received from the supplier? This uses available credit, not a new supplier payment or an automatic transfer.
  ///
  /// In en, this message translates to:
  /// **'Record refund money already received from the supplier? This uses available credit, not a new supplier payment or an automatic transfer.'**
  String get m53CreditRefundConfirm;

  /// Supplier credit: Apply credit to the selected single invoice? No money or stock is moved.
  ///
  /// In en, this message translates to:
  /// **'Apply credit to the selected single invoice? No money or stock is moved.'**
  String get m53CreditAllocateConfirm;

  /// Supplier credit: Record only money actually received from the supplier. Refunded credit cannot also be allocated to invoices. Bank transfers do not change drawer balance.
  ///
  /// In en, this message translates to:
  /// **'Record only money actually received from the supplier. Refunded credit cannot also be allocated to invoices. Bank transfers do not change drawer balance.'**
  String get m53CreditRefundHelp;

  /// Supplier credit: One allocation targets one invoice for the same supplier. Both balances are rechecked at confirmation. This allocation does not pay drawer cash.
  ///
  /// In en, this message translates to:
  /// **'One allocation targets one invoice for the same supplier. Both balances are rechecked at confirmation. This allocation does not pay drawer cash.'**
  String get m53CreditAllocateHelp;

  /// Supplier credit: Refund amount received
  ///
  /// In en, this message translates to:
  /// **'Refund amount received'**
  String get m53CreditRefundAmount;

  /// Supplier credit: Credit amount applied
  ///
  /// In en, this message translates to:
  /// **'Credit amount applied'**
  String get m53CreditAllocationAmount;

  /// Supplier credit: Fill available maximum
  ///
  /// In en, this message translates to:
  /// **'Fill available maximum'**
  String get m53CreditFillMaximum;

  /// Supplier credit: Refund receipt date
  ///
  /// In en, this message translates to:
  /// **'Refund receipt date'**
  String get m53CreditRefundDate;

  /// Supplier credit: Credit allocation date
  ///
  /// In en, this message translates to:
  /// **'Credit allocation date'**
  String get m53CreditAllocationDate;

  /// Supplier credit: Destination of received money
  ///
  /// In en, this message translates to:
  /// **'Destination of received money'**
  String get m53CreditRefundDestination;

  /// Supplier credit: Into cash drawer
  ///
  /// In en, this message translates to:
  /// **'Into cash drawer'**
  String get m53CreditDestinationdrawer;

  /// Supplier credit: Received through bank
  ///
  /// In en, this message translates to:
  /// **'Received through bank'**
  String get m53CreditDestinationbank;

  /// Supplier credit: Received by owner outside drawer
  ///
  /// In en, this message translates to:
  /// **'Received by owner outside drawer'**
  String get m53CreditDestinationownerFunds;

  /// Supplier credit: Drawer tracking is off. The refund amount is recorded, but no drawer pieces or balance are created. Open cash settings to track pieces and a drawer session.
  ///
  /// In en, this message translates to:
  /// **'Drawer tracking is off. The refund amount is recorded, but no drawer pieces or balance are created. Open cash settings to track pieces and a drawer session.'**
  String get m53CreditDrawerOff;

  /// Supplier credit: All effective credits for this supplier, current balance, separated by currency. Reversed approvals remain in the list history.
  ///
  /// In en, this message translates to:
  /// **'All effective credits for this supplier, current balance, separated by currency. Reversed approvals remain in the list history.'**
  String get m53CreditSummaryScope;

  /// Supplier credit: Total effective approved credit
  ///
  /// In en, this message translates to:
  /// **'Total effective approved credit'**
  String get m53CreditSummaryapproved;

  /// Supplier credit: Effective credit applied
  ///
  /// In en, this message translates to:
  /// **'Effective credit applied'**
  String get m53CreditSummaryallocated;

  /// Supplier credit: Effective refunds received
  ///
  /// In en, this message translates to:
  /// **'Effective refunds received'**
  String get m53CreditSummaryrefunded;

  /// Supplier credit: Unallocated credit
  ///
  /// In en, this message translates to:
  /// **'Unallocated credit'**
  String get m53CreditSummaryavailable;

  /// Supplier credit: Credit approval reversed
  ///
  /// In en, this message translates to:
  /// **'Credit approval reversed'**
  String get m53CreditReversed;

  /// Supplier credit: Choose one target invoice
  ///
  /// In en, this message translates to:
  /// **'Choose one target invoice'**
  String get m53CreditChooseInvoice;

  /// Supplier credit: Reverse credit allocation
  ///
  /// In en, this message translates to:
  /// **'Reverse credit allocation'**
  String get m53CreditReverseAllocation;

  /// Supplier credit: Cash pieces sent back to supplier
  ///
  /// In en, this message translates to:
  /// **'Cash pieces sent back to supplier'**
  String get m53CreditCashSentBack;

  /// Supplier credit: Reverse received refund
  ///
  /// In en, this message translates to:
  /// **'Reverse received refund'**
  String get m53CreditReverseRefund;

  /// Supplier credit: Reverse credit approval
  ///
  /// In en, this message translates to:
  /// **'Reverse credit approval'**
  String get m53CreditReverse;

  /// Supplier credit: Credit allocation history
  ///
  /// In en, this message translates to:
  /// **'Credit allocation history'**
  String get m53CreditAllocations;

  /// Supplier credit: Supplier refund history
  ///
  /// In en, this message translates to:
  /// **'Supplier refund history'**
  String get m53CreditRefunds;

  /// Supplier credit: Refund reversed
  ///
  /// In en, this message translates to:
  /// **'Refund reversed'**
  String get m53CreditRefundReversedLabel;

  /// Supplier credit: Credit value approved; review its allocations and balance
  ///
  /// In en, this message translates to:
  /// **'Credit value approved; review its allocations and balance'**
  String get m53CreditApprovedStatus;

  /// Supplier schedules: Visit plan not found.
  ///
  /// In en, this message translates to:
  /// **'Visit plan not found.'**
  String get m53VisitMissing;

  /// Supplier schedules: Check the visit time and note (up to 1,000 characters).
  ///
  /// In en, this message translates to:
  /// **'Check the visit time and note (up to 1,000 characters).'**
  String get m53VisitInputInvalid;

  /// Supplier schedules: The plan or reminder preference changed. Reload before continuing.
  ///
  /// In en, this message translates to:
  /// **'The plan or reminder preference changed. Reload before continuing.'**
  String get m53VisitChanged;

  /// Supplier schedules: The archive contains inconsistent supplier plans or reminder preferences.
  ///
  /// In en, this message translates to:
  /// **'The archive contains inconsistent supplier plans or reminder preferences.'**
  String get backupSupplierScheduleInvalid;

  /// Supplier schedules: Reminders are unavailable. Plans and invoices remain saved; check notification permission and battery restrictions.
  ///
  /// In en, this message translates to:
  /// **'Reminders are unavailable. Plans and invoices remain saved; check notification permission and battery restrictions.'**
  String get m53ReminderUnavailable;

  /// Supplier schedules: Supplier plans and reminders
  ///
  /// In en, this message translates to:
  /// **'Supplier plans and reminders'**
  String get m53SupplierSchedules;

  /// Supplier schedules: H-1 reminders at 09:00 shop time depend on Android permission and restrictions and may be delayed. Past H-1 targets are not sent as catch-up alerts. General notifications can be enabled in Reminder settings.
  ///
  /// In en, this message translates to:
  /// **'H-1 reminders at 09:00 shop time depend on Android permission and restrictions and may be delayed. Past H-1 targets are not sent as catch-up alerts. General notifications can be enabled in Reminder settings.'**
  String get m53SupplierReminderHelp;

  /// Supplier schedules: Reminder settings
  ///
  /// In en, this message translates to:
  /// **'Reminder settings'**
  String get m53ReminderPermissionSettings;

  /// Supplier schedules: Invoices with due dates
  ///
  /// In en, this message translates to:
  /// **'Invoices with due dates'**
  String get m53DueReminderList;

  /// Supplier schedules: Add visit plan
  ///
  /// In en, this message translates to:
  /// **'Add visit plan'**
  String get m53VisitAdd;

  /// Supplier schedules: Visit status
  ///
  /// In en, this message translates to:
  /// **'Visit status'**
  String get m53VisitFilter;

  /// Supplier schedules: Planned
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get m53VisitStatusplanned;

  /// Supplier schedules: Completed
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get m53VisitStatuscompleted;

  /// Supplier schedules: Cancelled
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get m53VisitStatuscancelled;

  /// Supplier schedules: All statuses
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get m53VisitStatusall;

  /// Supplier schedules: No visit plans match this selection.
  ///
  /// In en, this message translates to:
  /// **'No visit plans match this selection.'**
  String get m53VisitEmpty;

  /// Supplier schedules: Needs attention: the H-1 target has passed. Review the visit date and status.
  ///
  /// In en, this message translates to:
  /// **'Needs attention: the H-1 target has passed. Review the visit date and status.'**
  String get m53VisitAttention;

  /// Supplier schedules: Review visit plan
  ///
  /// In en, this message translates to:
  /// **'Review visit plan'**
  String get m53VisitReview;

  /// Supplier schedules: A visit plan does not create a receipt, invoice or payment. This date is separate from invoice due dates.
  ///
  /// In en, this message translates to:
  /// **'A visit plan does not create a receipt, invoice or payment. This date is separate from invoice due dates.'**
  String get m53VisitNoPosting;

  /// Supplier schedules: Visit date
  ///
  /// In en, this message translates to:
  /// **'Visit date'**
  String get m53VisitDate;

  /// Supplier schedules: Visit time (optional)
  ///
  /// In en, this message translates to:
  /// **'Visit time (optional)'**
  String get m53VisitTime;

  /// Supplier schedules: No specific time
  ///
  /// In en, this message translates to:
  /// **'No specific time'**
  String get m53VisitNoTime;

  /// Supplier schedules: Clear visit time
  ///
  /// In en, this message translates to:
  /// **'Clear visit time'**
  String get m53VisitClearTime;

  /// Supplier schedules: Remind me H-1 before the visit
  ///
  /// In en, this message translates to:
  /// **'Remind me H-1 before the visit'**
  String get m53VisitReminder;

  /// Supplier schedules: Visit note (optional)
  ///
  /// In en, this message translates to:
  /// **'Visit note (optional)'**
  String get m53VisitNote;

  /// Supplier schedules: These invoices still have a balance. Invoices due today or overdue need attention even if a reminder was not shown. Partial payment keeps the reminder; full settlement cancels it.
  ///
  /// In en, this message translates to:
  /// **'These invoices still have a balance. Invoices due today or overdue need attention even if a reminder was not shown. Partial payment keeps the reminder; full settlement cancels it.'**
  String get m53DueAttentionHelp;

  /// Supplier schedules: No invoices with due dates have an outstanding balance.
  ///
  /// In en, this message translates to:
  /// **'No invoices with due dates have an outstanding balance.'**
  String get m53DueReminderEmpty;

  /// Supplier schedules: Remind me H-1 before payment is due
  ///
  /// In en, this message translates to:
  /// **'Remind me H-1 before payment is due'**
  String get m53DueReminder;

  /// Supplier schedules: Supplier payment due tomorrow
  ///
  /// In en, this message translates to:
  /// **'Supplier payment due tomorrow'**
  String get m53ReminderDueTitle;

  /// Supplier schedules: Supplier visit tomorrow
  ///
  /// In en, this message translates to:
  /// **'Supplier visit tomorrow'**
  String get m53ReminderVisitTitle;

  /// Supplier schedules: {supplier} · Open with management access.
  ///
  /// In en, this message translates to:
  /// **'{supplier} · Open with management access.'**
  String m53ReminderPrivateBody(String supplier);

  /// Supplier schedules: Next planned visit date
  ///
  /// In en, this message translates to:
  /// **'Next planned visit date'**
  String get m53VisitNextDate;

  /// Supplier schedules: No plans for today or a later date
  ///
  /// In en, this message translates to:
  /// **'No plans for today or a later date'**
  String get m53VisitNoFuture;

  /// M5.3 product QR labels. English meaning: Product QR labels
  ///
  /// In en, this message translates to:
  /// **'Product QR labels'**
  String get m53Labels;

  /// M5.3 product QR labels. English meaning: QR contains a stable SkyBee product identity even after its name, SKU or price changes. Existing barcodes still work. Physical scanners must support QR (2D).
  ///
  /// In en, this message translates to:
  /// **'QR contains a stable SkyBee product identity even after its name, SKU or price changes. Existing barcodes still work. Physical scanners must support QR (2D).'**
  String get m53LabelHelp;

  /// M5.3 product QR labels. English meaning: Connect or configure printer
  ///
  /// In en, this message translates to:
  /// **'Connect or configure printer'**
  String get m53LabelPrinterSettings;

  /// M5.3 product QR labels. English meaning: Label printer
  ///
  /// In en, this message translates to:
  /// **'Label printer'**
  String get m53LabelPrinter;

  /// M5.3 product QR labels. English meaning: Command language supported by the printer
  ///
  /// In en, this message translates to:
  /// **'Command language supported by the printer'**
  String get m53LabelProtocol;

  /// M5.3 product QR labels. English meaning: Label width (mm)
  ///
  /// In en, this message translates to:
  /// **'Label width (mm)'**
  String get m53LabelwidthMm;

  /// M5.3 product QR labels. English meaning: Label height (mm)
  ///
  /// In en, this message translates to:
  /// **'Label height (mm)'**
  String get m53LabelheightMm;

  /// M5.3 product QR labels. English meaning: Inter-label gap (mm)
  ///
  /// In en, this message translates to:
  /// **'Inter-label gap (mm)'**
  String get m53LabelgapMm;

  /// M5.3 product QR labels. English meaning: Right offset (mm)
  ///
  /// In en, this message translates to:
  /// **'Right offset (mm)'**
  String get m53LabeloffsetXmm;

  /// M5.3 product QR labels. English meaning: Down offset (mm)
  ///
  /// In en, this message translates to:
  /// **'Down offset (mm)'**
  String get m53LabeloffsetYmm;

  /// M5.3 product QR labels. English meaning: QR module size (4–12 printer dots)
  ///
  /// In en, this message translates to:
  /// **'QR module size (4–12 printer dots)'**
  String get m53LabelmoduleDots;

  /// M5.3 product QR labels. English meaning: Trailing feed for continuous paper (0–8 lines)
  ///
  /// In en, this message translates to:
  /// **'Trailing feed for continuous paper (0–8 lines)'**
  String get m53Labelfeed;

  /// M5.3 product QR labels. English meaning: Label copies (1–100)
  ///
  /// In en, this message translates to:
  /// **'Label copies (1–100)'**
  String get m53Labelcopies;

  /// M5.3 product QR labels. English meaning: Show current retail price
  ///
  /// In en, this message translates to:
  /// **'Show current retail price'**
  String get m53LabelPrice;

  /// M5.3 product QR labels. English meaning: Use gap label media (TSPL)
  ///
  /// In en, this message translates to:
  /// **'Use gap label media (TSPL)'**
  String get m53LabelGap;

  /// M5.3 product QR labels. English meaning: I have confirmed the printer supports TSPL and this media size/gap.
  ///
  /// In en, this message translates to:
  /// **'I have confirmed the printer supports TSPL and this media size/gap.'**
  String get m53LabelGapAck;

  /// M5.3 product QR labels. English meaning: Label settings are separate from receipts. QR uses a four-module white margin and integer modules of at least four dots. Media that is too small is rejected. Test one label first; physical dimensions depend on the printer specifications. No automatic calibration is performed.
  ///
  /// In en, this message translates to:
  /// **'Label settings are separate from receipts. QR uses a four-module white margin and integer modules of at least four dots. Media that is too small is rejected. Test one label first; physical dimensions depend on the printer specifications. No automatic calibration is performed.'**
  String get m53LabelMediaHelp;

  /// M5.3 product QR labels. English meaning: Save label settings
  ///
  /// In en, this message translates to:
  /// **'Save label settings'**
  String get m53LabelSaveProfile;

  /// M5.3 product QR labels. English meaning: Preview label
  ///
  /// In en, this message translates to:
  /// **'Preview label'**
  String get m53LabelPreview;

  /// M5.3 product QR labels. English meaning: Media including feed/gap
  ///
  /// In en, this message translates to:
  /// **'Media including feed/gap'**
  String get m53LabelTotalMedia;

  /// M5.3 product QR labels. English meaning: Send labels to printer
  ///
  /// In en, this message translates to:
  /// **'Send labels to printer'**
  String get m53LabelPrint;

  /// M5.3 product QR labels. English meaning: Sent data does not prove a label printed. Check the paper and scan the QR. A new job may produce additional labels, especially when the previous delivery is unknown.
  ///
  /// In en, this message translates to:
  /// **'Sent data does not prove a label printed. Check the paper and scan the QR. A new job may produce additional labels, especially when the previous delivery is unknown.'**
  String get m53LabelPaperWarning;

  /// M5.3 product QR labels. English meaning: Create a new label job
  ///
  /// In en, this message translates to:
  /// **'Create a new label job'**
  String get m53LabelNewJob;

  /// M5.3 product QR labels. English meaning: Select and save a printer first.
  ///
  /// In en, this message translates to:
  /// **'Select and save a printer first.'**
  String get m53LabelPrinterMissing;

  /// M5.3 product QR labels. English meaning: Label settings changed. Reopen this screen to load the current version.
  ///
  /// In en, this message translates to:
  /// **'Label settings changed. Reopen this screen to load the current version.'**
  String get m53LabelProfileChanged;

  /// M5.3 product QR labels. English meaning: Product details changed. Review a fresh preview before printing.
  ///
  /// In en, this message translates to:
  /// **'Product details changed. Review a fresh preview before printing.'**
  String get m53LabelProductChanged;

  /// M5.3 product QR labels. English meaning: Label copies must be between 1 and 100.
  ///
  /// In en, this message translates to:
  /// **'Label copies must be between 1 and 100.'**
  String get m53LabelCopiesInvalid;

  /// M5.3 product QR labels. English meaning: Label size, offsets, QR module size or feed are invalid.
  ///
  /// In en, this message translates to:
  /// **'Label size, offsets, QR module size or feed are invalid.'**
  String get m53LabelProfileInvalid;

  /// M5.3 product QR labels. English meaning: Gap labels require TSPL and confirmation of printer support.
  ///
  /// In en, this message translates to:
  /// **'Gap labels require TSPL and confirmation of printer support.'**
  String get m53LabelGapUnsupported;

  /// M5.3 product QR labels. English meaning: Label width exceeds the selected printer’s printable area.
  ///
  /// In en, this message translates to:
  /// **'Label width exceeds the selected printer’s printable area.'**
  String get m53LabelWidthExceeded;

  /// M5.3 product QR labels. English meaning: The label content does not fit. Increase media size or reduce offsets/optional price. QR modules are never automatically shrunk.
  ///
  /// In en, this message translates to:
  /// **'The label content does not fit. Increase media size or reduce offsets/optional price. QR modules are never automatically shrunk.'**
  String get m53LabelDoesNotFit;

  /// M5.3 product QR labels. English meaning: The label snapshot is invalid. Create a new job from valid product details.
  ///
  /// In en, this message translates to:
  /// **'The label snapshot is invalid. Create a new job from valid product details.'**
  String get m53LabelSnapshotInvalid;

  /// M5.3 product QR labels. English meaning: The backup contains invalid label settings.
  ///
  /// In en, this message translates to:
  /// **'The backup contains invalid label settings.'**
  String get backupLabelProfileInvalid;

  /// M5.3 product QR labels. English meaning: Continue the same label job
  ///
  /// In en, this message translates to:
  /// **'Continue the same label job'**
  String get m53LabelResume;

  /// M5.3 product QR labels. English meaning: TSPL (continuous or confirmed gap media)
  ///
  /// In en, this message translates to:
  /// **'TSPL (continuous or confirmed gap media)'**
  String get m53LabelTspl;

  /// M5.3 product QR labels. English meaning: This product identity is not supported for QR labels. Product data was not changed.
  ///
  /// In en, this message translates to:
  /// **'This product identity is not supported for QR labels. Product data was not changed.'**
  String get m53LabelIdentityInvalid;

  /// M5.3 receipt policy. English meaning: Receipt policy
  ///
  /// In en, this message translates to:
  /// **'Receipt policy'**
  String get m53ReceiptPolicy;

  /// M5.3 receipt policy. English meaning: Require a receipt before the next sale
  ///
  /// In en, this message translates to:
  /// **'Require a receipt before the next sale'**
  String get m53ReceiptPolicyRequired;

  /// M5.3 receipt policy. English meaning: Off by default. When enabled as a sale is saved, the cashier remains on its receipt until paper output is confirmed or the owner approves a single-sale exception. Stock, debt and money are committed once even if the printer fails. Disabling the policy affects future sales; existing obligations still need resolution.
  ///
  /// In en, this message translates to:
  /// **'Off by default. When enabled as a sale is saved, the cashier remains on its receipt until paper output is confirmed or the owner approves a single-sale exception. Stock, debt and money are committed once even if the printer fails. Disabling the policy affects future sales; existing obligations still need resolution.'**
  String get m53ReceiptPolicyHelp;

  /// M5.3 receipt policy. English meaning: This sale’s receipt is still required. Inspect and confirm the paper, explicitly print a copy, or request an owner exception before the next basket.
  ///
  /// In en, this message translates to:
  /// **'This sale’s receipt is still required. Inspect and confirm the paper, explicitly print a copy, or request an owner exception before the next basket.'**
  String get m53ReceiptRequiredPending;

  /// M5.3 receipt policy. English meaning: The receipt policy requires a database upgrade.
  ///
  /// In en, this message translates to:
  /// **'The receipt policy requires a database upgrade.'**
  String get m53ReceiptPolicyUnavailable;

  /// M5.3 receipt policy. English meaning: The receipt policy changed. Reload settings before saving.
  ///
  /// In en, this message translates to:
  /// **'The receipt policy changed. Reload settings before saving.'**
  String get m53ReceiptPolicyChanged;

  /// M5.3 receipt policy. English meaning: This sale is no longer waiting for receipt fulfillment. Reload the receipt.
  ///
  /// In en, this message translates to:
  /// **'This sale is no longer waiting for receipt fulfillment. Reload the receipt.'**
  String get m53ReceiptNotPending;

  /// M5.3 receipt policy. English meaning: This job cannot confirm the receipt. Use a receipt delivery for the same sale; label, calibration and failed deliveries do not qualify.
  ///
  /// In en, this message translates to:
  /// **'This job cannot confirm the receipt. Use a receipt delivery for the same sale; label, calibration and failed deliveries do not qualify.'**
  String get m53ReceiptConfirmationUnavailable;

  /// M5.3 receipt policy. English meaning: Has the receipt printed?
  ///
  /// In en, this message translates to:
  /// **'Has the receipt printed?'**
  String get m53ReceiptPaperQuestion;

  /// M5.3 receipt policy. English meaning: Inspect this sale’s paper receipt yourself. Successful writes, ACK or sent status do not prove paper delivery. This confirmation is an operator statement, not automatic physical verification by the printer.
  ///
  /// In en, this message translates to:
  /// **'Inspect this sale’s paper receipt yourself. Successful writes, ACK or sent status do not prove paper delivery. This confirmation is an operator statement, not automatic physical verification by the printer.'**
  String get m53ReceiptPaperInspect;

  /// M5.3 receipt policy. English meaning: Yes, I inspected the paper receipt
  ///
  /// In en, this message translates to:
  /// **'Yes, I inspected the paper receipt'**
  String get m53ReceiptPaperYes;

  /// M5.3 receipt policy. English meaning: Unknown delivery never retries automatically. Confirm only after paper actually comes out, including from an earlier attempt. If the printer is broken or out of paper, the owner may approve a single-sale exception with a reason.
  ///
  /// In en, this message translates to:
  /// **'Unknown delivery never retries automatically. Confirm only after paper actually comes out, including from an earlier attempt. If the printer is broken or out of paper, the owner may approve a single-sale exception with a reason.'**
  String get m53ReceiptPaperHelp;

  /// M5.3 receipt policy. English meaning: The operator confirmed the receipt after inspecting the paper.
  ///
  /// In en, this message translates to:
  /// **'The operator confirmed the receipt after inspecting the paper.'**
  String get m53ReceiptOperatorConfirmed;

  /// M5.3 receipt policy. English meaning: The owner approved a receipt exception for this sale only.
  ///
  /// In en, this message translates to:
  /// **'The owner approved a receipt exception for this sale only.'**
  String get m53ReceiptOwnerExcepted;

  /// M5.3 receipt policy. English meaning: Request a single-sale receipt exception
  ///
  /// In en, this message translates to:
  /// **'Request a single-sale receipt exception'**
  String get m53ReceiptException;

  /// M5.3 receipt policy. English meaning: The sale is already saved. This exception does not cancel, charge again or change stock/debt/money. Enter a reason, then ask the owner to authenticate again to approve this sale only. The reason and approval are recorded; the owner session is locked again after the action.
  ///
  /// In en, this message translates to:
  /// **'The sale is already saved. This exception does not cancel, charge again or change stock/debt/money. Enter a reason, then ask the owner to authenticate again to approve this sale only. The reason and approval are recorded; the owner session is locked again after the action.'**
  String get m53ReceiptExceptionHelp;

  /// M5.3 receipt policy. English meaning: Exception reason
  ///
  /// In en, this message translates to:
  /// **'Exception reason'**
  String get m53ReceiptExceptionReason;

  /// M5.3 receipt policy. English meaning: Enter an exception reason, up to 1000 characters.
  ///
  /// In en, this message translates to:
  /// **'Enter an exception reason, up to 1000 characters.'**
  String get m53ReceiptExceptionReasonRequired;

  /// M5.3 receipt policy. English meaning: Authenticate the owner and approve once
  ///
  /// In en, this message translates to:
  /// **'Authenticate the owner and approve once'**
  String get m53ReceiptExceptionAuthenticate;

  /// M5.3 receipt policy. English meaning: The backup contains invalid receipt policy, obligation or confirmation records.
  ///
  /// In en, this message translates to:
  /// **'The backup contains invalid receipt policy, obligation or confirmation records.'**
  String get backupReceiptPolicyInvalid;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
