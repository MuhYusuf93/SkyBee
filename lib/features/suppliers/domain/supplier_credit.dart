import '../../../core/domain/value_types.dart';
import '../../cash_drawer/domain/cash_pieces.dart';
import 'supplier_invoice.dart';

/// Explicitly binds the approval preview to the original invoice or its absence.
final class SupplierCreditApprovalInput {
  const SupplierCreditApprovalInput({
    required this.amount,
    required this.date,
    required this.reason,
    this.invoice,
    this.invoiceRevision,
  });
  final Money amount;
  final CalendarDate date;
  final String reason;
  final EntityId? invoice;
  final int? invoiceRevision;
  List<Object?> get fingerprint => [
    amount.amountMinor,
    amount.currencyCode,
    amount.scale,
    date.iso,
    reason.trim(),
    invoice?.value,
    invoiceRevision,
  ];
}

final class SupplierCredit {
  SupplierCredit(Map<String, Object?> row) : row = Map.unmodifiable(row);
  final Map<String, Object?> row;
  EntityId get id => EntityId(row['id'] as String);
  EntityId get returnId => EntityId(row['return_id'] as String);
  EntityId get supplier => EntityId(row['supplier_id'] as String);
  CurrencyPolicy get currency =>
      CurrencyPolicy.forCode(row['currency_code'] as String);
  int get total => row['amount_minor'] as int;
  int get allocated => row['allocated_minor'] as int;
  int get refunded => row['refunded_minor'] as int;
  bool get reversed => row['reversed'] == 1;
  int get available => reversed ? 0 : total - allocated - refunded;
  int get revision => row['credit_revision'] as int;
}

final class SupplierCreditQuote {
  const SupplierCreditQuote({
    required this.returnId,
    required this.supplier,
    required this.supplierName,
    required this.currency,
    required this.today,
    required this.removedValue,
    required this.valueComplete,
    this.invoice,
  });
  final EntityId returnId, supplier;
  final String supplierName;
  final CurrencyPolicy currency;
  final CalendarDate today;
  final BigInt removedValue;
  final bool valueComplete;
  final SupplierInvoice? invoice;
}

/// A refund records money already received outside the app. Incoming drawer
/// pieces describe an actual movement; a bank record executes no transfer.
final class SupplierCreditRefundInput {
  const SupplierCreditRefundInput({
    required this.amount,
    required this.date,
    required this.destination,
    this.reference,
    this.note,
    this.drawerSession,
    this.incoming,
  });
  final Money amount;
  final CalendarDate date;
  final SupplierPaymentSource destination;
  final String? reference, note;
  final EntityId? drawerSession;
  final CashPieces? incoming;
  List<Object?> get fingerprint => [
    amount.amountMinor,
    amount.currencyCode,
    amount.scale,
    date.iso,
    destination.code,
    reference == null || reference!.trim().isEmpty ? null : reference!.trim(),
    note == null || note!.trim().isEmpty ? null : note!.trim(),
    drawerSession?.value,
    incoming?.encode(),
  ];
}

final class SupplierCreditCursor {
  const SupplierCreditCursor(
    this.supplier,
    this.date,
    this.id,
    this.generation,
    this.revision,
  );
  final EntityId supplier, id;
  final String date;
  final int generation, revision;
}

enum SupplierCreditFactKind { allocation, refund }

final class SupplierCreditFactCursor {
  const SupplierCreditFactCursor(
    this.credit,
    this.kind,
    this.sequence,
    this.id,
    this.generation,
    this.revision,
  );
  final EntityId credit, id;
  final SupplierCreditFactKind kind;
  final int sequence, generation, revision;
}
