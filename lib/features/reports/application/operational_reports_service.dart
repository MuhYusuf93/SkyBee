import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../inventory/application/warehouse_query.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../inventory/domain/stock_rules.dart';
import '../../management/application/management_service.dart';
import '../../suppliers/application/supplier_service.dart';
import '../../suppliers/domain/supplier_invoice.dart';
import '../../suppliers/domain/supplier_credit.dart';
import '../domain/operational_report.dart';
import 'report_export_service.dart';
import 'report_file_writer.dart';
part 'operational_report_queries.dart';
part 'operational_report_values.dart';

/// Owner-only read models. Bounded keyset reads share one snapshot, calendar
/// cutoff and ledger projections; no current price ever rewrites sale history.
final class OperationalReportsService {
  const OperationalReportsService(this.database, this.access);
  final DatabaseCoordinator database;
  final ManagementService access;

  void _validate(OperationalScope scope) {
    if (scope.search.length > 200 ||
        (scope.from == null) != (scope.through == null) ||
        scope.from != null &&
            scope.from!.iso.compareTo(scope.through!.iso) > 0) {
      throw const AppError('m4InvalidPeriod');
    }
  }

  Future<T> _read<T>(
    Future<T> Function(
      Transaction sql,
      _ReportContext c,
      Future<void> Function() check,
    )
    work,
  ) async {
    access.requireAccess();
    final grant = access.generation, generation = database.generation;
    return database.read(
      (db) => db.transaction((sql) async {
        Future<void> check() async {
          if (grant != access.generation || generation != database.generation) {
            throw const AppError('m53OperationalReportChanged');
          }
          await access.authorize(sql);
        }

        await check();
        final settings = (await sql.query(
          'store_settings',
          where: 'id=1',
        )).single;
        final zone = settings['time_zone'] as String,
            captured = access.clock.milliseconds;
        final c = _ReportContext(
          zone,
          access.clock.dateAt(captured, zone).iso,
          captured,
          generation,
          database.revision,
        );
        final result = await work(sql, c, check);
        await check();
        return result;
      }, exclusive: false),
    );
  }

  /// Summary streams the ENTIRE filtered scope; the UI retains at most20 rows.
  /// Mutable cursor contexts reject both commits and a change of shop day.
  Future<OperationalSnapshot> load(
    OperationalScope scope, {
    OperationalCursor? after,
    bool Function()? cancelled,
  }) {
    _validate(scope);
    return _read((sql, c, authorize) async {
      Future<void> check() async {
        if (cancelled?.call() == true) throw const ReportExportCancelled();
        await authorize();
      }

      await check();
      final identity = jsonEncode(scope.identity);
      if (after != null &&
          (after.scope != identity ||
              after.generation != c.generation ||
              after.revision != c.revision ||
              after.day != c.day)) {
        throw const AppError('m53OperationalReportChanged');
      }
      final totals = <String, Map<String, BigInt>>{};
      await for (final row in _rows(sql, scope, c, check)) {
        _accumulate(
          totals.putIfAbsent('${row.currency}:${row.scale}', () => {}),
          row.amounts,
        );
      }
      final rows = <OperationalRow>[];
      await for (final row in _rows(sql, scope, c, check, after: after)) {
        rows.add(row);
        if (rows.length == 21) break;
      }
      final hasMore = rows.length > 20;
      if (hasMore) rows.removeLast();
      final last = rows.isEmpty ? null : rows.last;
      await check();
      return OperationalSnapshot(
        c.zone,
        c.day,
        c.captured,
        Map.unmodifiable({
          for (final e in totals.entries)
            e.key: Map<String, BigInt>.unmodifiable(e.value),
        }),
        List.unmodifiable(rows),
        !hasMore || last == null
            ? null
            : OperationalCursor(
                last.group,
                last.id,
                identity,
                c.generation,
                c.revision,
                c.day,
              ),
      );
    });
  }

  /// Read-only diagnostics use the actual paged query, including its cursor.
  /// They report planner metadata only, never business rows or query arguments.
  Future<List<String>> queryPlan(
    OperationalScope scope, {
    bool withCursor = false,
  }) {
    _validate(scope);
    return _read((sql, c, check) async {
      final plans = <String>[];
      for (final nextGroup
          in withCursor && _pagedByGroup(scope) ? [false, true] : [true]) {
        final page = _pageQuery(
          _query(scope, c),
          withCursor ? '' : null,
          '',
          nextGroup: nextGroup,
        );
        plans.addAll(
          (await sql.rawQuery(
            'EXPLAIN QUERY PLAN ${page.$1}',
            page.$2,
          )).map((row) => row['detail'] as String),
        );
      }
      return plans;
    });
  }

  static (String, List<Object?>) _pageQuery(
    (String, List<Object?>) query,
    String? group,
    String? id, {
    bool nextGroup = false,
    int limit = 100,
  }) => (
    '''WITH q AS (${query.$1}) SELECT * FROM q
        ${group == null
        ? ''
        : nextGroup
        ? 'WHERE report_group COLLATE BINARY>?'
        : 'WHERE report_group COLLATE BINARY=? AND id COLLATE BINARY>?'}
        ORDER BY ${group != null && !nextGroup ? 'id COLLATE BINARY' : 'report_group COLLATE BINARY,id COLLATE BINARY'} LIMIT $limit''',
    [
      ...query.$2,
      if (group != null) ...[group, if (!nextGroup) id],
    ],
  );

  static bool _grouped(OperationalScope scope) =>
      scope.section == OperationalSection.potential &&
          scope.grouping != PotentialGrouping.product ||
      scope.section == OperationalSection.supplierInvoices &&
          scope.grouping == PotentialGrouping.supplier ||
      scope.section == OperationalSection.pendingReturns;

  /// Financial UNIONs need (event kind, table ID), even if two tables reuse a
  /// UUID. They share cursor groups without aggregating distinct event rows.
  static bool _pagedByGroup(OperationalScope scope) =>
      _grouped(scope) ||
      scope.section == OperationalSection.supplierPayments ||
      scope.section == OperationalSection.supplierRefunds;

  Stream<OperationalRow> _rows(
    Transaction sql,
    OperationalScope scope,
    _ReportContext c,
    Future<void> Function() check, {
    OperationalCursor? after,
  }) async* {
    final query = _query(scope, c);
    String? group = after?.group, id = after?.id;
    OperationalRow? pending;
    final grouped = _grouped(scope);
    final pagedByGroup = _pagedByGroup(scope);
    while (true) {
      await check();
      final page = _pageQuery(query, group, id, nextGroup: !pagedByGroup);
      final sources = (await sql.rawQuery(page.$1, page.$2)).toList();
      // Equality on the group followed by an ID range makes SQLite SEEK both
      // index columns. A row-value expression index comparison can still SCAN
      // every prior row. At a group boundary one second bounded read fills the
      // remainder; large groups need only one source call per100 rows.
      if (pagedByGroup && group != null && sources.length < 100) {
        final rest = _pageQuery(
          query,
          group,
          id,
          nextGroup: true,
          limit: 100 - sources.length,
        );
        sources.addAll(await sql.rawQuery(rest.$1, rest.$2));
      }
      if (sources.isEmpty) break;
      final stock = scope.section == OperationalSection.potential
          ? await warehouseProductsOn(sql, sources, c.day)
          : const <InventoryProduct>[];
      for (var n = 0; n < sources.length; n++) {
        final row = _value(
          scope,
          sources[n],
          c,
          stock.isEmpty ? null : stock[n],
        );
        if (grouped) {
          if (pending != null && pending.group != row.group) {
            yield pending;
            pending = null;
          }
          final amounts = <String, BigInt>{...?pending?.amounts};
          _accumulate(amounts, row.amounts);
          pending = OperationalRow(
            id: row.id,
            group: row.group,
            currency: row.currency,
            scale: row.scale,
            details: {
              'name': row.details['group_name'],
              'supplier_id': row.details['supplier_id'],
              'grouping': scope.section == OperationalSection.pendingReturns
                  ? 'pending_return'
                  : scope.grouping.name,
            },
            amounts: amounts,
          );
        } else {
          yield row;
        }
      }
      group = sources.last['report_group'] as String;
      id = sources.last['id'] as String;
      if (sources.length < 100) break;
    }
    if (pending != null) yield pending;
  }

  /// Uses the existing typed CSV/SpreadsheetML writer and destination flow.
  /// One protected snapshot includes whole-scope totals, every matching row,
  /// exact integer units, filter definition and capture/timezone metadata.
  Future<ReportArtifact> export(
    OperationalScope scope, {
    required bool xlsx,
    required ReportExportControl control,
    void Function(int)? progress,
    Future<void> Function()? testPage,
  }) async {
    _validate(scope);
    await access.authorizeCurrent();
    final exportGrant = access.generation,
        exportGeneration = database.generation;
    final directory = await Directory(
      p.join(
        p.dirname(database.databasePath),
        'm51_report_${const Uuid().v4()}',
      ),
    ).create();
    const keys = [
      'section',
      'row_id',
      'group_id',
      'currency',
      'scale',
      'field',
      'value',
      'unit',
      'zone',
      'shop_day',
      'captured_utc',
      'scope',
    ];
    final writer = ReportFileWriter(directory, xlsx, fieldKeys: keys);
    var success = false;
    try {
      await _read((sql, c, authorize) async {
        Future<void> check() async {
          control.check();
          await authorize();
        }

        final common = <String, Object?>{
          'zone': c.zone,
          'shop_day': c.day,
          'captured_utc': DateTime.fromMillisecondsSinceEpoch(
            c.captured,
            isUtc: true,
          ).toIso8601String(),
          'scope': jsonEncode(scope.identity),
        };
        void add(Map<String, Object?> values) {
          control.check();
          writer.add({...common, ...values});
          control.rows++;
        }

        await writer.start('Details');
        final totals = <String, Map<String, BigInt>>{};
        var count = 0;
        await for (final row in _rows(sql, scope, c, check)) {
          final base = <String, Object?>{
            'section': scope.section.name,
            'row_id': row.id,
            'group_id': row.group,
            'currency': row.currency,
            'scale': row.scale,
          };
          _accumulate(
            totals.putIfAbsent('${row.currency}:${row.scale}', () => {}),
            row.amounts,
          );
          for (final field in row.details.entries) {
            add({
              ...base,
              'field': field.key,
              'value': field.value?.toString(),
              'unit': 'text',
            });
          }
          for (final field in row.amounts.entries) {
            add({
              ...base,
              'field': field.key,
              'value': field.value.toString(),
              'unit': unit(field.key),
            });
          }
          if (++count % 100 == 0) {
            await writer.flush();
            progress?.call(control.rows);
            await testPage?.call();
            await check();
          }
        }
        await writer.start('Summary');
        for (final currency in totals.entries) {
          for (final field in currency.value.entries) {
            add({
              'section': 'summary',
              'currency': currency.key.split(':').first,
              'scale': int.parse(currency.key.split(':').last),
              'field': field.key,
              'value': field.value.toString(),
              'unit': unit(field.key),
            });
          }
        }
        await writer.flush();
        progress?.call(control.rows);
        await check();
      });
      control.check();
      final result = await writer.finish();
      await access.authorizeCurrent();
      if (exportGrant != access.generation ||
          exportGeneration != database.generation) {
        throw const AppError('m53OperationalReportChanged');
      }
      control.check();
      success = true;
      return ReportArtifact(
        directory,
        result,
        accessGeneration: exportGrant,
        databaseGeneration: exportGeneration,
      );
    } finally {
      if (!success) {
        await writer.endSheet();
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    }
  }

  static String unit(String key) => key.endsWith('_micros')
      ? 'millionth_minor'
      : key.endsWith('_minor')
      ? 'minor'
      : key.endsWith('_quantity')
      ? 'base_units'
      : 'count';
  static void _accumulate(
    Map<String, BigInt> target,
    Map<String, BigInt> values,
  ) {
    for (final e in values.entries) {
      target[e.key] = (target[e.key] ?? BigInt.zero) + e.value;
    }
  }
}

final class _ReportContext {
  const _ReportContext(
    this.zone,
    this.day,
    this.captured,
    this.generation,
    this.revision,
  );
  final String zone, day;
  final int captured, generation, revision;
}
