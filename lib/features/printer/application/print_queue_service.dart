import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../cashier/application/checkout_service.dart';
import '../../management/application/management_service.dart';
import '../domain/printer_profile.dart';
import 'printer_transport.dart';
import 'receipt_layout.dart';
import 'receipt_snapshots.dart';
import 'printer_output_gate.dart';

final class SalePrintPreview {
  const SalePrintPreview(this.layout, this.logo);
  final ReceiptLayout layout;
  final Uint8List? logo;
}

/// Persistent, serial post-commit side effects. A lease is claimed by SQL CAS;
/// a second tap/instance cannot send it twice. In-flight jobs become unknown on
/// startup, are never automatically retried, and never call checkout or stock.
final class PrintQueueService {
  PrintQueueService(
    this.database,
    this.checkout,
    this.access,
    this.transport, {
    PrinterOutputGate? outputGate,
  }) : outputGate = outputGate ?? defaultPrinterOutputGate();
  final DatabaseCoordinator database;
  final CheckoutService checkout;
  final ManagementService access;
  final PrinterTransport transport;
  final PrinterOutputGate outputGate;
  PrinterOutputLease? _restoreLease;
  Future<void> _tail = Future.value();
  bool _suspended = false;
  bool get suspended => _suspended;
  Future<void> pauseForRestore() async {
    _suspended = true;
    try {
      await transport.disconnect();
    } catch (_) {
      /* an in-flight send remains ambiguous */
    }
    await _tail;
    // Restore cannot promote data while another engine is printing. Acquire
    // before the database maintenance lease to avoid printer→DB lock inversion.
    _restoreLease = await outputGate.acquire();
  }

  Future<void> resumeAfterRestore() async {
    final lease = _restoreLease;
    _restoreLease = null;
    await lease?.release();
    _suspended = false;
  }

  static const ids = Uuid();
  Future<SalePrintPreview> preview(
    EntityId saleId, {
    bool copy = false,
    bool management = false,
  }) async {
    if (management) await access.authorizeCurrent();
    final receipt = await checkout.receipt(saleId);
    return database.transaction((dbTxn) async {
      if (management) await access.authorize(dbTxn);
      final selected = await dbTxn.query(
        'printer_profiles',
        where: 'selected=1',
        limit: 1,
      );
      final profile = selected.isEmpty
          ? const PrinterProfile()
          : PrinterProfile.fromJson(
              jsonDecode(selected.single['settings_json'] as String)
                  as Map<String, dynamic>,
            );
      final snapshot = await ReceiptSnapshots.record(
        dbTxn,
        receipt,
        legacy: true,
      );
      final cancelled = (await dbTxn.query(
        'sale_transaction_reversals',
        columns: ['id'],
        where: 'sale_transaction_id=?',
        whereArgs: [saleId.value],
        limit: 1,
      )).isNotEmpty;
      Uint8List? logo;
      if (snapshot['logoHash'] != null) {
        final row = (await dbTxn.query(
          'receipt_assets',
          columns: ['bytes'],
          where: 'hash=?',
          whereArgs: [snapshot['logoHash']],
        )).single;
        logo = row['bytes'] as Uint8List;
      }
      final preview = SalePrintPreview(
        ReceiptLayout.sale(
          {...snapshot, 'cancelled': cancelled},
          profile,
          copy: copy,
        ),
        logo,
      );
      if (management) await access.authorize(dbTxn);
      return preview;
    });
  }

  Future<void> recoverInterrupted() => database.exclusive((db) async {
    await db.update('print_jobs', {
      'status': 'unknown',
      'error_code': 'process_interrupted',
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, where: "status='sending'");
  });

  /// Cashier receipts/copies stay public. History explicitly supplies management
  /// context so a late confirmation cannot bypass PIN revocation on that route.
  Future<String> prepare(
    EntityId saleId, {
    bool copy = false,
    bool management = false,
  }) async {
    if (management) await access.authorizeCurrent();
    // Service receipt existence is the commit boundary. No draft can be printed.
    final receipt = await checkout.receipt(saleId);
    return database.transaction((dbTxn) async {
      if (management) await access.authorize(dbTxn);
      final chosen = await dbTxn.query(
        'printer_profiles',
        where: 'selected=1',
        limit: 1,
      );
      if (chosen.isEmpty) throw StateError('printerNotConfigured');
      final snapshot = await ReceiptSnapshots.record(
        dbTxn,
        receipt,
        legacy: true,
      );
      final reversed = (await dbTxn.query(
        'sale_transaction_reversals',
        columns: ['id'],
        where: 'sale_transaction_id=?',
        whereArgs: [saleId.value],
        limit: 1,
      )).isNotEmpty;
      final id = ids.v4(), now = DateTime.now().millisecondsSinceEpoch;
      final operation = copy ? 'copy:$id' : 'first:${saleId.value}';
      final profile = chosen.single;
      await dbTxn.insert('print_jobs', {
        'id': id,
        'operation_key': operation,
        'sale_transaction_id': saleId.value,
        'device_id': profile['device_id'],
        'profile_json': profile['settings_json'],
        'snapshot_json': jsonEncode({
          ...snapshot,
          'copy': copy,
          'cancelled': reversed,
        }),
        'status': 'prepared',
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final preparedId =
          (await dbTxn.query(
                'print_jobs',
                columns: ['id'],
                where: 'operation_key=?',
                whereArgs: [operation],
              )).single['id']
              as String;
      if (management) await access.authorize(dbTxn);
      return preparedId;
    });
  }

  Future<String> prepareCalibration() => database.transaction((dbTxn) async {
    await access.authorize(dbTxn);
    final selected = await dbTxn.query(
      'printer_profiles',
      where: 'selected=1',
      limit: 1,
    );
    if (selected.isEmpty) throw StateError('printerNotConfigured');
    final id = ids.v4(), now = DateTime.now().millisecondsSinceEpoch;
    final shop = await dbTxn.query(
      'm5_store',
      columns: ['logo_asset'],
      where: 'id=1',
    );
    await dbTxn.insert('print_jobs', {
      'id': id,
      'operation_key': 'test:$id',
      'device_id': selected.single['device_id'],
      'profile_json': selected.single['settings_json'],
      'snapshot_json': jsonEncode({
        'test': true,
        'logoHash': shop.firstOrNull?['logo_asset'],
      }),
      'status': 'prepared',
      'created_at': now,
      'updated_at': now,
    });
    await access.authorize(dbTxn);
    return id;
  });
  Future<Map<String, Object?>> job(String id) => database.read(
    (db) async => Map.unmodifiable(
      (await db.query('print_jobs', where: 'id=?', whereArgs: [id])).single,
    ),
  );
  Future<void> _status(String id, String status, [String? error]) =>
      database.exclusive((db) async {
        await db.update(
          'print_jobs',
          {
            'status': status,
            'error_code': error,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id=?',
          whereArgs: [id],
        );
      });

  /// Only closures, never a persistent secret payload. Sensitive operations
  /// fetch their recovery material after owning this same whole-output lease.
  Future<T> serialOutput<T>(Future<T> Function() action) {
    final operation = _tail.then((_) => withPrinterOutput(outputGate, action));
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<String> send(String id) => serialOutput(() => _send(id));

  Future<String> _send(String id) async {
    if (_suspended) return 'cancelled';
    final claimed = await database.exclusive(
      (db) => db.update(
        'print_jobs',
        {
          'status': 'sending',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: "id=? AND status='prepared'",
        whereArgs: [id],
      ),
    );
    if (claimed != 1) return (await job(id))['status'] as String;
    var attempted = false;
    try {
      final row = await job(id);
      final profile = PrinterProfile.fromJson(
        jsonDecode(row['profile_json'] as String) as Map<String, dynamic>,
      );
      final snapshot =
          jsonDecode(row['snapshot_json'] as String) as Map<String, dynamic>;
      final layout = snapshot['test'] == true
          ? ReceiptLayout.calibration(profile)
          : ReceiptLayout.sale(
              snapshot,
              profile,
              copy: snapshot['copy'] == true,
            );
      Uint8List? logo;
      if (snapshot['logoHash'] != null) {
        logo = await database.read((db) async {
          final rows = await db.query(
            'receipt_assets',
            columns: ['bytes'],
            where: 'hash=?',
            whereArgs: [snapshot['logoHash']],
          );
          if (rows.isEmpty) throw StateError('receiptLogoMissing');
          return rows.single['bytes'] as Uint8List;
        });
      }
      await transport.connect(row['device_id'] as String);
      attempted = true;
      await transport.write(Uint8List.fromList([0x1b, 0x40]));
      await for (final tile in layout.tiles(logo: logo)) {
        late Uint8List bytes;
        try {
          bytes = await ReceiptLayout.encodeTile(tile);
        } finally {
          tile.dispose();
        }
        for (var i = 0; i < bytes.length; i += 4096) {
          await transport.write(
            Uint8List.sublistView(bytes, i, (i + 4096).clamp(0, bytes.length)),
          );
        }
      }
      if (profile.feed > 0) {
        await transport.write(
          Uint8List.fromList(List.filled(profile.feed, 10)),
        );
      }
      await _status(id, 'submitted');
      return 'submitted';
    } catch (_) {
      final state = attempted ? 'unknown' : 'failed';
      await _status(id, state, attempted ? 'delivery_ambiguous' : 'not_sent');
      return state;
    } finally {
      try {
        await transport.disconnect();
      } catch (_) {
        /* delivery status remains conservative */
      }
    }
  }
}
