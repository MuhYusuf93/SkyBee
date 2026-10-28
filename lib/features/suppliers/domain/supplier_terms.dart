import '../../../core/domain/value_types.dart';

/// Operational agreement metadata, never proof of a payment, outstanding debt
/// or personal identity. Defaults do not create or reconcile old invoices.
final class SupplierTerms {
  const SupplierTerms({
    required this.supplierId,
    required this.name,
    required this.archived,
    required this.allowsCredit,
    required this.revision,
    required this.updatedAt,
  });
  final EntityId supplierId;
  final String name;
  final bool archived, allowsCredit;
  final int revision;
  final int? updatedAt;
}
