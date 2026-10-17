import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../data/repositories/keyset_queries.dart';
import '../domain/cashier_models.dart';
import 'cashier_store.dart';

/// Actual ranked search query; token filtering is indexed, while GROUP BY/
/// ranking still has work proportional to its candidates. No O(1) promise.
SqlQuery rankedProductSearchQuery(String text) {
  final query = normalizeName(text), end = prefixEnd(normalizeName(text));
  return SqlQuery(
    '''WITH candidates AS (
        SELECT id AS product_id,0 AS priority FROM products WHERE is_deleted=0 AND barcode=?
        UNION ALL SELECT id,0 FROM products WHERE is_deleted=0 AND sku=?
        UNION ALL SELECT id,1 FROM products WHERE is_deleted=0 AND normalized_name=?
        UNION ALL SELECT product_id,priority FROM cashier_search_terms
        WHERE term COLLATE BINARY>=? ${end == null ? '' : 'AND term COLLATE BINARY<?'})
        SELECT p.id,MIN(c.priority) AS rank FROM candidates c JOIN products p ON p.id=c.product_id
        WHERE p.is_deleted=0 GROUP BY p.id ORDER BY rank,p.normalized_name COLLATE BINARY,p.id COLLATE BINARY LIMIT 16''',
    [text.trim(), text.trim(), query, query, ?end],
  );
}

abstract interface class ProductSearch {
  Future<List<CashierProduct>> suggest(String text);
  Future<CashierProduct> scan(String code);
}

/// Portable BINARY token-prefix index: no whole catalog in a Provider and no
/// substring LIKE claim. Dirty trigger queue survives restart/master edits.
final class ProductSearchService implements ProductSearch {
  ProductSearchService(this.database, this.store);
  final DatabaseCoordinator database;
  final CashierStore store;
  bool? fts5Available;
  Future<bool> checkFts5() => database.read((db) async {
    if (fts5Available != null) return fts5Available!;
    try {
      await db.execute(
        'CREATE VIRTUAL TABLE temp.cashier_fts_probe USING fts5(term)',
      );
      await db.execute('DROP TABLE temp.cashier_fts_probe');
      return fts5Available = true;
    } on DatabaseException {
      return fts5Available = false;
    }
  });
  Future<List<Map<String, Object?>>> _exact(
    DatabaseExecutor db,
    String code,
  ) => db.rawQuery(
    'SELECT id FROM products WHERE is_deleted=0 AND barcode=? UNION SELECT id FROM products WHERE is_deleted=0 AND sku=?',
    [code, code],
  );
  @override
  Future<CashierProduct> scan(String code) => database.read((db) async {
    final rows = await _exact(db, code.trim());
    if (rows.isEmpty) throw const AppError('productNotFound');
    if (rows.length != 1) throw const AppError('m3AmbiguousCode');
    return store.product(db, EntityId(rows.single['id'] as String));
  });
  Set<String> _terms(String text) {
    final normalized = normalizeName(text);
    return {
      normalized,
      normalized.replaceAll(' ', ''),
      ...normalized.split(RegExp(r'[\s\p{P}]+', unicode: true)),
    }..remove('');
  }

  Future<void> _refresh(Transaction dbTxn) async {
    while (true) {
      final dirty = await dbTxn.query(
        'cashier_search_dirty',
        orderBy: 'product_id COLLATE BINARY',
        limit: 100,
      );
      if (dirty.isEmpty) return;
      for (final entry in dirty) {
        final id = entry['product_id'] as String;
        await dbTxn.delete(
          'cashier_search_terms',
          where: 'product_id=?',
          whereArgs: [id],
        );
        final products = await dbTxn.query(
          'products',
          columns: ['normalized_name', 'category_id', 'is_deleted'],
          where: 'id=?',
          whereArgs: [id],
        );
        if (products.isNotEmpty && products.single['is_deleted'] == 0) {
          final product = products.single;
          final sources = <(String, int)>[
            (product['normalized_name'] as String, 2),
          ];
          for (final alias in await dbTxn.query(
            'product_aliases',
            where: 'product_id=?',
            whereArgs: [id],
          )) {
            sources.add((alias['normalized_alias'] as String, 3));
          }
          if (product['category_id'] != null) {
            final category = await dbTxn.query(
              'categories',
              where: 'id=? AND is_deleted=0',
              whereArgs: [product['category_id']],
            );
            if (category.isNotEmpty) {
              sources.add((category.single['normalized_name'] as String, 4));
            }
          }
          for (final source in sources) {
            for (final term in _terms(source.$1)) {
              await dbTxn.insert(
                'cashier_search_terms',
                {'product_id': id, 'term': term, 'priority': source.$2},
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }
          }
        }
        await dbTxn.delete(
          'cashier_search_dirty',
          where: 'product_id=?',
          whereArgs: [id],
        );
      }
    }
  }

  @override
  Future<List<CashierProduct>> suggest(String text) async {
    final query = normalizeName(text);
    if (query.isEmpty) return const [];
    await checkFts5(); // Capability recorded; same portable backend on all OS.
    return database.transaction((dbTxn) async {
      await _refresh(dbTxn);
      final candidateQuery = rankedProductSearchQuery(text);
      final rows = await dbTxn.rawQuery(
        candidateQuery.sql,
        candidateQuery.arguments,
      );
      final results = <CashierProduct>[];
      for (final row in rows) {
        results.add(await store.product(dbTxn, EntityId(row['id'] as String)));
      }
      return List.unmodifiable(results);
    });
  }
}
