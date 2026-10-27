import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/pagination/page.dart';
import '../../../data/database/database_coordinator.dart';
import '../../management/application/management_service.dart';
import '../../cashier/application/cashier_store.dart';
import '../../cashier_lock/application/cashier_lock_service.dart';
import '../domain/member_models.dart';
import 'member_rules.dart';

/// Owner profile administration and bounded cashier transaction lookup share
/// identity rules, but never share an authorization grant or editable balance.
final class MemberService {
  MemberService(this.database, this.access, this.cashier, {this.testStage});
  final DatabaseCoordinator database;
  final ManagementService access;
  final CashierStore cashier;

  /// Deterministic fault/revocation injection only for newly owned fixtures.
  final Future<void> Function(String stage)? testStage;

  Future<T> _ownerRead<T>(Future<T> Function(DatabaseExecutor) action) {
    access.requireAccess();
    return database.read((db) async {
      await access.authorize(db);
      final result = await action(db);
      await testStage?.call('read');
      await access.authorize(db);
      return result;
    });
  }

  Future<T> _ownerWrite<T>(Future<T> Function(Transaction) action) =>
      database.transaction((dbTxn) async {
        await access.authorize(dbTxn);
        final result = await action(dbTxn);
        await testStage?.call('write');
        await access.authorize(dbTxn);
        access.touch();
        return result;
      });

  static const _columns = '''c.id,c.name,c.normalized_name,c.address,
    CASE WHEN typeof(c.phone_number)='text' AND length(c.phone_number)<=128 THEN c.phone_number END AS phone_number,
    c.revision,c.is_deleted,c.visit_count,c.phone_e164,
    EXISTS(SELECT 1 FROM customers other WHERE other.phone_e164=c.phone_e164
      AND other.id<>c.id) AS phone_conflict''';
  static MemberProfile profile(Map<String, Object?> row) => MemberProfile(
    EntityId(row['id'] as String),
    row['name'] as String,
    row['phone_number'] as String?,
    row['address'] as String? ?? '',
    row['revision'] as int,
    row['is_deleted'] == 1,
    row['phone_e164'] == null || row['phone_conflict'] == 1,
    row['visit_count'] as int,
  );

  Future<MemberProfile> _detailOn(DatabaseExecutor db, EntityId id) async {
    final rows = await db.rawQuery(
      'SELECT $_columns FROM customers c WHERE c.id=?',
      [id.value],
    );
    if (rows.isEmpty) throw const AppError('m3CustomerUnavailable');
    return profile(rows.single);
  }

  Future<MemberProfile> ownerDetail(EntityId id) =>
      _ownerRead((db) => _detailOn(db, id));
  Future<Page<MemberProfile, MemberCursor>> ownerList({
    String query = '',
    bool archived = false,
    MemberCursor? after,
    int pageSize = 50,
  }) => _ownerRead((db) => _listOn(db, query, archived, after, pageSize));

  /// This lookup is tied to an active checkout draft and cannot edit/archive a
  /// profile. A late lock or database replacement rejects the returned result.
  Future<Page<MemberProfile, MemberCursor>> forCheckout(
    EntityId draftId, {
    String query = '',
    MemberCursor? after,
    int pageSize = 10,
  }) => database.read((db) async {
    final proof = await CashierLockService.beginOn(db, cashier.cashierAccess);
    await cashier.draft(db, draftId);
    final result = await _listOn(db, query, false, after, pageSize);
    await CashierLockService.endOn(db, proof);
    return result;
  });

  Future<Page<MemberProfile, MemberCursor>> _listOn(
    DatabaseExecutor db,
    String query,
    bool archived,
    MemberCursor? after,
    int pageSize,
  ) async {
    validatePageSize(pageSize);
    final q = normalizeName(query);
    if (q.length > 200) throw const AppError('m53MemberFieldsInvalid');
    if (after != null &&
        (after.query != q ||
            after.archived != archived ||
            after.generation != database.generation ||
            after.databaseRevision != database.revision)) {
      throw const AppError('m3DraftChanged');
    }
    final region = (await cashier.settings(db))['phone_region'] as String;
    final search = MemberRules.searchWhere(query, region);
    final rows = await db.rawQuery(
      '''SELECT $_columns FROM customers c
      WHERE c.is_deleted=? AND ${search.sql}
      ${after == null ? '' : '''AND (c.visit_count<? OR (c.visit_count=? AND
        (c.normalized_name COLLATE BINARY>? OR
          (c.normalized_name COLLATE BINARY=? AND c.id COLLATE BINARY>?))))'''}
      ORDER BY c.visit_count DESC,c.normalized_name COLLATE BINARY,c.id COLLATE BINARY LIMIT ?''',
      [
        archived ? 1 : 0,
        ...search.arguments,
        if (after != null) ...[
          after.visits,
          after.visits,
          after.name,
          after.name,
          after.id.value,
        ],
        pageSize + 1,
      ],
    );
    final limited = rows.take(pageSize).toList(),
        last = rows.take(pageSize).lastOrNull;
    return Page(
      items: limited.map(profile).toList(),
      nextCursor: rows.length > pageSize && last != null
          ? MemberCursor(
              last['visit_count'] as int,
              last['normalized_name'] as String,
              EntityId(last['id'] as String),
              q,
              archived,
              database.generation,
              database.revision,
            )
          : null,
    );
  }

  Future<MemberProfile> create(MemberInput input, {EntityId? requestId}) =>
      _ownerWrite((dbTxn) async {
        final id = requestId ?? CashierStore.ids.next();
        final region =
            (await cashier.settings(dbTxn))['phone_region'] as String;
        final value = MemberRules.normalize(input, region);
        final previous = await dbTxn.query(
          'customers',
          where: 'id=?',
          whereArgs: [id.value],
        );
        if (previous.isNotEmpty) {
          final row = previous.single;
          if (row['name'] != value.name ||
              row['phone_e164'] != value.phone ||
              row['address'] != value.address ||
              row['is_deleted'] != 0) {
            throw const AppError('m3AttemptChanged');
          }
          return _detailOn(dbTxn, id);
        }
        await MemberRules.createOn(
          dbTxn,
          id,
          input,
          region,
          access.clock.milliseconds,
        );
        await access.audit(dbTxn, 'member_created', entityId: id.value);
        return _detailOn(dbTxn, id);
      });

  Future<MemberProfile> update(EntityId id, int revision, MemberInput input) =>
      _ownerWrite((dbTxn) async {
        final region =
            (await cashier.settings(dbTxn))['phone_region'] as String;
        final values = MemberRules.normalize(input, region);
        await MemberRules.requireUnique(dbTxn, values.phone, except: id);
        final changed = await dbTxn.update(
          'customers',
          {
            'name': values.name,
            'normalized_name': normalizeName(values.name),
            'phone_number': values.phone,
            'phone_e164': values.phone,
            'member_phone_region': region,
            'profile_version': 1,
            'address': values.address,
            'revision': revision + 1,
            'updated_at': access.clock.milliseconds,
          },
          where: 'id=? AND revision=?',
          whereArgs: [id.value, revision],
        );
        if (changed != 1) throw const AppError('m3DraftChanged');
        await access.audit(dbTxn, 'member_updated', entityId: id.value);
        return _detailOn(dbTxn, id);
      });

  Future<MemberProfile> archive(EntityId id, int revision, bool archived) =>
      _ownerWrite((dbTxn) async {
        final current = await _detailOn(dbTxn, id);
        if (current.revision != revision) {
          throw const AppError('m3DraftChanged');
        }
        if (current.archived == archived) return current;
        if (!archived) {
          // Restoration cannot revive a duplicate/incomplete identity for NEW
          // sales. Old debts remain payable even while the profile is archived.
          final row = (await dbTxn.query(
            'customers',
            where: 'id=?',
            whereArgs: [id.value],
          )).single;
          final phone = row['phone_e164'] as String?;
          if (phone == null) throw const AppError('m53MemberRepairRequired');
          await MemberRules.requireUnique(dbTxn, phone, except: id);
        }
        final changed = await dbTxn.update(
          'customers',
          {
            'is_deleted': archived ? 1 : 0,
            'revision': revision + 1,
            'updated_at': access.clock.milliseconds,
          },
          where: 'id=? AND revision=?',
          whereArgs: [id.value, revision],
        );
        if (changed != 1) throw const AppError('m3DraftChanged');
        await access.audit(
          dbTxn,
          archived ? 'member_archived' : 'member_restored',
          entityId: id.value,
        );
        return _detailOn(dbTxn, id);
      });
}
