import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../management/application/management_service.dart';
import '../domain/supplier_terms.dart';
import '../domain/supplier_invoice.dart';
import '../domain/supplier_credit.dart';
import '../../../core/pagination/page.dart';
import '../../cashier/application/cashier_store.dart';
import '../../cash_drawer/application/cash_drawer_ledger.dart';
import '../../cash_drawer/domain/cash_pieces.dart';
part 'supplier_invoice_posting.dart';
part 'supplier_payment_posting.dart';
part 'supplier_finance_validation.dart';
part 'supplier_finance_queries.dart';
part 'supplier_credit_posting.dart';
part 'supplier_credit_refunds.dart';
part 'supplier_credit_validation.dart';
part 'supplier_credit_queries.dart';

/// Supplier operational facts and owner-controlled financial configuration.
/// Future invoice/payment writers must consume these terms inside their own
/// atomic transaction, never trust a widget's stale eligibility flag.
final class SupplierService {
  const SupplierService(this.database, this.access);
  final DatabaseCoordinator database;
  final ManagementService access;
  static const _ids = IdGenerator();
  static void key(String value) {
    if (value.isEmpty || value.length > 200 || value != value.trim()) {
      throw const AppError('m53SupplierInputInvalid');
    }
  }

  static String fingerprint(Object value) =>
      sha256.convert(utf8.encode(jsonEncode(value))).toString();
  static String? optional(String? value, int max) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    if (text.length > max) throw const AppError('m53SupplierInputInvalid');
    return text;
  }

  Future<T> _read<T>(Future<T> Function(DatabaseExecutor db) work) {
    access.requireAccess(capability: ManagementCapability.inventory);
    final generation = access.generation;
    return database.read((db) async {
      await access.authorize(db, capability: ManagementCapability.inventory);
      if (access.generation != generation) {
        throw const AppError('m53SupplierAccessChanged');
      }
      final result = await work(db);
      await access.authorize(db, capability: ManagementCapability.inventory);
      if (access.generation != generation) {
        throw const AppError('m53SupplierAccessChanged');
      }
      return result;
    });
  }

  Future<T> _write<T>(
    Future<T> Function(Transaction db) work, {
    bool owner = false,
  }) {
    final generation = access.generation;
    return database.transaction((db) async {
      final cap = owner
          ? ManagementCapability.owner
          : ManagementCapability.inventory;
      await access.authorize(db, capability: cap);
      if (access.generation != generation) {
        throw const AppError('m53SupplierAccessChanged');
      }
      final result = await work(db);
      await access.authorize(db, capability: cap);
      if (access.generation != generation) {
        throw const AppError('m53SupplierAccessChanged');
      }
      access.touch();
      return result;
    });
  }

  static const _invoiceSelect = '''SELECT i.*,
    COALESCE((SELECT SUM(p.amount_minor) FROM supplier_payments p WHERE p.invoice_id=i.id
      AND NOT EXISTS(SELECT 1 FROM supplier_payment_reversals r WHERE r.payment_id=p.id)),0) AS paid_minor,
    COALESCE((SELECT SUM(a.amount_minor) FROM supplier_credit_allocations a WHERE a.invoice_id=i.id
      AND NOT EXISTS(SELECT 1 FROM supplier_credit_allocation_reversals v WHERE v.allocation_id=a.id)
      AND NOT EXISTS(SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=a.credit_id)),0) AS credit_minor,
    COALESCE((SELECT a.due_date FROM supplier_due_amendments a
      WHERE a.invoice_id=i.id ORDER BY a.invoice_revision DESC LIMIT 1),i.due_date) AS effective_due
    FROM supplier_invoices i''';
  static Future<SupplierInvoice> invoiceOn(
    DatabaseExecutor db,
    EntityId id,
  ) async {
    final rows = await db.rawQuery('$_invoiceSelect WHERE i.id=?', [id.value]);
    if (rows.length != 1) throw const AppError('m53SupplierInvoiceMissing');
    final invoice = SupplierInvoice(rows.single);
    if (invoice.remaining < 0) throw const AppError('m4InconsistentData');
    return invoice;
  }

  Future<SupplierInvoice> invoice(EntityId id) =>
      _read((db) => invoiceOn(db, id));
  Future<SupplierInvoice?> invoiceForReceipt(EntityId receipt) =>
      _read((db) async {
        final rows = await db.rawQuery(
          "$_invoiceSelect WHERE i.receipt_id=? AND i.status='posted'",
          [receipt.value],
        );
        return rows.isEmpty ? null : SupplierInvoice(rows.single);
      });

  /// Mandatory supplier scope prevents the operational warehouse endpoint from
  /// becoming a consolidated financial report. One bounded indexed SQL page.
  Future<Page<SupplierInvoice, SupplierInvoiceCursor>> invoices(
    EntityId supplier, {
    SupplierInvoiceCursor? after,
    String filter = 'all',
  }) => _read((db) async {
    if (!const ['all', 'open', 'paid', 'overdue'].contains(filter)) {
      throw const AppError('m53SupplierInputInvalid');
    }
    if (after != null &&
        (after.supplier != supplier ||
            after.filter != filter ||
            after.generation != database.generation ||
            after.databaseRevision != database.revision)) {
      throw const AppError('m53SupplierInvoiceChanged');
    }
    final today = await _todayOn(db);
    final rows = await db.rawQuery(
      '''SELECT * FROM ($_invoiceSelect WHERE i.supplier_id=?
      ${after == null ? '' : 'AND (i.invoice_date,i.id)<(?,?)'}) q
      ${filter == 'all' ? '' : "WHERE status='posted' AND total_minor-paid_minor-credit_minor ${filter == 'paid' ? '=0' : '>0'}"}
      ${filter == 'overdue' ? 'AND effective_due IS NOT NULL AND effective_due<?' : ''}
      ORDER BY invoice_date DESC,id COLLATE BINARY DESC LIMIT 21''',
      [
        supplier.value,
        if (after != null) ...[after.date, after.id.value],
        if (filter == 'overdue') today.iso,
      ],
    );
    final page = rows.take(20).map(SupplierInvoice.new).toList();
    return Page(
      items: page,
      nextCursor: rows.length <= 20
          ? null
          : SupplierInvoiceCursor(
              supplier,
              page.last.row['invoice_date'] as String,
              page.last.id,
              database.generation,
              database.revision,
              filter: filter,
            ),
    );
  });

  static Future<SupplierTerms> termsOn(DatabaseExecutor db, EntityId id) async {
    final rows = await db.rawQuery(
      '''SELECT s.id,s.name,s.is_deleted,
      COALESCE(t.allows_credit,0) AS allows_credit,COALESCE(t.revision,0) AS terms_revision,t.updated_at
      FROM suppliers s LEFT JOIN supplier_terms t ON t.supplier_id=s.id WHERE s.id=?''',
      [id.value],
    );
    if (rows.length != 1) throw const AppError('m53SupplierMissing');
    final row = rows.single;
    return SupplierTerms(
      supplierId: id,
      name: row['name'] as String,
      archived: row['is_deleted'] == 1,
      allowsCredit: row['allows_credit'] == 1,
      revision: row['terms_revision'] as int,
      updatedAt: row['updated_at'] as int?,
    );
  }

  Future<SupplierTerms> terms(EntityId id) {
    access.requireAccess(capability: ManagementCapability.inventory);
    return database.read((db) async {
      await access.authorize(db, capability: ManagementCapability.inventory);
      final value = await termsOn(db, id);
      await access.authorize(db, capability: ManagementCapability.inventory);
      return value;
    });
  }

  /// CAS and append-only change facts prevent stale forms from silently
  /// overwriting an agreement. Turning credit off never touches business rows.
  Future<SupplierTerms> saveTerms(
    EntityId id,
    int revision, {
    required bool allowsCredit,
  }) => database.transaction((db) async {
    await access.authorize(db);
    final before = await termsOn(db, id);
    if (before.revision != revision) {
      throw const AppError('m53SupplierTermsChanged');
    }
    if (before.allowsCredit == allowsCredit) {
      await access.authorize(db);
      return before;
    }
    final now = access.clock.milliseconds, next = revision + 1;
    if (revision == 0) {
      await db.insert('supplier_terms', {
        'supplier_id': id.value,
        'allows_credit': allowsCredit ? 1 : 0,
        'revision': next,
        'updated_at': now,
      });
    } else if (await db.update(
          'supplier_terms',
          {
            'allows_credit': allowsCredit ? 1 : 0,
            'revision': next,
            'updated_at': now,
          },
          where: 'supplier_id=? AND revision=?',
          whereArgs: [id.value, revision],
        ) !=
        1) {
      throw const AppError('m53SupplierTermsChanged');
    }
    await db.insert('supplier_terms_events', {
      'id': _ids.next().value,
      'supplier_id': id.value,
      'revision': next,
      'before_allowed': before.allowsCredit ? 1 : 0,
      'after_allowed': allowsCredit ? 1 : 0,
      'actor_role': 'owner',
      'created_at': now,
    });
    await access.audit(db, 'supplier_credit_terms_changed', entityId: id.value);
    await access.authorize(db);
    access.touch();
    return termsOn(db, id);
  });
}
