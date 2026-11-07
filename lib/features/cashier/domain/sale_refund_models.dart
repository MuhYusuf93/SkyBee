import '../../../core/domain/value_types.dart';
import '../../cash_drawer/domain/cash_pieces.dart';

enum SaleRefundMethod { cash, qris, transfer, external }

final class PendingSaleRefund {
  const PendingSaleRefund(this.id, this.amount, this.createdAt, this.reason);
  final EntityId id;
  final Money amount;
  final int createdAt;
  final String reason;
}

typedef SaleRefundCursor = ({
  EntityId sale,
  EntityId refund,
  int createdAt,
  int revision,
});

final class SaleRefundIntent {
  const SaleRefundIntent(this.method, {this.session, this.outgoing});
  final SaleRefundMethod method;
  final EntityId? session;
  final CashPieces? outgoing;
}

final class SaleRefundReceipt {
  const SaleRefundReceipt({
    required this.id,
    required this.returnId,
    required this.method,
    required this.amount,
    required this.createdAt,
    this.drawerEvent,
  });
  final EntityId id, returnId;
  final SaleRefundMethod method;
  final Money amount;
  final int createdAt;
  final EntityId? drawerEvent;
}
