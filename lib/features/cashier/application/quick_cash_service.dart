import '../../../core/domain/app_error.dart';
import 'cashier_store.dart';
import '../../cashier_lock/application/cashier_lock_service.dart';
import 'dart:convert';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../management/application/management_service.dart';

/// Bounded denomination lists only; public cashier writes receive no store/owner authority.
final class QuickCashService {
  const QuickCashService(this.database, this.access, {this.cashierAccess});
  final CashierLockService? cashierAccess;
  final DatabaseCoordinator database;
  final ManagementService access;
  static List<int> defaults(String code) =>
      code == 'IDR' ? [10000, 20000, 50000, 100000] : [500, 1000, 2000, 5000];
  static List<int> validate(String code, Object? values) {
    final policy = CurrencyPolicy.forCode(code);
    if (values is! List ||
        values.isEmpty ||
        values.length > 8 ||
        values.any((e) => e is! int)) {
      throw const FormatException('invalidQuickCash');
    }
    final result = <int>{};
    for (final value in values) {
      if ((value as int) <= 0) continue;
      Money(value, code, policy.scale);
      result.add(value);
    }
    if (result.isEmpty) throw const FormatException('invalidQuickCash');
    return result.toList()..sort();
  }

  /// New editor input is strict; legacy reads retain the established codec.
  static List<int> validateNew(String code, List<int> values) {
    if (values.any((v) => v <= 0) || values.toSet().length != values.length) {
      throw const AppError('m53QuickAmountsInvalid');
    }
    try {
      return validate(code, values);
    } catch (_) {
      throw const AppError('m53QuickAmountsInvalid');
    }
  }

  Future<void> saveForCashier(String code, List<int>? amounts) {
    final store = CashierStore(access.clock, cashierAccess: cashierAccess);
    return store.write(database, (dbTxn) async {
      final currency = store.policy(await store.settings(dbTxn));
      if (currency.code != code) throw const AppError('currencyMismatch');
      if (amounts == null) {
        await dbTxn.delete(
          'cash_quick_amounts',
          where: 'currency_code=?',
          whereArgs: [code],
        );
      } else {
        final values = validateNew(code, amounts);
        await dbTxn.rawInsert(
          'INSERT OR REPLACE INTO cash_quick_amounts(currency_code,amounts_json) VALUES(?,?)',
          [code, jsonEncode(values)],
        );
      }
      await store.audit(dbTxn, 'cash_quick_amounts_changed', code);
    });
  }

  Future<List<int>> read(String code) => database.read((db) async {
    CurrencyPolicy.forCode(code);
    final length = await db.rawQuery(
      'SELECT length(amounts_json) AS n FROM cash_quick_amounts WHERE currency_code=?',
      [code],
    );
    if (length.isEmpty) return defaults(code);
    if (length.single['n'] is! int || (length.single['n'] as int) > 512) {
      throw const FormatException('invalidQuickCash');
    }
    final rows = await db.query(
      'cash_quick_amounts',
      where: 'currency_code=?',
      whereArgs: [code],
      limit: 1,
    );
    return validate(code, jsonDecode(rows.single['amounts_json'] as String));
  });
  Future<void> save(String code, List<int>? amounts) => database.transaction((
    dbTxn,
  ) async {
    await access.authorize(dbTxn);
    CurrencyPolicy.forCode(code);
    if (amounts == null) {
      await dbTxn.delete(
        'cash_quick_amounts',
        where: 'currency_code=?',
        whereArgs: [code],
      );
    } else {
      final values = validate(code, amounts);
      await dbTxn.rawInsert(
        'INSERT OR REPLACE INTO cash_quick_amounts(currency_code,amounts_json) VALUES(?,?)',
        [code, jsonEncode(values)],
      );
    }
    await access.audit(dbTxn, 'cash_quick_amounts_changed', entityId: code);
  });
}
