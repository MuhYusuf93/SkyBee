import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../data/repositories/product_code_resolver.dart';
import '../../management/application/management_service.dart';
import '../../printer/domain/printer_profile.dart';
import '../domain/product_label.dart';
import 'qr_label_layout.dart';

final class ProductLabelPrinter {
  const ProductLabelPrinter(
    this.id,
    this.name,
    this.hardware,
    this.media,
    this.revision,
  );
  final String id, name;
  final PrinterProfile hardware;
  final ProductLabelProfile media;
  final int revision;
}

/// Inventory capability owns label configuration and preparation. The existing
/// persistent print queue/output lease performs transport only after commit.
final class ProductLabelService {
  const ProductLabelService(this.database, this.access);
  final DatabaseCoordinator database;
  final ManagementService access;
  // Bound public label text only. Existing master values are neither truncated
  // nor rewritten, and the complete stable QR identity is never shortened.
  static String _labelText(String value, int maximum) {
    if (value.length <= maximum) return value;
    var end = maximum;
    final last = value.codeUnitAt(end - 1);
    if (last >= 0xd800 && last <= 0xdbff) {
      end--;
    }
    return value.substring(0, end);
  }

  Future<T> _read<T>(Future<T> Function(DatabaseExecutor db) work) async {
    access.requireAccess(capability: ManagementCapability.inventory);
    final generation = access.generation, store = database.generation;
    return database.read((db) async {
      await access.authorize(db, capability: ManagementCapability.inventory);
      final value = await work(db);
      await access.authorize(db, capability: ManagementCapability.inventory);
      if (generation != access.generation || store != database.generation) {
        throw const AppError('m3DraftChanged');
      }
      return value;
    });
  }

  Future<T> _write<T>(Future<T> Function(Transaction db) work) {
    final generation = access.generation, store = database.generation;
    return database.transaction((db) async {
      await access.authorize(db, capability: ManagementCapability.inventory);
      if (generation != access.generation || store != database.generation) {
        throw const AppError('m3DraftChanged');
      }
      final value = await work(db);
      await access.authorize(db, capability: ManagementCapability.inventory);
      if (generation != access.generation || store != database.generation) {
        throw const AppError('m3DraftChanged');
      }
      return value;
    });
  }

  ProductLabelPrinter _printer(Map<String, Object?> row) {
    final hardware = PrinterProfile.fromJson(
      jsonDecode(row['settings_json'] as String) as Map<String, dynamic>,
    );
    final label = row['label_json'];
    return ProductLabelPrinter(
      row['device_id'] as String,
      row['name'] as String,
      hardware,
      label == null
          ? ProductLabelProfile(protocol: hardware.protocol)
          : ProductLabelProfile.fromJson(
              jsonDecode(label as String) as Map<String, dynamic>,
            ),
      (row['label_revision'] as int?) ?? 0,
    );
  }

  static const _printers =
      '''SELECT p.*,l.settings_json AS label_json,l.revision AS label_revision FROM printer_profiles p LEFT JOIN product_label_profiles l ON l.device_id=p.device_id''';
  Future<List<ProductLabelPrinter>> printers({String? after}) => _read(
    (db) async => (await db.rawQuery(
      '$_printers ${after == null ? '' : 'WHERE p.device_id>?'} ORDER BY p.device_id COLLATE BINARY LIMIT 20',
      [?after],
    )).map(_printer).toList(),
  );
  Future<ProductLabelPrinter> printer(String id) => _read((db) async {
    final rows = await db.rawQuery('$_printers WHERE p.device_id=?', [id]);
    if (rows.length != 1) throw const AppError('m53LabelPrinterMissing');
    return _printer(rows.single);
  });
  Future<int> saveProfile(
    String device,
    ProductLabelProfile value,
    int expectedRevision,
  ) => _write((db) async {
    final rows = await db.rawQuery('$_printers WHERE p.device_id=?', [device]);
    if (rows.length != 1) throw const AppError('m53LabelPrinterMissing');
    final previous = _printer(rows.single);
    value.validate(hardware: previous.hardware);
    if (previous.revision != expectedRevision) {
      throw const AppError('m53LabelProfileChanged');
    }
    final values = {
      'revision': expectedRevision + 1,
      'settings_json': jsonEncode(value.toJson()),
      'updated_at': access.clock.milliseconds,
    };
    if (expectedRevision == 0) {
      await db.insert('product_label_profiles', {
        'device_id': device,
        ...values,
      });
    } else {
      await db.update(
        'product_label_profiles',
        values,
        where: 'device_id=? AND revision=?',
        whereArgs: [device, expectedRevision],
      );
    }
    await access.audit(db, 'product_label_profile_saved', entityId: device);
    return expectedRevision + 1;
  });
  Future<ProductLabelSnapshot> _snapshot(
    DatabaseExecutor db,
    EntityId id,
    int? revision,
    String? language,
  ) async {
    final rows = await db.query(
      'products',
      columns: [
        'id',
        'revision',
        'name',
        'sku',
        'selling_price_rupiah',
        'currency_code',
        'currency_scale',
        'is_deleted',
      ],
      where: 'id=?',
      whereArgs: [id.value],
    );
    if (rows.length != 1 || rows.single['is_deleted'] != 0) {
      throw const AppError('productNotFound');
    }
    final row = rows.single;
    if (revision != null && row['revision'] != revision) {
      throw const AppError('m53LabelProductChanged');
    }
    final settings = (await db.query(
      'store_settings',
      columns: ['ui_language'],
    )).single;
    final value = ProductLabelSnapshot(
      product: id,
      productRevision: row['revision'] as int,
      name: _labelText(row['name'] as String, 200),
      sku: _labelText(row['sku'] as String, 120),
      price: Money(
        row['selling_price_rupiah'] as int,
        row['currency_code'] as String,
        row['currency_scale'] as int,
      ),
      // UI supplies its resolved locale when legacy preference is null. Headless
      // callers have an explicit deterministic Indonesian fallback.
      language: language ?? settings['ui_language'] as String? ?? 'id',
      capturedAt: access.clock.milliseconds,
    );
    final resolved = await ProductCodeResolver.lookup(db, value.code);
    if (resolved.length != 1 || resolved.single['id'] != id.value) {
      throw const AppError('m3AmbiguousCode');
    }
    return value;
  }

  Future<ProductLabelSnapshot> snapshot(EntityId id, {String? language}) =>
      _read((db) => _snapshot(db, id, null, language));
  Future<String> prepare(
    EntityId product,
    int expectedRevision,
    String device,
    ProductLabelProfile media,
    int copies, {
    required String operationKey,
    String? language,
  }) => _write((db) async {
    if (operationKey.isEmpty ||
        operationKey.length > 200 ||
        operationKey != operationKey.trim()) {
      throw const AppError('m3AttemptChanged');
    }
    if (copies < 1 || copies > 100) {
      throw const AppError('m53LabelCopiesInvalid');
    }
    final key = 'label:$operationKey',
        hash = sha256
            .convert(
              utf8.encode(
                jsonEncode([
                  product.value,
                  expectedRevision,
                  device,
                  media.toJson(),
                  copies,
                  language,
                ]),
              ),
            )
            .toString();
    final old = await db.query(
      'print_jobs',
      where: 'operation_key=?',
      whereArgs: [key],
    );
    if (old.isNotEmpty) {
      final original =
          jsonDecode(old.single['snapshot_json'] as String)
              as Map<String, dynamic>;
      if (original['labelIntentHash'] != hash) {
        throw const AppError('m3AttemptChanged');
      }
      return old.single['id'] as String;
    }
    final profiles = await db.query(
      'printer_profiles',
      where: 'device_id=?',
      whereArgs: [device],
    );
    if (profiles.length != 1) throw const AppError('m53LabelPrinterMissing');
    final hardware = PrinterProfile.fromJson(
      jsonDecode(profiles.single['settings_json'] as String)
          as Map<String, dynamic>,
    );
    final value = await _snapshot(db, product, expectedRevision, language);
    // Fit is checked before committing a job or connecting to any printer.
    QrLabelLayout(value, media, hardware);
    final id = const IdGenerator().next().value,
        now = access.clock.milliseconds;
    await db.insert('print_jobs', {
      'id': id,
      'operation_key': key,
      'device_id': device,
      'profile_json': jsonEncode(hardware.toJson()),
      'snapshot_json': jsonEncode({
        'productLabel': value.toJson(),
        'labelProfile': media.toJson(),
        'copies': copies,
        'labelIntentHash': hash,
      }),
      'status': 'prepared',
      'created_at': now,
      'updated_at': now,
    });
    await access.audit(db, 'product_labels_prepared', entityId: id);
    return id;
  });
}
