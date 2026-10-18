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
  /// **'Blank lines after receipt (0–8)'**
  String get m5Feed;

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
  /// **'Printer is not ready. Check printer settings in Management. The sale remains saved.'**
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

  /// No description provided for @m51Attributes.
  ///
  /// In en, this message translates to:
  /// **'Optional product attributes'**
  String get m51Attributes;

  /// No description provided for @m51Size.
  ///
  /// In en, this message translates to:
  /// **'Weight / volume'**
  String get m51Size;

  /// No description provided for @m51SizeHelp.
  ///
  /// In en, this message translates to:
  /// **'Up to 3 decimals, no grouping. Example: 0.5'**
  String get m51SizeHelp;

  /// No description provided for @m51Unit.
  ///
  /// In en, this message translates to:
  /// **'Size unit'**
  String get m51Unit;

  /// No description provided for @m51NoUnit.
  ///
  /// In en, this message translates to:
  /// **'No unit'**
  String get m51NoUnit;

  /// No description provided for @m51Liter.
  ///
  /// In en, this message translates to:
  /// **'liter'**
  String get m51Liter;

  /// No description provided for @m51Shelf.
  ///
  /// In en, this message translates to:
  /// **'Shelf location'**
  String get m51Shelf;

  /// No description provided for @m51Note.
  ///
  /// In en, this message translates to:
  /// **'Product note'**
  String get m51Note;

  /// No description provided for @m51AttributesHelp.
  ///
  /// In en, this message translates to:
  /// **'Size is descriptive; stock stays in pcs. Shelf: 80 characters; note: 1,000. Clear both value and unit to remove size.'**
  String get m51AttributesHelp;

  /// No description provided for @m51AttributesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive size with its unit (up to 3 decimals, no grouping). Check shelf 80 and note 1,000 character limits.'**
  String get m51AttributesInvalid;
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
