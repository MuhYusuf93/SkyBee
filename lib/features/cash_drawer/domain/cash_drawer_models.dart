import '../../../core/domain/value_types.dart';
import 'cash_pieces.dart';

enum CashDrawerMode { off, notes, audit }

final class CashDrawerPolicy {
  const CashDrawerPolicy({this.mode = CashDrawerMode.off, this.revision = 1});
  final CashDrawerMode mode;
  final int revision;
  bool get active => mode != CashDrawerMode.off;
  bool get mandatory => mode == CashDrawerMode.audit;
  factory CashDrawerPolicy.fromRow(Map<String, Object?> row) =>
      CashDrawerPolicy(
        mode: CashDrawerMode.values.byName(row['mode'] as String),
        revision: row['revision'] as int,
      );
}

final class CashDrawerBalance {
  const CashDrawerBalance(
    this.pieces, {
    required this.known,
    required this.revision,
  });
  final CashPieces pieces;
  final bool known;
  final int revision;
}

final class CashDrawerSession {
  CashDrawerSession(
    Map<String, Object?> row,
    this.balance, {
    this.closed = false,
  }) : row = Map.unmodifiable(row);
  final Map<String, Object?> row;
  final CashDrawerBalance balance;
  final bool closed;
  EntityId get id => EntityId(row['id'] as String);
  String get day => row['store_day'] as String;
  String get timeZone => row['time_zone'] as String;
  CurrencyPolicy get currency =>
      CurrencyPolicy.forCode(row['currency_code'] as String);
  CashDrawerMode get mode =>
      CashDrawerMode.values.byName(row['policy_mode'] as String);
  bool get openingKnown => row['opening_counts_json'] != null;
}

final class CashDrawerContext {
  const CashDrawerContext({
    required this.policy,
    required this.day,
    required this.timeZone,
    required this.currency,
    this.session,
    this.unclosedOlder = 0,
  });
  final CashDrawerPolicy policy;
  final String day, timeZone;
  final CurrencyPolicy currency;
  final CashDrawerSession? session;
  final int unclosedOlder;
}

/// Optional new receipt provenance; null on old callers retains the historical
/// idempotency hash and never invents their physical notes or payment method.
enum CashPaymentSource { drawer, external }

final class CashPaymentIntent {
  const CashPaymentIntent({
    required this.source,
    this.sessionId,
    this.incoming,
    this.outgoing,
  });
  final CashPaymentSource source;
  final EntityId? sessionId;
  final CashPieces? incoming, outgoing;
  List<Object?> get financialValues => [
    source.name,
    sessionId?.value,
    incoming?.encode(),
    outgoing?.encode(),
  ];
}
