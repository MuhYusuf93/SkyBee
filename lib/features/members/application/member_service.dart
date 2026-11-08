import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/pagination/page.dart';
import '../../../data/database/database_coordinator.dart';
import '../../management/application/management_service.dart';
import '../../cashier/application/cashier_store.dart';
import '../../cashier_lock/application/cashier_lock_service.dart';
import '../domain/member_models.dart';
import '../domain/member_history.dart';
import 'member_rules.dart';

part 'member_history_service.dart';

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
    outstandingMinor: row['outstanding_minor'] as int?,
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
    MemberListSort sort = MemberListSort.visits,
    bool descending = true,
    bool onlyDebtors = false,
  }) => _ownerRead(
    (db) => _listOn(
      db,
      query,
      archived,
      after,
      pageSize,
      sort: sort,
      descending: descending,
      onlyDebtors: onlyDebtors,
    ),
  );

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
    int pageSize, {
    MemberListSort sort = MemberListSort.visits,
    bool descending = true,
    bool onlyDebtors = false,
  }) async {
    validatePageSize(pageSize);
    final q = normalizeName(query);
    if (q.length > 200) throw const AppError('m53MemberFieldsInvalid');
    if (after != null &&
        (after.query != q ||
            after.archived != archived ||
            after.sort != sort ||
            after.descending != descending ||
            after.onlyDebtors != onlyDebtors ||
            after.generation != database.generation ||
            after.databaseRevision != database.revision)) {
      throw const AppError('m3DraftChanged');
    }
    final region = (await cashier.settings(db))['phone_region'] as String;
    final search = MemberRules.searchWhere(query, region);
    final includeDebt = onlyDebtors || sort == MemberListSort.debt;
    final debtCte = includeDebt
        ? 'debts AS (${CashierStore.debtSqlFor(database.schemaVersion)}),'
        : '';
    final balance = includeDebt
        ? '''COALESCE((SELECT SUM(d.outstanding) FROM debts d
            WHERE d.customer_id=c.id AND d.outstanding>0),0)'''
        : 'NULL';
    const name = 'normalized_name COLLATE BINARY';
    const id = 'id COLLATE BINARY';
    final direction = descending ? 'DESC' : 'ASC';
    final comparison = descending ? '<' : '>';
    final tieDirection = descending ? 'ASC' : 'DESC';
    final tieComparison = descending ? '>' : '<';
    final (order, seek, keys) = switch (sort) {
      MemberListSort.name => (
        '$name $direction,$id $direction',
        '($name,$id)$comparison(?,?)',
        [after?.name, after?.id.value],
      ),
      MemberListSort.visits => (
        'visit_count $direction,$name $tieDirection,$id $tieDirection',
        '(visit_count$comparison? OR (visit_count=? AND ($name,$id)$tieComparison(?,?)))',
        [after?.visits, after?.visits, after?.name, after?.id.value],
      ),
      MemberListSort.added => (
        'created_at $direction,$id $direction',
        '(created_at,$id)$comparison(?,?)',
        [after?.orderingValue, after?.id.value],
      ),
      MemberListSort.debt => (
        'outstanding_minor $direction,$id $direction',
        '(outstanding_minor,$id)$comparison(?,?)',
        [after?.orderingValue, after?.id.value],
      ),
    };
    final restrictions = [
      if (onlyDebtors) 'outstanding_minor>0',
      if (after != null) seek,
    ];
    final rows = await db.rawQuery(
      '''WITH ${debtCte}members AS (
        SELECT $_columns,c.created_at,$balance AS outstanding_minor
        FROM customers c WHERE c.is_deleted=? AND ${search.sql}
      )
      SELECT * FROM members
      ${restrictions.isEmpty ? '' : 'WHERE ${restrictions.join(' AND ')}'}
      ORDER BY $order LIMIT ?''',
      [
        archived ? 1 : 0,
        ...search.arguments,
        if (after != null) ...keys,
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
              sort: sort,
              descending: descending,
              onlyDebtors: onlyDebtors,
              orderingValue: switch (sort) {
                MemberListSort.added => last['created_at'] as int,
                MemberListSort.debt => last['outstanding_minor'] as int,
                _ => 0,
              },
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
