import '../../../core/domain/value_types.dart';
import 'cash_drawer_models.dart';

/// Cursors bind both access scope and database generation. A restore or a
/// switch between public notes and owner audit must start a new page sequence.
final class CashSessionCursor {
  const CashSessionCursor(this.day, this.id, this.owner, this.generation);
  final String day, id;
  final bool owner;
  final int generation;
}

final class CashSessionPage {
  const CashSessionPage(this.items, this.next);
  final List<CashDrawerSession> items;
  final CashSessionCursor? next;
}

final class CashEventCursor {
  const CashEventCursor(
    this.session,
    this.sequence,
    this.owner,
    this.generation,
  );
  final EntityId session;
  final int sequence, generation;
  final bool owner;
}

final class CashSessionDetail {
  const CashSessionDetail(this.session, this.closure, this.events, this.next);
  final CashDrawerSession session;
  final Map<String, Object?>? closure;
  final List<Map<String, Object?>> events;
  final CashEventCursor? next;
}
