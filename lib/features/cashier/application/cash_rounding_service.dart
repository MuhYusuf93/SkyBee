import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../management/application/management_service.dart';
import '../domain/checkout_settlement.dart';
import 'cashier_store.dart';

/// Per-currency preference for future cash checkouts. A changed preference
/// invalidates an open preview and never changes a posted receipt.
final class CashRoundingService {
  const CashRoundingService(this.database, this.store, this.access);
  final DatabaseCoordinator database;
  final CashierStore store;
  final ManagementService access;

  static Future<CashRoundingPolicy> policyOn(
    DatabaseExecutor db,
    CurrencyPolicy currency,
  ) async {
    final row = (await db.query(
      'cash_rounding_settings',
      where: 'currency_code=?',
      whereArgs: [currency.code],
      limit: 1,
    )).firstOrNull;
    return row == null
        ? CashRoundingPolicy(currency)
        : CashRoundingPolicy(
            currency,
            step: row['step_minor'] as int,
            revision: row['revision'] as int,
          );
  }

  Future<CashRoundingPolicy> forCashier() => store.read(database, (db) async {
    final currency = store.policy(await store.settings(db));
    return database.schemaVersion < 44
        ? CashRoundingPolicy(currency)
        : policyOn(db, currency);
  });

  Future<CashRoundingPolicy> forOwner() => database.read((db) async {
    await access.authorize(db);
    final value = await policyOn(db, store.policy(await store.settings(db)));
    await access.authorize(db);
    return value;
  });

  Future<CashRoundingPolicy> save(CashRoundingPolicy expected, int step) =>
      database.transaction((dbTxn) async {
        await access.authorize(dbTxn);
        final currency = store.policy(await store.settings(dbTxn));
        final current = await policyOn(dbTxn, currency);
        if (currency.code != expected.currency.code ||
            current.revision != expected.revision) {
          throw const AppError('m54RoundingChanged');
        }
        if (step != 0 && !CashRoundingPolicy.steps(currency).contains(step)) {
          throw const AppError('m54RoundingInvalid');
        }
        if (step == current.step) return current;
        final next = CashRoundingPolicy(
          currency,
          step: step,
          revision: current.revision + 1,
        );
        await dbTxn.insert('cash_rounding_settings', {
          'currency_code': currency.code,
          'step_minor': next.step,
          'revision': next.revision,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await access.audit(dbTxn, 'cash_rounding_saved');
        await access.authorize(dbTxn);
        return next;
      });
}
