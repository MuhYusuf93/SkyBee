import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/pagination/page.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../data/repositories/keyset_queries.dart';
import '../domain/cashier_models.dart';
import '../domain/product_search_page.dart';
import '../../cashier_lock/application/cashier_lock_service.dart';
import 'cashier_store.dart';
import 'product_popularity_store.dart';
import 'product_search_queries.dart';

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

abstract interface class PagedProductSearch implements ProductSearch {
  Stream<void> get invalidations;
  Future<ProductSearchPage> page(
    String text, {
    ProductSearchOrder order = ProductSearchOrder.frequent,
    ProductSearchCursor? after,
    int pageSize = 16,
  });
}

/// Portable BINARY token-prefix index: no whole catalog in a Provider and no
/// substring LIKE claim. Dirty trigger queue survives restart/master edits.
final class ProductSearchService implements PagedProductSearch {
  ProductSearchService(this.database, this.store, {this.testStage});
  final DatabaseCoordinator database;
  final CashierStore store;

  /// Deterministic cache-fault injection for newly owned fixtures only.
  final Future<void> Function(String stage)? testStage;
  @override
  Stream<void> get invalidations => Stream<void>.multi((sink) {
    final subscriptions = <StreamSubscription<dynamic>>[
      database.inventoryChanges.listen((_) => sink.add(null)),
      database.replacements.listen((_) => sink.add(null)),
      if (store.cashierAccess != null)
        store.cashierAccess!.changes.listen((_) => sink.add(null)),
    ];
    sink.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
  }, isBroadcast: true);
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
    final proof = await CashierLockService.beginOn(db, store.cashierAccess);
    final rows = await _exact(db, code.trim());
    if (rows.isEmpty) throw const AppError('productNotFound');
    if (rows.length != 1) throw const AppError('m3AmbiguousCode');
    final product = await store.product(
      db,
      EntityId(rows.single['id'] as String),
    );
    await CashierLockService.endOn(db, proof);
    return product;
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
      // Bound Dart objects and platform round trips independently. Native
      // Per-product operations can amplify native IPC cost under device load.
      final ids = dirty.map((row) => row['product_id'] as String).toList();
      final marks = List.filled(ids.length, '?').join(',');
      var batch = dbTxn.batch(), pending = 0;
      Future<void> flush() async {
        if (pending == 0) return;
        await batch.commit(noResult: true);
        batch = dbTxn.batch();
        pending = 0;
      }

      Future<void> terms(String id, String text, int priority) async {
        for (final term in _terms(text)) {
          batch.insert('cashier_search_terms', {
            'product_id': id,
            'term': term,
            'priority': priority,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          if (++pending >= 250) await flush();
        }
      }

      for (final id in ids) {
        batch.delete(
          'cashier_search_terms',
          where: 'product_id=?',
          whereArgs: [id],
        );
        pending++;
      }
      final products = await dbTxn.rawQuery('''SELECT p.id,p.normalized_name,
        c.normalized_name AS category_name FROM products p
        LEFT JOIN categories c ON c.id=p.category_id AND c.is_deleted=0
        WHERE p.id IN($marks) AND p.is_deleted=0''', ids);
      for (final product in products) {
        final id = product['id'] as String;
        await terms(id, product['normalized_name'] as String, 2);
        if (product['category_name'] != null) {
          await terms(id, product['category_name'] as String, 4);
        }
      }
      List<Object?>? cursor;
      while (true) {
        final aliases = await dbTxn.rawQuery(
          '''SELECT a.product_id,a.normalized_alias
          FROM product_aliases a JOIN products p ON p.id=a.product_id
          WHERE a.product_id IN($marks) AND p.is_deleted=0
          ${cursor == null ? '' : 'AND (a.product_id COLLATE BINARY,a.normalized_alias COLLATE BINARY)>(?,?)'}
          ORDER BY a.product_id COLLATE BINARY,a.normalized_alias COLLATE BINARY LIMIT 250''',
          [...ids, ...?cursor],
        );
        if (aliases.isEmpty) break;
        for (final alias in aliases) {
          await terms(
            alias['product_id'] as String,
            alias['normalized_alias'] as String,
            3,
          );
        }
        cursor = [aliases.last['product_id'], aliases.last['normalized_alias']];
      }
      for (final id in ids) {
        batch.delete(
          'cashier_search_dirty',
          where: 'product_id=?',
          whereArgs: [id],
        );
        if (++pending >= 250) await flush();
      }
      await flush();
    }
  }

  @override
  Future<List<CashierProduct>> suggest(String text) async {
    if (database.schemaVersion >= 23) return (await page(text)).items;
    return _legacySuggest(text);
  }

  Future<List<CashierProduct>> _legacySuggest(String text) async {
    final query = normalizeName(text);
    if (query.isEmpty) return const [];
    await checkFts5(); // Capability recorded; same portable backend on all OS.
    return database.transaction((dbTxn) async {
      final proof = await CashierLockService.beginOn(
        dbTxn,
        store.cashierAccess,
      );
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
      await CashierLockService.endOn(dbTxn, proof);
      return List.unmodifiable(results);
    });
  }

  @override
  Future<ProductSearchPage> page(
    String text, {
    ProductSearchOrder order = ProductSearchOrder.frequent,
    ProductSearchCursor? after,
    int pageSize = 16,
  }) async {
    validatePageSize(pageSize);
    final raw = text.trim();
    if (raw.isEmpty) {
      return ProductSearchPage(items: [], windowFrom: 0, windowThrough: 0);
    }
    if (database.schemaVersion < 23) {
      if (after != null) throw const AppError('m3DraftChanged');
      return ProductSearchPage(
        items: await _legacySuggest(text),
        windowFrom: 0,
        windowThrough: 0,
      );
    }
    await checkFts5();
    return database.transaction((dbTxn) async {
      final proof = await CashierLockService.beginOn(
        dbTxn,
        store.cashierAccess,
      );
      await _refresh(dbTxn);
      final settings = await store.settings(dbTxn),
          versions = await ProductPopularityStore.versions(dbTxn);
      final zone = settings['time_zone'] as String,
          day = store.clock.today(settings['time_zone'] as String).iso;
      final now = store.clock.milliseconds;
      var window = await ProductPopularityStore.window(dbTxn);
      final frequent = order == ProductSearchOrder.frequent;
      if (after != null &&
          (after.query != raw ||
              after.order != order ||
              after.generation != database.generation ||
              after.catalogueEpoch != versions['catalogue_epoch'] ||
              after.storeDay != day ||
              after.timeZone != zone ||
              (frequent &&
                  (after.cacheRevision != window['cache_revision'] ||
                      !ProductPopularityStore.fresh(
                        window,
                        now,
                        versions['sale_epoch'] as int,
                      ))))) {
        throw const AppError('m3DraftChanged');
      }
      if (frequent &&
          !ProductPopularityStore.fresh(
            window,
            now,
            versions['sale_epoch'] as int,
          )) {
        window = await ProductPopularityStore.rebuild(
          dbTxn,
          now,
          versions['sale_epoch'] as int,
          testStage: testStage,
        );
      }
      final query = pagedProductSearchQuery(raw, day, order, after, pageSize);
      final rows = await dbTxn.rawQuery(query.sql, query.arguments);
      final results = await store.publicProductPage(
        dbTxn,
        rows
            .take(pageSize)
            .map((row) => EntityId(row['id'] as String))
            .toList(),
        today: day,
      );
      if (store.clock.today(zone).iso != day) {
        throw const AppError('m3DraftChanged');
      }
      await CashierLockService.endOn(dbTxn, proof);
      final last = rows.take(pageSize).lastOrNull;
      return ProductSearchPage(
        items: results,
        windowFrom: window['window_from'] as int,
        windowThrough: window['window_through'] as int,
        nextCursor: rows.length > pageSize && last != null
            ? ProductSearchCursor(
                query: raw,
                order: order,
                generation: database.generation,
                catalogueEpoch: versions['catalogue_epoch'] as int,
                cacheRevision: frequent ? window['cache_revision'] as int : 0,
                storeDay: day,
                timeZone: zone,
                codeTier: last['code_tier'] as int,
                eligibility: last['eligibility'] as int,
                receipts: last['receipts'] as int,
                quantity: last['net_quantity'] as int,
                relevance: last['relevance'] as int,
                name: last['normalized_name'] as String,
                id: EntityId(last['id'] as String),
              )
            : null,
      );
    });
  }
}
