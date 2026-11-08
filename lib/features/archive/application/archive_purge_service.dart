import 'package:sqflite/sqflite.dart';

import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../management/application/management_service.dart';

enum ArchivePurgeKind {
  product('products'),
  category('categories'),
  supplier('suppliers'),
  member('customers');

  const ArchivePurgeKind(this.table);
  final String table;
}

enum ArchivePurgeBlocker { changed, stockOrValue, reference }

final class ArchivePurgeEntry {
  const ArchivePurgeEntry._(this.id, this.name, this.blocker, this._stamp);

  final EntityId id;
  final String? name;
  final ArchivePurgeBlocker? blocker;
  final int? _stamp;
}

final class ArchivePurgePlan {
  ArchivePurgePlan._(
    this.kind,
    List<ArchivePurgeEntry> entries,
    this._generation,
  ) : entries = List.unmodifiable(entries);

  final ArchivePurgeKind kind;
  final List<ArchivePurgeEntry> entries;
  final int _generation;

  Iterable<ArchivePurgeEntry> get eligible =>
      entries.where((entry) => entry.blocker == null);
}

/// Deletes only explicitly selected archived masters after fresh owner proof.
/// All business and unknown foreign references fail closed at preview and commit.
final class ArchivePurgeService {
  ArchivePurgeService(this.database, this.access);

  static const ownerPurpose = 'archivePurge';
  static const maxSelection = 150;
  static const _disposableProductMetadata = {
    'product_aliases',
    'product_suppliers',
    'cashier_search_terms',
    'cashier_search_dirty',
    'cashier_product_popularity',
  };
  final DatabaseCoordinator database;
  final ManagementService access;

  Future<ArchivePurgePlan> preview(
    ArchivePurgeKind kind,
    List<EntityId> selected,
  ) {
    final ids = List<EntityId>.unmodifiable(selected);
    if (ids.isEmpty ||
        ids.length > maxSelection ||
        ids.toSet().length != ids.length) {
      throw const AppError('m54ArchiveScopeChanged');
    }
    access.requireAccess();
    return database.read((db) async {
      await access.authorize(db);
      final entries = await _previewOn(db, kind, ids);
      await access.authorize(db);
      return ArchivePurgePlan._(kind, entries, database.generation);
    });
  }

  Future<int> purge(
    ArchivePurgePlan plan,
    FreshActionProof proof, {
    void Function()? requireIntent,
  }) async {
    try {
      return await database.transaction((dbTxn) async {
        await access.authorize(dbTxn);
        access.requireClaim(proof, ownerPurpose);
        requireIntent?.call();
        final selected = plan.eligible.toList();
        if (selected.isEmpty) throw const AppError('m54ArchiveNoEligible');
        if (plan._generation != database.generation) {
          throw const AppError('m54ArchiveScopeChanged');
        }
        final ids = selected.map((entry) => entry.id).toList();
        final current = await _previewOn(dbTxn, plan.kind, ids);
        for (var index = 0; index < current.length; index++) {
          final live = current[index], previous = selected[index];
          if (live.blocker != null ||
              live.name != previous.name ||
              live._stamp != previous._stamp) {
            throw const AppError('m54ArchiveScopeChanged');
          }
        }
        final values = ids.map((id) => id.value).toList();
        final marks = List.filled(values.length, '?').join(',');
        if (plan.kind == ArchivePurgeKind.product) {
          // Only metadata owned by the removed product may be detached.
          // Search terms/dirty rows use their existing FK cascade.
          for (final table in [
            'product_aliases',
            if (database.schemaVersion >= 46) 'product_suppliers',
            if (database.schemaVersion >= 23) 'cashier_product_popularity',
          ]) {
            await dbTxn.delete(
              table,
              where: 'product_id IN ($marks)',
              whereArgs: values,
            );
          }
        }
        final deleted = await dbTxn.delete(
          plan.kind.table,
          where: 'is_deleted=1 AND id IN ($marks)',
          whereArgs: values,
        );
        if (deleted != selected.length) {
          throw const AppError('m54ArchiveScopeChanged');
        }
        for (final id in ids) {
          await access.audit(
            dbTxn,
            'archive_purged_${plan.kind.name}',
            entityId: id.value,
          );
        }
        await access.authorize(dbTxn);
        access.requireClaim(proof, ownerPurpose);
        requireIntent?.call();
        access.touch();
        return deleted;
      }, inventoryChanged: true);
    } finally {
      access.releaseClaim(proof);
    }
  }

  static Future<List<ArchivePurgeEntry>> _previewOn(
    DatabaseExecutor db,
    ArchivePurgeKind kind,
    List<EntityId> ids,
  ) async {
    final dependencies = await db.rawQuery(
      '''SELECT m.name AS source,k.id,
        k."from" AS source_field,k."to" AS target_field
      FROM sqlite_master m JOIN pragma_foreign_key_list(m.name) k
      WHERE m.type='table' AND k."table"=?''',
      [kind.table],
    );
    final references = <(String, int), List<String>>{};
    for (final row in dependencies) {
      final table = row['source'] as String;
      final source = row['source_field'] as String;
      if (kind == ArchivePurgeKind.product &&
          source == 'product_id' &&
          _disposableProductMetadata.contains(table)) {
        continue;
      }
      final target = row['target_field'] as String? ?? 'id';
      references
          .putIfAbsent((table, row['id'] as int), () => [])
          .add('x.${_identifier(source)}=r.${_identifier(target)}');
    }
    final lifecycleActions = switch (kind) {
      ArchivePurgeKind.product => const [
        'product_created',
        'product_edited',
        'product_archived',
        'product_restored',
        'product_undo',
      ],
      ArchivePurgeKind.member => const [
        'member_created',
        'member_updated',
        'member_archived',
        'member_restored',
      ],
      _ => const ['master_saved', 'master_archived', 'master_restored'],
    };
    final stock = kind == ArchivePurgeKind.product
        ? 'OR (r.stock_tracking_enabled=1 AND r.stock_quantity>0) OR r.inventory_value_micros>0'
        : '';
    final protection = [
      for (final entry in references.entries)
        'EXISTS(SELECT 1 FROM ${_identifier(entry.key.$1)} x WHERE ${entry.value.join(' AND ')})',
      '''EXISTS(SELECT 1 FROM audit_log a WHERE a.entity_id=r.id AND
        a.action NOT IN (${List.filled(lifecycleActions.length, '?').join(',')}))''',
    ];
    final rows = await db.rawQuery(
      '''SELECT r.id,r.name,
      (SELECT COUNT(*) FROM audit_log a WHERE a.entity_id=r.id) AS stamp,
      CASE WHEN r.is_deleted<>1 THEN ${ArchivePurgeBlocker.changed.index}
        WHEN 0 $stock THEN ${ArchivePurgeBlocker.stockOrValue.index}
        WHEN ${protection.join(' OR ')} THEN ${ArchivePurgeBlocker.reference.index}
      END AS blocker FROM ${kind.table} r
      WHERE r.id IN (${List.filled(ids.length, '?').join(',')})''',
      [...lifecycleActions, ...ids.map((id) => id.value)],
    );
    final byId = {for (final row in rows) row['id'] as String: row};
    return [
      for (final id in ids)
        if (byId[id.value] case final row?)
          ArchivePurgeEntry._(
            id,
            row['name'] as String?,
            row['blocker'] == null
                ? null
                : ArchivePurgeBlocker.values[row['blocker'] as int],
            row['stamp'] as int?,
          )
        else
          ArchivePurgeEntry._(id, null, ArchivePurgeBlocker.changed, null),
    ];
  }

  static String _identifier(String name) => '"${name.replaceAll('"', '""')}"';
}
