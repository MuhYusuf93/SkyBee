import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'receipt_policy_service.dart';

/// Replay paper obligations without treating transport success as physical
/// evidence. A restored store may retain witnesses after its queue is removed.
abstract final class ReceiptPolicyValidation {
  static Future<void> validate(DatabaseExecutor db) async {
    try {
      final policies = await db.query('receipt_print_policy');
      if (policies.length != 1 || policies.single['id'] != 1) {
        throw const FormatException();
      }
      final policy = policies.single;
      if (!const [0, 1].contains(policy['required']) ||
          policy['revision'] is! int ||
          (policy['revision'] as int) < 1 ||
          policy['updated_at'] is! int ||
          (policy['updated_at'] as int) < 0) {
        throw const FormatException();
      }
      final gates = await db.query('receipt_print_gate');
      if (gates.length != 1 || gates.single['id'] != 1) {
        throw const FormatException();
      }
      String? cursor, pending;
      while (true) {
        final rows = await db.rawQuery(
          '''SELECT r.*,s.created_at AS sale_created,
          x.kind,x.actor,x.operation_key,x.payload_hash,x.job_id,x.job_status,x.reason,x.created_at AS resolved_at,
          j.sale_transaction_id AS job_sale,j.status AS live_job_status,j.operation_key AS live_job_key,j.snapshot_json AS live_snapshot
          FROM sale_receipt_requirements r LEFT JOIN sale_transactions s ON s.id=r.sale_transaction_id
          LEFT JOIN receipt_print_resolutions x ON x.sale_transaction_id=r.sale_transaction_id
          LEFT JOIN print_jobs j ON j.id=x.job_id
          ${cursor == null ? '' : 'WHERE r.sale_transaction_id COLLATE BINARY>?'}
          ORDER BY r.sale_transaction_id COLLATE BINARY LIMIT 50''',
          [?cursor],
        );
        for (final row in rows) {
          final sale = row['sale_transaction_id'] as String;
          if (sale.length != 36 ||
              row['policy_revision'] is! int ||
              (row['policy_revision'] as int) < 2 ||
              (row['policy_revision'] as int) > (policy['revision'] as int) ||
              row['created_at'] is! int ||
              (row['created_at'] as int) < 0 ||
              row['sale_created'] != row['created_at']) {
            throw const FormatException();
          }
          if (row['kind'] == null) {
            if (pending != null) throw const FormatException();
            pending = sale;
            continue;
          }
          final key = row['operation_key'];
          if (key is! String ||
              key.isEmpty ||
              key.length > 200 ||
              key.trim() != key ||
              row['resolved_at'] is! int ||
              (row['resolved_at'] as int) < 0) {
            throw const FormatException();
          }
          String intent;
          switch (row['kind']) {
            case 'operator_confirmation':
              final job = row['job_id'];
              if (row['actor'] != 'operator' ||
                  job is! String ||
                  job.length != 36 ||
                  !const ['submitted', 'unknown'].contains(row['job_status']) ||
                  row['reason'] != null) {
                throw const FormatException();
              }
              if (row['live_snapshot'] != null) {
                final snapshot =
                    jsonDecode(row['live_snapshot'] as String) as Map;
                if (row['job_sale'] != sale ||
                    row['live_job_status'] != row['job_status'] ||
                    ![
                      'first:$sale',
                      'copy:$job',
                    ].contains(row['live_job_key']) ||
                    snapshot['test'] == true ||
                    snapshot.containsKey('productLabel')) {
                  throw const FormatException();
                }
              }
              intent = ReceiptPolicyService.hash([
                'operator_confirmation',
                sale,
                job,
              ]);
            case 'owner_exception':
              final reason = row['reason'];
              if (row['actor'] != 'owner' ||
                  row['job_id'] != null ||
                  row['job_status'] != null ||
                  reason is! String ||
                  reason.isEmpty ||
                  reason.length > 1000 ||
                  reason.trim() != reason) {
                throw const FormatException();
              }
              intent = ReceiptPolicyService.hash([
                'owner_exception',
                sale,
                reason,
              ]);
            default:
              throw const FormatException();
          }
          if (row['payload_hash'] != intent) throw const FormatException();
        }
        if (rows.length < 50) break;
        cursor = rows.last['sale_transaction_id'] as String;
      }
      if (gates.single['pending_sale'] != pending) {
        throw const FormatException();
      }
      if ((await db.rawQuery('''SELECT 1 FROM receipt_print_resolutions x
        LEFT JOIN sale_receipt_requirements r ON r.sale_transaction_id=x.sale_transaction_id
        WHERE r.sale_transaction_id IS NULL LIMIT 1''')).isNotEmpty) {
        throw const FormatException();
      }
    } catch (_) {
      throw const FormatException('backupReceiptPolicyInvalid');
    }
  }
}
