import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../management/application/management_service.dart';
import '../domain/supplier_terms.dart';

/// Supplier operational facts and owner-controlled financial configuration.
/// Future invoice/payment writers must consume these terms inside their own
/// atomic transaction, never trust a widget's stale eligibility flag.
final class SupplierService {
  const SupplierService(this.database, this.access);
  final DatabaseCoordinator database;
  final ManagementService access;
  static const _ids = IdGenerator();

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
