import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../cashier/application/cashier_store.dart';
import '../../cashier/domain/cash_tender.dart';
import '../../cashier/domain/cashier_models.dart';
import '../domain/cash_pieces.dart';
import '../domain/cash_drawer_models.dart';
import 'cash_drawer_ledger.dart';

/// Financial services call this inside their existing dbTxn. Methods classify
/// only new payments: absent legacy provenance never becomes invented cash.
abstract final class CashPaymentPosting {
  static CashPieces _composition(
    CurrencyPolicy currency,
    CashPieces? value,
    int total,
  ) {
    if (total == 0 && value == null) return CashPieces(currency, {});
    if (value == null ||
        value.currency.code != currency.code ||
        value.currency.scale != currency.scale ||
        value.total.amountMinor != total) {
      throw const AppError('m53CashCompositionMismatch');
    }
    return value;
  }

  static Future<void> _sourceOn(
    Transaction db,
    EntityId payment,
    CashDrawerPolicy policy,
    String source, {
    EntityId? event,
    EntityId? session,
    int? incomingMinor,
    int? outgoingMinor,
    CashPieces? incoming,
    CashPieces? outgoing,
  }) => db
      .insert('payment_cash_sources', {
        'payment_id': payment.value,
        'source': source,
        'policy_mode': policy.mode.name,
        'event_id': event?.value,
        'session_id': event == null ? null : session?.value,
        'in_minor': incomingMinor,
        'out_minor': outgoingMinor,
        'in_counts_json': incoming?.encode(),
        'out_counts_json': outgoing?.encode(),
      })
      .then<void>((_) {});

  static Future<void> checkoutOn(
    Transaction db,
    CashierStore store, {
    required EntityId sale,
    required EntityId? payment,
    required CheckoutInput input,
    required CashTender? tender,
    required Money paid,
    required CurrencyPolicy currency,
  }) async {
    final policy = await CashDrawerLedger.policyOn(db);
    if (tender == null) {
      if (input.changePieces != null || input.drawerSessionId != null) {
        throw const AppError('m3InvalidPayment');
      }
      if (policy.active && paid.amountMinor > 0) {
        throw const AppError('m53CashCompositionRequired');
      }
      if (payment != null) await _sourceOn(db, payment, policy, 'unknown');
      return;
    }
    CashPieces? incoming, outgoing = input.changePieces;
    if (input.drawerSessionId != null) {
      final rows = await db.query(
        'cash_drawer_sessions',
        columns: ['currency_code', 'currency_scale'],
        where: 'id=?',
        whereArgs: [input.drawerSessionId!.value],
        limit: 2,
      );
      if (rows.length != 1 ||
          rows.single['currency_code'] != currency.code ||
          rows.single['currency_scale'] != currency.scale) {
        throw const AppError('currencyMismatch');
      }
    }
    if (outgoing != null) {
      _composition(currency, outgoing, tender.change.amountMinor);
    }
    EntityId? event;
    if (policy.active &&
        (tender.received.amountMinor > 0 || tender.change.amountMinor > 0)) {
      try {
        incoming = CashPieces.fromTender(
          currency,
          input.tenderDetails,
          tender.received.amountMinor,
        );
      } on FormatException {
        throw const AppError('m53CashCompositionRequired');
      }
      outgoing = _composition(currency, outgoing, tender.change.amountMinor);
      event = await CashDrawerLedger.postOn(
        db,
        store,
        sourceKind: 'checkout',
        sourceId: sale,
        currency: currency,
        sessionId: input.drawerSessionId,
        incoming: incoming,
        outgoing: outgoing,
      );
    } else if (input.tenderDetails != null) {
      // Historical quick amounts can be arbitrary denominations. Retain that
      // tender snapshot while declining to relabel it as a supported cash vector.
      try {
        incoming = CashPieces.fromTender(
          currency,
          input.tenderDetails,
          tender.received.amountMinor,
        );
      } on FormatException {
        incoming = null;
      }
    }
    if (payment != null) {
      await _sourceOn(
        db,
        payment,
        policy,
        'drawer',
        event: event,
        session: input.drawerSessionId,
        incomingMinor: tender.received.amountMinor,
        outgoingMinor: tender.change.amountMinor,
        incoming: incoming,
        outgoing: outgoing,
      );
    }
  }

  /// A repayment's net amount is its allocation, not tender received. External
  /// receipts require an explicit choice and never mutate a drawer.
  static Future<void> receiptOn(
    Transaction db,
    CashierStore store, {
    required EntityId payment,
    required Money amount,
    required CashPaymentIntent? intent,
  }) async {
    final policy = await CashDrawerLedger.policyOn(db),
        currency = CurrencyPolicy.forCode(amount.currencyCode);
    if (intent == null) {
      if (policy.active) throw const AppError('m53CashCompositionRequired');
      await _sourceOn(db, payment, policy, 'unknown');
      return;
    }
    if (intent.source == CashPaymentSource.external) {
      _external(intent);
      await _sourceOn(db, payment, policy, 'external');
      return;
    }
    final incoming = intent.incoming;
    var outgoing = intent.outgoing;
    if (incoming == null) {
      if (policy.active || outgoing != null || intent.sessionId != null) {
        throw const AppError('m53CashCompositionRequired');
      }
      await _sourceOn(db, payment, policy, 'drawer');
      return;
    }
    amount.compatible(incoming.total);
    final change = incoming.total.amountMinor - amount.amountMinor;
    if (change < 0) throw const AppError('m53CashCompositionMismatch');
    if (outgoing != null || policy.active) {
      outgoing = _composition(currency, outgoing, change);
    }
    EntityId? event;
    if (policy.active) {
      event = await CashDrawerLedger.postOn(
        db,
        store,
        sourceKind: 'receivable',
        sourceId: payment,
        currency: currency,
        sessionId: intent.sessionId,
        incoming: incoming,
        outgoing: outgoing!,
      );
    }
    await _sourceOn(
      db,
      payment,
      policy,
      'drawer',
      event: event,
      session: intent.sessionId,
      incomingMinor: incoming.total.amountMinor,
      outgoingMinor: change,
      incoming: incoming,
      outgoing: outgoing,
    );
  }

  static void _external(CashPaymentIntent intent) {
    if (intent.incoming != null ||
        intent.outgoing != null ||
        intent.sessionId != null) {
      throw const AppError('m3InvalidPayment');
    }
  }

  /// Refund only the original applied payment, with newly declared outgoing
  /// pieces. Never reverse the old tender/count vector as a physical guess.
  static Future<void> refundOn(
    Transaction db,
    CashierStore store, {
    required EntityId payment,
    required Money amount,
    required CashPaymentIntent? intent,
  }) async {
    final policy = await CashDrawerLedger.policyOn(db),
        currency = CurrencyPolicy.forCode(amount.currencyCode);
    if (intent == null) {
      if (policy.active) throw const AppError('m53CashCompositionRequired');
      await _sourceOn(db, payment, policy, 'unknown');
      return;
    }
    if (intent.source == CashPaymentSource.external) {
      _external(intent);
      await _sourceOn(db, payment, policy, 'external');
      return;
    }
    if (intent.incoming != null) throw const AppError('m3InvalidPayment');
    CashPieces? outgoing = intent.outgoing;
    if (outgoing != null || policy.active) {
      outgoing = _composition(currency, outgoing, amount.amountMinor);
    }
    EntityId? event;
    final empty = CashPieces(currency, {});
    if (policy.active) {
      event = await CashDrawerLedger.postOn(
        db,
        store,
        sourceKind: 'refund',
        sourceId: payment,
        currency: currency,
        sessionId: intent.sessionId,
        incoming: empty,
        outgoing: outgoing!,
      );
    }
    await _sourceOn(
      db,
      payment,
      policy,
      'drawer',
      event: event,
      session: intent.sessionId,
      incomingMinor: 0,
      outgoingMinor: amount.amountMinor,
      incoming: empty,
      outgoing: outgoing,
    );
  }
}
