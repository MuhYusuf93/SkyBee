import '../../../core/domain/value_types.dart';
import '../../cash_drawer/domain/cash_pieces.dart';

enum SupplierInvoiceTerms { cash, credit }

enum SupplierPaymentSource {
  drawer,
  bank,
  ownerFunds;

  String get code => this == ownerFunds ? 'owner_funds' : name;
}

/// Financial total may be reconciled historically without claiming the old
/// product-level HPP is known. Normal invoices always use exact receipt costs.
final class SupplierInvoiceInput {
  const SupplierInvoiceInput({
    required this.invoiceDate,
    this.number,
    this.terms = SupplierInvoiceTerms.cash,
    this.dueDate,
    this.reportedInitialMinor = 0,
    this.historicalTotal,
    this.reconciliationReason,
    this.supplierId,
  });
  final CalendarDate invoiceDate;
  final String? number;
  final SupplierInvoiceTerms terms;
  final CalendarDate? dueDate;
  final int reportedInitialMinor;
  final Money? historicalTotal;
  final String? reconciliationReason;
  final EntityId? supplierId;
  List<Object?> get fingerprint => [
    invoiceDate.iso,
    _clean(number),
    terms.name,
    dueDate?.iso,
    reportedInitialMinor,
    historicalTotal?.amountMinor,
    historicalTotal?.currencyCode,
    historicalTotal?.scale,
    _clean(reconciliationReason),
    supplierId?.value,
  ];
}

/// A payment records money already paid outside the app. Drawer pieces describe
/// only an actual drawer movement; bank records execute no bank transfer.
final class SupplierPaymentInput {
  const SupplierPaymentInput({
    required this.amount,
    required this.date,
    required this.source,
    this.reference,
    this.note,
    this.drawerSession,
    this.outgoing,
  });
  final Money amount;
  final CalendarDate date;
  final SupplierPaymentSource source;
  final String? reference, note;
  final EntityId? drawerSession;
  final CashPieces? outgoing;
  List<Object?> get fingerprint => [
    amount.amountMinor,
    amount.currencyCode,
    amount.scale,
    date.iso,
    source.code,
    _clean(reference),
    _clean(note),
    drawerSession?.value,
    outgoing?.encode(),
  ];
}

String? _clean(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

final class SupplierInvoice {
  SupplierInvoice(Map<String, Object?> row) : row = Map.unmodifiable(row);
  final Map<String, Object?> row;
  EntityId get id => EntityId(row['id'] as String);
  EntityId get receiptId => EntityId(row['receipt_id'] as String);
  EntityId get supplierId => EntityId(row['supplier_id'] as String);
  int get revision => row['revision'] as int;
  String get status => row['status'] as String;
  CurrencyPolicy get currency =>
      CurrencyPolicy.forCode(row['currency_code'] as String);
  int get total => row['total_minor'] as int;
  int get paid => row['paid_minor'] as int;
  int get credit => row['credit_minor'] as int;
  int get remaining => status == 'voided' ? 0 : total - paid - credit;
  CalendarDate? get due => row['effective_due'] == null
      ? null
      : CalendarDate(row['effective_due'] as String);
  String get paymentStatus => remaining == 0
      ? 'paid'
      : paid + credit == 0
      ? 'unpaid'
      : 'partial';
}

final class SupplierInvoiceCursor {
  const SupplierInvoiceCursor(
    this.supplier,
    this.date,
    this.id,
    this.generation,
    this.databaseRevision, {
    this.filter = 'all',
  });
  final EntityId supplier, id;
  final String date;
  final int generation, databaseRevision;
  final String filter;
}

final class SupplierReceiptQuote {
  const SupplierReceiptQuote({
    required this.receipt,
    required this.currency,
    required this.today,
    required this.itemCount,
    this.supplierId,
    this.total,
  });
  final EntityId receipt;
  final EntityId? supplierId;
  final CurrencyPolicy currency;
  final CalendarDate today;
  final int itemCount;

  /// Null includes incomplete costs or a source total finer than one minor unit.
  final Money? total;
}

final class SupplierReceiptCursor {
  const SupplierReceiptCursor(
    this.supplier,
    this.createdAt,
    this.id,
    this.generation,
    this.revision,
  );
  final EntityId supplier, id;
  final int createdAt, generation, revision;
}

final class SupplierPaymentCursor {
  const SupplierPaymentCursor(
    this.invoice,
    this.revision,
    this.id,
    this.generation,
    this.databaseRevision,
  );
  final EntityId invoice, id;
  final int revision, generation, databaseRevision;
}

final class SupplierSummary {
  SupplierSummary(
    Map<String, Map<String, BigInt>> totals,
    this.unreconciled,
    this.today,
  ) : totals = Map.unmodifiable({
        for (final entry in totals.entries)
          entry.key: Map<String, BigInt>.unmodifiable(entry.value),
      });
  final Map<String, Map<String, BigInt>> totals;
  final int unreconciled;
  final CalendarDate today;
}
