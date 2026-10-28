import '../../../core/domain/value_types.dart';
import 'stock_input.dart';
import 'stock_rules.dart';

final class StocktakeLine {
  StocktakeLine(Map<String, Object?> row) : row = Map.unmodifiable(row);
  final Map<String, Object?> row;
  EntityId get id => EntityId(row['id'] as String);
  EntityId get productId => EntityId(row['product_id'] as String);
  String get name => row['product_name'] as String;
  String get baseUnit => row['base_unit'] as String;
  int get baselineQuantity => row['baseline_quantity'] as int;
  int get pendingBatches =>
      (row['observation_count'] as int) - (row['counted_batches'] as int);
  int get partialCount => row['partial_count'] as int;
  int? get counted => pendingBatches == 0 ? partialCount : null;
  int? get delta => counted == null ? null : counted! - baselineQuantity;
  int get baselineEpoch => row['baseline_epoch'] as int;
  int? get finalQuantity => row['final_quantity'] as int?;
  int? get valueDelta =>
      row['baseline_complete'] != 1 || row['final_complete'] != 1
      ? null
      : (row['final_value_micros'] as int) -
            (row['baseline_value_micros'] as int);

  /// Same moving-average estimate used by finalization. Unknown or stale total
  /// valuation stays unknown; completed sessions always use frozen results.
  int? get estimatedValueDelta {
    if (finalQuantity != null) return valueDelta;
    if (counted == null || row['baseline_complete'] != 1) return null;
    final before = row['baseline_value_micros'] as int;
    if (baselineQuantity == 0 && counted! > 0) {
      return row['valuation_quantity'] == counted
          ? row['empty_pool_total_micros'] as int?
          : null;
    }
    if (delta! < 0) {
      return -removalCost(
        quantity: baselineQuantity,
        valueMicros: before,
        remove: -delta!,
      );
    }
    final addition =
        BigInt.from(averageCost(baselineQuantity, before)) *
        BigInt.from(delta!);
    return addition + BigInt.from(before) > BigInt.from(9223372036854775807)
        ? null
        : addition.toInt();
  }
}

final class StocktakeDraft {
  StocktakeDraft(Map<String, Object?> row, List<StocktakeLine> lines)
    : row = Map.unmodifiable(row),
      lines = List.unmodifiable(lines);
  final Map<String, Object?> row;
  final List<StocktakeLine> lines;
  EntityId get id => EntityId(row['id'] as String);
  int get revision => row['revision'] as int;
  String get status => row['status'] as String;
  CurrencyPolicy get currency =>
      CurrencyPolicy.forCode(row['currency_code'] as String);
  bool get allCounted =>
      lines.isNotEmpty && lines.every((l) => l.counted != null);
}

final class StocktakeObservation {
  StocktakeObservation(Map<String, Object?> row) : row = Map.unmodifiable(row);
  final Map<String, Object?> row;
  EntityId get id => EntityId(row['id'] as String);
  EntityId get lineId => EntityId(row['line_id'] as String);
  int get baselineQuantity => row['baseline_quantity'] as int;
  int? get counted => row['counted_quantity'] as int?;
  bool get newBatch => row['baseline_batch_id'] == null;
  CalendarDate? get expiry {
    final date =
        row[newBatch ? 'observed_expiry' : 'baseline_expiry'] as String?;
    return date == null ? null : CalendarDate(date);
  }

  StockInput? get input => counted == null
      ? null
      : StockInput(
          row['input_count'] as int,
          unit: StockInputUnit.values.byName(row['input_unit'] as String),
          packSize: row['pack_size'] as int?,
          packLabel: row['pack_label'] as String?,
        );
}

final class StocktakeScanResult {
  const StocktakeScanResult(
    this.draft,
    this.lineId, {
    required this.needsBatchChoice,
  });
  final StocktakeDraft draft;
  final EntityId lineId;
  final bool needsBatchChoice;
}

final class StocktakeCursor {
  const StocktakeCursor(
    this.updatedAt,
    this.id,
    this.status,
    this.generation,
    this.databaseRevision,
  );
  final int updatedAt, generation, databaseRevision;
  final EntityId id;
  final String status;
}

final class StocktakeObservationCursor {
  const StocktakeObservationCursor(
    this.lineId,
    this.position,
    this.id,
    this.baselineEpoch,
    this.generation,
  );
  final EntityId lineId, id;
  final int position, baselineEpoch, generation;
}
