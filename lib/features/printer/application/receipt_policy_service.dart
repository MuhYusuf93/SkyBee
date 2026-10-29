import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../cashier_lock/application/cashier_lock_service.dart';
import '../../cashier/application/cashier_store.dart';
import '../../management/application/management_service.dart';
import '../domain/receipt_print_policy.dart';

/// Post-commit paper obligations never call checkout, stock or payment writers.
/// The singleton gate makes next-basket checks independent of history length.
final class ReceiptPolicyService {
  const ReceiptPolicyService(this.database, this.access, this.cashierAccess);
  final DatabaseCoordinator database;
  final ManagementService access;
  final CashierLockService cashierAccess;
  static const exceptionPurpose = 'receiptException';
  static String hash(List<Object?> values) =>
      sha256.convert(utf8.encode(jsonEncode(values))).toString();
  static void _operation(String key) {
    if (key.isEmpty || key.length > 200 || key.trim() != key) {
      throw const AppError('m3AttemptChanged');
    }
  }

  static Future<String?> pendingOn(DatabaseExecutor db) async =>
      (await db.query(
            'receipt_print_gate',
            columns: ['pending_sale'],
            where: 'id=1',
          )).single['pending_sale']
          as String?;
  static Future<void> requireNoPendingOn(DatabaseExecutor db) async {
    if (await pendingOn(db) != null) {
      throw const AppError('m53ReceiptRequiredPending');
    }
  }

  /// Called only inside the same transaction as the sale's final snapshot.
  static Future<void> recordOn(
    DatabaseExecutor db,
    EntityId sale,
    int createdAt,
  ) async {
    final row = (await db.query('receipt_print_policy', where: 'id=1')).single;
    if (row['required'] != 1) return;
    await db.insert('sale_receipt_requirements', {
      'sale_transaction_id': sale.value,
      'policy_revision': row['revision'],
      'created_at': createdAt,
    });
  }

  Future<ReceiptPrintPolicy> policy() => database.read((db) async {
    await access.authorize(db);
    if (database.schemaVersion < 36) return const ReceiptPrintPolicy();
    final row = (await db.query('receipt_print_policy', where: 'id=1')).single;
    await access.authorize(db);
    return ReceiptPrintPolicy(
      required: row['required'] == 1,
      revision: row['revision'] as int,
    );
  });
  Future<void> savePolicy(bool required, int revision) {
    final generation = database.generation, grant = access.generation;
    return database.transaction((db) async {
      await access.authorize(db);
      if (grant != access.generation) throw const AppError('m3DraftChanged');
      if (database.schemaVersion < 36) {
        throw const AppError('m53ReceiptPolicyUnavailable');
      }
      final changed = await db.update(
        'receipt_print_policy',
        {
          'required': required ? 1 : 0,
          'revision': revision + 1,
          'updated_at': access.clock.milliseconds,
        },
        where: 'id=1 AND revision=?',
        whereArgs: [revision],
      );
      if (changed != 1) throw const AppError('m53ReceiptPolicyChanged');
      await access.audit(
        db,
        required
            ? 'receipt_print_policy_required'
            : 'receipt_print_policy_optional',
      );
      await access.authorize(db);
      if (grant != access.generation) throw const AppError('m3DraftChanged');
    }, expectedGeneration: generation);
  }

  Future<ReceiptPrintState> status(EntityId sale) => database.read((db) async {
    if (database.schemaVersion < 36) return ReceiptPrintState(sale: sale.value);
    final requirement = await db.query(
      'sale_receipt_requirements',
      where: 'sale_transaction_id=?',
      whereArgs: [sale.value],
    );
    if (requirement.isEmpty) return ReceiptPrintState(sale: sale.value);
    final resolved = await db.query(
      'receipt_print_resolutions',
      columns: ['kind'],
      where: 'sale_transaction_id=?',
      whereArgs: [sale.value],
    );
    final jobs = await db.query(
      'print_jobs',
      columns: ['id', 'status'],
      where: 'sale_transaction_id=?',
      whereArgs: [sale.value],
      orderBy: 'created_at DESC,id COLLATE BINARY DESC',
      limit: 1,
    );
    final eligible = await db.query(
      'print_jobs',
      columns: ['id'],
      where: "sale_transaction_id=? AND status IN('submitted','unknown')",
      whereArgs: [sale.value],
      orderBy: 'created_at DESC,id COLLATE BINARY DESC',
      limit: 1,
    );
    return ReceiptPrintState(
      sale: sale.value,
      required: true,
      resolution: resolved.firstOrNull?['kind'] as String?,
      latestJob: jobs.firstOrNull?['id'] as String?,
      latestStatus: jobs.firstOrNull?['status'] as String?,
      confirmableJob: eligible.firstOrNull?['id'] as String?,
    );
  });
  Future<bool> _replay(
    DatabaseExecutor db,
    EntityId sale,
    String key,
    String intent,
  ) async {
    final rows = await db.query(
      'receipt_print_resolutions',
      where: 'operation_key=?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return false;
    if (rows.single['sale_transaction_id'] != sale.value ||
        rows.single['payload_hash'] != intent) {
      throw const AppError('m3AttemptChanged');
    }
    return true;
  }

  static Future<void> _pendingSale(DatabaseExecutor db, EntityId sale) async {
    if (await pendingOn(db) != sale.value) {
      throw const AppError('m53ReceiptNotPending');
    }
  }

  Future<void> confirmPaper(
    EntityId sale,
    String job, {
    required String operationKey,
    bool management = false,
  }) {
    _operation(operationKey);
    final intent = hash(['operator_confirmation', sale.value, job]);
    final generation = database.generation;
    return database.transaction((db) async {
      if (management) await access.authorize(db);
      final proof = await CashierLockService.beginOn(db, cashierAccess);
      if (await _replay(db, sale, operationKey, intent)) {
        if (management) await access.authorize(db);
        await CashierLockService.endOn(db, proof);
        return;
      }
      await _pendingSale(db, sale);
      final jobs = await db.query(
        'print_jobs',
        where: 'id=?',
        whereArgs: [job],
      );
      if (jobs.length != 1 ||
          jobs.single['sale_transaction_id'] != sale.value ||
          !const ['submitted', 'unknown'].contains(jobs.single['status'])) {
        throw const AppError('m53ReceiptConfirmationUnavailable');
      }
      final row = jobs.single,
          snapshot = jsonDecode(jobs.single['snapshot_json'] as String) as Map;
      if (snapshot['test'] == true ||
          snapshot.containsKey('productLabel') ||
          ![
            'first:${sale.value}',
            'copy:$job',
          ].contains(row['operation_key'])) {
        throw const AppError('m53ReceiptConfirmationUnavailable');
      }
      await db.insert('receipt_print_resolutions', {
        'sale_transaction_id': sale.value,
        'operation_key': operationKey,
        'payload_hash': intent,
        'kind': 'operator_confirmation',
        'actor': 'operator',
        'job_id': job,
        'job_status': row['status'],
        'created_at': access.clock.milliseconds,
      });
      await CashierStore(
        access.clock,
        cashierAccess: cashierAccess,
      ).audit(db, 'receipt_paper_operator_confirmed', sale.value);
      await CashierLockService.endOn(db, proof);
      if (management) await access.authorize(db);
    }, expectedGeneration: generation);
  }

  Future<void> ownerException(
    EntityId sale,
    String reason,
    FreshActionProof claim, {
    required String operationKey,
  }) async {
    try {
      _operation(operationKey);
      final text = reason.trim();
      if (text.isEmpty || text.length > 1000) {
        throw const AppError('m53ReceiptExceptionReasonRequired');
      }
      final intent = hash(['owner_exception', sale.value, text]),
          generation = database.generation;
      await database.transaction((db) async {
        await access.authorize(db);
        access.requireClaim(claim, exceptionPurpose);
        if (await _replay(db, sale, operationKey, intent)) {
          await access.authorize(db);
          access.requireClaim(claim, exceptionPurpose);
          return;
        }
        await _pendingSale(db, sale);
        await db.insert('receipt_print_resolutions', {
          'sale_transaction_id': sale.value,
          'operation_key': operationKey,
          'payload_hash': intent,
          'kind': 'owner_exception',
          'actor': 'owner',
          'reason': text,
          'created_at': access.clock.milliseconds,
        });
        await access.audit(
          db,
          'receipt_single_sale_exception',
          entityId: sale.value,
        );
        await access.authorize(db);
        access.requireClaim(claim, exceptionPurpose);
      }, expectedGeneration: generation);
    } finally {
      access.releaseClaim(claim);
    }
  }
}
