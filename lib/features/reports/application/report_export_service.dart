import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../data/repositories/sqlite_reports_repository.dart';
import '../../management/application/management_service.dart';
import '../domain/report_models.dart';
import 'report_file_writer.dart';

final class ReportExportCancelled implements Exception {
  const ReportExportCancelled();
}

final class ReportExportControl {
  bool cancelled = false;
  int rows = 0;
  void cancel() => cancelled = true;
  void check() {
    if (cancelled) throw const ReportExportCancelled();
  }
}

final class ReportArtifact {
  const ReportArtifact(
    this.directory,
    this.file, {
    this.accessGeneration,
    this.databaseGeneration,
  });
  final Directory directory;
  final File file;
  final int? accessGeneration, databaseGeneration;

  /// A new unlock or replaced store cannot release an older protected export.
  void requireCurrent(ManagementService access) {
    if (accessGeneration != null && accessGeneration != access.generation ||
        databaseGeneration != null &&
            databaseGeneration != access.database.generation) {
      throw StateError('reportSessionChanged');
    }
  }

  Future<void> dispose() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

/// One protected read transaction freezes all sections. SQL pages and file I/O
/// remain service-owned. No network or SAF is performed while the DB is leased.
final class ReportExportService {
  const ReportExportService(this.database, this.access);
  final DatabaseCoordinator database;
  final ManagementService access;
  static String decimal(int minor, int scale) {
    final digits = minor.abs().toString().padLeft(scale + 1, '0');
    return '${minor < 0 ? '-' : ''}${scale == 0 ? digits : '${digits.substring(0, digits.length - scale)}.${digits.substring(digits.length - scale)}'}';
  }

  Future<ReportArtifact> create(
    ReportFilter filter, {
    required bool xlsx,
    required ReportExportControl control,
    void Function(int rows)? progress,
    Future<void> Function()? testPage,
  }) async {
    await access.authorizeCurrent();
    final grant = access.generation, generation = database.generation;
    final directory = await Directory(
      p.join(
        p.dirname(database.databasePath),
        'm51_report_${const Uuid().v4()}',
      ),
    ).create();
    final writer = ReportFileWriter(directory, xlsx);
    var succeeded = false;
    try {
      await database.read(
        (db) => db.transaction((sql) async {
          await access.authorize(sql);
          final settings = (await sql.query(
            'store_settings',
            where: 'id=1',
          )).single;
          final currency = CurrencyPolicy.forCode(
            settings['currency_code'] as String,
          );
          final zone = settings['time_zone'] as String;
          final captured = access.clock.now.toUtc().toIso8601String();
          final common = <String, Object?>{
            'currency': currency.code,
            'scale': currency.scale,
            'zone': zone,
            'captured_utc': captured,
            'period_start_utc': DateTime.fromMillisecondsSinceEpoch(
              filter.start.milliseconds,
              isUtc: true,
            ).toIso8601String(),
            'period_end_exclusive_utc': DateTime.fromMillisecondsSinceEpoch(
              filter.end.milliseconds,
              isUtc: true,
            ).toIso8601String(),
          };
          void add(String section, Map<String, Object?> row) {
            control.check();
            writer.add({...common, 'section': section, ...row});
            control.rows++;
          }

          Future<void> page() async {
            await writer.flush();
            control.check();
            await access.authorize(sql);
            progress?.call(control.rows);
            await testPage?.call();
          }

          final summary = await SqliteReportsRepository.summaryDatabase(
            sql,
            filter,
            access.clock.today(zone).iso,
          );
          await writer.start('Summary');
          final metrics = <String, (Object, String)>{
            'net_sales': (summary.salesMinor.toString(), 'minor'),
            'cost': (summary.costMicros?.toString() ?? '', 'millionth_minor'),
            'gross_profit': (
              summary.grossProfitMicros?.toString() ?? '',
              'millionth_minor',
            ),
            'net_payments': (summary.paymentsMinor.toString(), 'minor'),
            'checkout_payments': (
              summary.checkoutPaymentsMinor.toString(),
              'minor',
            ),
            'repayments': (summary.repaymentsMinor.toString(), 'minor'),
            'unknown_payments': (
              summary.unknownPaymentsMinor.toString(),
              'minor',
            ),
            'current_receivables': (
              summary.receivablesMinor.toString(),
              'minor',
            ),
            'incomplete_cost_events': (summary.incompleteSaleEvents, 'count'),
            'incomplete_inventory_products': (
              summary.incompleteInventoryProducts,
              'count',
            ),
            'sale_count': (summary.saleCount, 'count'),
            'reversal_count': (summary.returnCount, 'count'),
            'current_inventory_value': (
              summary.inventoryMicros?.toString() ?? '',
              'millionth_minor',
            ),
            'current_stock': (summary.inventoryQuantity, 'pcs'),
            'current_expired': (summary.expiredQuantity, 'pcs'),
            'customer_filter': (filter.customerId?.value ?? 'ALL', 'id'),
          };
          for (final e in metrics.entries) {
            add('summary', {
              'metric': e.key,
              'value': e.value.$1,
              'unit': e.value.$2,
            });
          }
          await page();
          for (final section in ReportSection.values) {
            await writer.start(
              section == ReportSection.sales ? 'Sales' : 'Payments',
            );
            final selection = filter.withSection(section);
            ReportCursor? cursor;
            while (true) {
              final query = reportEventsQuery(
                selection,
                cursor,
                100,
                costKnowledge: database.schemaVersion >= 17,
              );
              final entries = (await sql.rawQuery(
                query.sql,
                query.arguments,
              )).take(100).map(ReportEntry.new).toList();
              if (entries.isEmpty) break;
              for (final row in entries) {
                add(section.name, {
                  'event_id': row.id.value,
                  'sale_id': row.saleId?.value,
                  'created_utc': DateTime.fromMillisecondsSinceEpoch(
                    row.createdAt,
                    isUtc: true,
                  ).toIso8601String(),
                  'kind': row.isReversal ? 'reversal' : row.origin,
                  'origin': row.origin,
                  'reversed': row.reversed ? 1 : 0,
                  'amount_minor': row.amountMinor.toString(),
                  'amount_decimal': decimal(row.amountMinor, currency.scale),
                  'cost_micros': row.costMicros?.toString(),
                  'cost_status': row.costMicros == null
                      ? 'incomplete'
                      : 'complete',
                  'customer': row.customerName,
                  'reason': row.reason,
                });
              }
              final last = entries.last, first = entries.first;
              cursor = ReportCursor(
                last.createdAt,
                last.kind,
                last.id.value,
                cursor?.upperCreatedAt ?? first.createdAt,
                cursor?.upperKind ?? first.kind,
                cursor?.upperId ?? first.id.value,
                selection,
                0,
              );
              await page();
            }
          }
          await writer.start('Items');
          List<Object?>? cursor;
          while (true) {
            final rows = await sql.rawQuery(
              '''SELECT i.*,s.created_at,s.customer_name_snapshot,
            EXISTS(SELECT 1 FROM sale_transaction_reversals r WHERE r.sale_transaction_id=s.id) AS reversed
            FROM sale_transaction_items i
            JOIN sale_transactions s ON s.id=i.sale_transaction_id WHERE s.created_at>=? AND s.created_at<?
            ${filter.customerId == null ? '' : 'AND s.customer_id=?'}
            ${cursor == null ? '' : 'AND (s.created_at,s.id,i.id)>(?,?,?)'}
            ORDER BY s.created_at,s.id COLLATE BINARY,i.id COLLATE BINARY LIMIT 100''',
              [
                filter.start.milliseconds,
                filter.end.milliseconds,
                if (filter.customerId != null) filter.customerId!.value,
                ...?cursor,
              ],
            );
            if (rows.isEmpty) break;
            for (final row in rows) {
              add('items', {
                'event_id': row['id'],
                'sale_id': row['sale_transaction_id'],
                'created_utc': DateTime.fromMillisecondsSinceEpoch(
                  row['created_at'] as int,
                  isUtc: true,
                ).toIso8601String(),
                'product_id': row['product_id'],
                'kind': 'original_sale_item',
                'reversed': row['reversed'],
                'sku': row['sku_snapshot'],
                'barcode': row['barcode_snapshot'],
                'name': row['product_name_snapshot'],
                'quantity': row['quantity'],
                'price_minor': '${row['unit_price_rupiah']}',
                'amount_minor': '${row['total_rupiah']}',
                'amount_decimal': decimal(
                  row['total_rupiah'] as int,
                  currency.scale,
                ),
                'cost_micros': row['cost_complete'] == 0
                    ? null
                    : row['cost_micros'],
                'cost_status': row['cost_complete'] == 0
                    ? 'incomplete'
                    : 'complete',
                'pricing_mode': row['pricing_mode'],
                'stock_tracking': row['stock_tracking_snapshot'] == 0
                    ? 'untracked'
                    : 'tracked',
                'cost_basis': row['stock_tracking_snapshot'] == 0
                    ? 'reference_purchase_per_unit'
                    : 'moving_weighted_average',
                'gross_minor': row['gross_minor']?.toString(),
                'discount_minor': row['discount_minor']?.toString(),
                'promo_snapshot': row['promo_snapshot_json'],
                'customer': row['customer_name_snapshot'],
              });
            }
            final last = rows.last;
            cursor = [
              last['created_at'],
              last['sale_transaction_id'],
              last['id'],
            ];
            await page();
          }
          await writer.start('Current inventory');
          String? productCursor;
          while (true) {
            final rows = await sql.rawQuery(
              '''SELECT id,sku,barcode,name,stock_quantity,pack_size,base_unit_label,pack_label,size_milli,size_unit,
            shelf_location,product_note,is_deleted,inventory_value_micros ${database.schemaVersion >= 25 ? ',size_ons_milli' : ''} ${database.schemaVersion >= 17 ? ',cost_complete' : ''} ${database.schemaVersion >= 14 ? ',stock_tracking_enabled,reference_cost_micros' : ''} FROM products
            ${productCursor == null ? '' : 'WHERE id COLLATE BINARY>?'} ORDER BY id COLLATE BINARY LIMIT 100''',
              [?productCursor],
            );
            if (rows.isEmpty) break;
            for (final row in rows) {
              add('current_inventory', {
                'product_id': row['id'],
                'sku': row['sku'],
                'barcode': row['barcode'],
                'name': row['name'],
                'stock_pcs': row['stock_tracking_enabled'] == 0
                    ? '999 — Stok fiktif (tidak dilacak)'
                    : row['stock_quantity'],
                'stock_tracking': row['stock_tracking_enabled'] == 0
                    ? 'untracked'
                    : 'tracked',
                'cost_basis': row['stock_tracking_enabled'] == 0
                    ? 'reference_purchase_per_unit'
                    : 'moving_weighted_average',
                'pcs_per_pack': row['pack_size'],
                'base_unit': row['base_unit_label'],
                'pack_label': row['pack_label'],
                'size_milli': row['size_ons_milli'] ?? row['size_milli'],
                'size_unit': row['size_ons_milli'] != null
                    ? 'ons (100 g)'
                    : row['size_unit'],
                'shelf': row['shelf_location'],
                'note': row['product_note'],
                'archived': row['is_deleted'],
                'cost_status': row['cost_complete'] == 0
                    ? 'incomplete'
                    : 'complete',
                'cost_micros': row['cost_complete'] == 0
                    ? null
                    : row['stock_tracking_enabled'] == 0
                    ? '—'
                    : '${row['inventory_value_micros']}',
              });
            }
            productCursor = rows.last['id'] as String;
            await page();
          }
          await access.authorize(sql);
          control.check();
        }, exclusive: false),
      );
      control.check();
      final file = await writer.finish();
      await access.authorizeCurrent();
      final artifact = ReportArtifact(
        directory,
        file,
        accessGeneration: grant,
        databaseGeneration: generation,
      );
      artifact.requireCurrent(access);
      control.check();
      succeeded = true;
      return artifact;
    } finally {
      if (!succeeded) {
        await writer.endSheet();
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    }
  }
}
