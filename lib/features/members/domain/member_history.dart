import '../../../core/domain/value_types.dart';
import '../../../core/pagination/page.dart';
import 'member_models.dart';

enum MemberHistoryKind {
  sale,
  saleReversal,
  saleReturn,
  repayment,
  repaymentReversal,
  refund,
}

final class MemberHistoryEvent {
  const MemberHistoryEvent({
    required this.id,
    required this.saleId,
    required this.kind,
    required this.createdAt,
    required this.amountMinor,
    required this.reversed,
  });

  final EntityId id;
  final EntityId? saleId;
  final MemberHistoryKind kind;
  final int createdAt, amountMinor;
  final bool reversed;
}

final class MemberHistoryCursor {
  const MemberHistoryCursor({
    required this.memberId,
    required this.start,
    required this.end,
    required this.from,
    required this.through,
    required this.generation,
    required this.databaseRevision,
    required this.zone,
    required this.last,
  });

  final EntityId memberId;
  final int start, end, generation, databaseRevision;
  final CalendarDate? from, through;
  final String zone;
  final MemberHistoryEvent last;
}

final class MemberHistoryPage {
  const MemberHistoryPage({
    required this.member,
    required this.currency,
    required this.zone,
    required this.start,
    required this.end,
    required this.purchases,
    required this.purchaseCount,
    required this.outstanding,
    required this.events,
  });

  final MemberProfile member;
  final CurrencyPolicy currency;
  final String zone;
  final int start, end, purchases, purchaseCount, outstanding;
  final Page<MemberHistoryEvent, MemberHistoryCursor> events;
}
