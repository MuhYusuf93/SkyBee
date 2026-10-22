import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/pagination/page.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../data/repositories/keyset_queries.dart';
import '../../management/application/management_service.dart';

typedef PromotionCursor = ({String name, String id, String prefix});

/// Protected, keyset-paged promotion master. A partial unique index is the final
/// cross-engine guard against two simultaneously active rules for one product.
final class QuantityPromotionService {
  const QuantityPromotionService(this.database, this.access);
  final DatabaseCoordinator database;
  final ManagementService access;
  Future<Page<Map<String, Object?>, PromotionCursor>> page({
    String prefix = '',
    PromotionCursor? after,
  }) => database.read((db) async {
    await access.authorize(db);
    final search = normalizeName(prefix),
        end = prefixEnd(normalizeName(prefix));
    if (after != null && after.prefix != search) {
      throw const AppError('filterChangedReloadList');
    }
    final rows = await db.rawQuery(
      '''SELECT q.*,p.name AS product_name,p.is_deleted AS product_archived,
      p.stock_tracking_enabled,p.reference_cost_micros,p.stock_quantity,p.inventory_value_micros,p.selling_price_rupiah
      FROM quantity_promotions q JOIN products p ON p.id=q.product_id WHERE q.is_deleted=0
      AND q.normalized_name>=? ${end == null ? '' : 'AND q.normalized_name<?'}
      ${after == null ? '' : 'AND (q.normalized_name,q.id)>(?,?)'}
      ORDER BY q.normalized_name COLLATE BINARY,q.id COLLATE BINARY LIMIT 51''',
      [
        search,
        ?end,
        if (after != null) ...[after.name, after.id],
      ],
    );
    await access.authorize(db);
    final visible = rows.take(50).toList();
    return Page(
      items: visible,
      nextCursor: rows.length > 50
          ? (
              name: visible.last['normalized_name'] as String,
              id: visible.last['id'] as String,
              prefix: search,
            )
          : null,
    );
  });
  Future<EntityId> save({
    EntityId? id,
    required EntityId product,
    required String name,
    required int minimum,
    required int basisPoints,
    required bool active,
    int? expectedRevision,
  }) => database.transaction((dbTxn) async {
    await access.authorize(dbTxn);
    Quantity.positive(minimum);
    if (basisPoints < 1 ||
        basisPoints > 10000 ||
        name.trim().isEmpty ||
        name.runes.length > 100) {
      throw const AppError('m52PromoInvalid');
    }
    final products = await dbTxn.query(
      'products',
      where: 'id=? AND is_deleted=0',
      whereArgs: [product.value],
    );
    if (products.isEmpty) {
      throw const AppError('productIsArchivedRestoreItFirst');
    }
    final existing = await dbTxn.query(
      'quantity_promotions',
      columns: ['id'],
      where:
          'product_id=? AND active=1 AND is_deleted=0 ${id == null ? '' : 'AND id<>?'}',
      whereArgs: [product.value, ?id?.value],
      limit: 1,
    );
    if (active && existing.isNotEmpty) throw const AppError('m52PromoConflict');
    final target = id ?? const IdGenerator().next();
    final values = <String, Object?>{
      'product_id': product.value,
      'name': name.trim(),
      'normalized_name': normalizeName(name),
      'minimum_quantity': minimum,
      'basis_points': basisPoints,
      'active': active ? 1 : 0,
      'updated_at': access.clock.milliseconds,
    };
    if (id == null) {
      await dbTxn.insert('quantity_promotions', {
        'id': target.value,
        ...values,
        'created_at': access.clock.milliseconds,
      });
    } else {
      final changed = await dbTxn.update(
        'quantity_promotions',
        {...values, 'revision': (expectedRevision ?? 0) + 1},
        where: 'id=? AND revision=? AND is_deleted=0',
        whereArgs: [target.value, expectedRevision],
      );
      if (changed != 1) {
        throw const AppError('productChangedReloadBeforeSaving');
      }
    }
    await access.audit(
      dbTxn,
      'quantity_promotion_saved',
      entityId: target.value,
    );
    await access.authorize(dbTxn);
    return target;
  });
  Future<void> archive(EntityId id, int revision) => database.transaction((
    dbTxn,
  ) async {
    await access.authorize(dbTxn);
    final changed = await dbTxn.update(
      'quantity_promotions',
      {
        'active': 0,
        'is_deleted': 1,
        'revision': revision + 1,
        'updated_at': access.clock.milliseconds,
      },
      where: 'id=? AND revision=? AND is_deleted=0',
      whereArgs: [id.value, revision],
    );
    if (changed != 1) throw const AppError('productChangedReloadBeforeSaving');
    await access.audit(
      dbTxn,
      'quantity_promotion_archived',
      entityId: id.value,
    );
    await access.authorize(dbTxn);
  });
}
