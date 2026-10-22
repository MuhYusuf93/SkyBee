import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../../../core/domain/app_error.dart';
import '../../../data/database/database_coordinator.dart';
import '../../backup/application/backup_service.dart';
import '../../management/application/management_service.dart';
import '../domain/printer_profile.dart';
import 'print_queue_service.dart';
import 'receipt_layout.dart';

final class RecoveryPrintTarget {
  const RecoveryPrintTarget(this.deviceId, this.name, this.profile);
  final String deviceId, name;
  final PrinterProfile profile;
  String get identity => sha256
      .convert(utf8.encode(jsonEncode([deviceId, name, profile.toJson()])))
      .toString();
}

enum RecoveryPrintOutcome { submitted, notSent, unknown }

/// A volatile, fresh-authorized output path. It deliberately never calls
/// prepare()/print_jobs, receipt snapshots, backup rotation or clipboard APIs.
/// A completed write still needs a human paper check; unknown never retries.
final class RecoveryPrintService {
  RecoveryPrintService(this.database, this.access, this.backups, this.queue);
  final DatabaseCoordinator database;
  final ManagementService access;
  final BackupService backups;
  final PrintQueueService queue;
  bool _busy = false;

  Future<RecoveryPrintTarget> target() => database.read((db) async {
    await access.authorize(db);
    final rows = await db.query(
      'printer_profiles',
      where: 'selected=1',
      limit: 1,
    );
    if (rows.isEmpty) throw const AppError('m51RecoveryPrinterRequired');
    final row = rows.single;
    final result = RecoveryPrintTarget(
      row['device_id'] as String,
      row['name'] as String,
      PrinterProfile.fromJson(
        jsonDecode(row['settings_json'] as String) as Map<String, dynamic>,
      ),
    );
    await access.authorize(db);
    return result;
  });

  Future<RecoveryPrintOutcome> print(
    RecoveryPrintTarget confirmedTarget, {
    required bool confirmed,
    required String language,
  }) async {
    if (!confirmed) {
      access.clearFresh('recoveryPrint');
      throw const AppError('m5Cancelled');
    }
    if (_busy) throw const AppError('m51SystemOperationPending');
    access.requireFresh('recoveryPrint');
    _busy = true;
    var mayHaveWritten = false;
    FreshActionProof? claim;
    try {
      // The closure does not capture recovery material. Fetch only after the
      // whole-output lease, and validate fresh auth again if the queue waited.
      return await queue.serialOutput(() async {
        var attempted = false;
        Future<void> guard() async {
          if (queue.suspended) throw const AppError('m5OperationFailed');
          await access.authorizeCurrent();
          final owned = claim;
          if (owned == null) {
            access.requireFresh('recoveryPrint');
          } else {
            access.requireClaim(owned, 'recoveryPrint');
          }
        }

        Future<void> write(Uint8List bytes) async {
          try {
            await guard();
            attempted = true;
            mayHaveWritten = true;
            await queue.transport.write(bytes);
          } finally {
            bytes.fillRange(0, bytes.length, 0);
          }
        }

        try {
          await guard();
          if ((await target()).identity != confirmedTarget.identity) {
            throw const AppError('m51RecoveryPrinterChanged');
          }
          await queue.transport.connect(confirmedTarget.deviceId);
          claim = access.claimFresh('recoveryPrint');
          final code = await backups.recoveryForPrint(claim: claim);
          final layout = ReceiptLayout.recovery(
            code,
            confirmedTarget.profile,
            language: language,
            createdAt: access.clock.now,
          );
          await write(Uint8List.fromList([0x1b, 0x40]));
          await for (final tile in layout.tiles()) {
            late Uint8List bytes;
            try {
              bytes = await ReceiptLayout.encodeTile(tile, sensitive: true);
            } finally {
              tile.dispose();
            }
            try {
              for (var at = 0; at < bytes.length; at += 4096) {
                // Copy: the write helper can wipe its own chunk without
                // altering data needed by a subsequent chunk.
                await write(
                  Uint8List.fromList(
                    bytes.sublist(at, (at + 4096).clamp(0, bytes.length)),
                  ),
                );
              }
            } finally {
              bytes.fillRange(0, bytes.length, 0);
            }
          }
          if (confirmedTarget.profile.feed > 0) {
            await write(
              Uint8List.fromList(List.filled(confirmedTarget.profile.feed, 10)),
            );
          }
          return RecoveryPrintOutcome.submitted;
        } catch (_) {
          return attempted
              ? RecoveryPrintOutcome.unknown
              : RecoveryPrintOutcome.notSent;
        } finally {
          try {
            await queue.transport.disconnect();
          } catch (_) {
            // Do not reinterpret or retry bytes after a disconnect error.
          }
        }
      });
    } catch (_) {
      // A release/engine error after the body finished can still follow bytes
      // accepted by the printer; never present that as safe automatic retry.
      return mayHaveWritten
          ? RecoveryPrintOutcome.unknown
          : RecoveryPrintOutcome.notSent;
    } finally {
      _busy = false;
      if (claim != null) access.releaseClaim(claim!);
      access.clearFresh('recoveryPrint');
    }
  }

  /// Only a boolean acknowledgment event; no key/fingerprint/printer payload.
  Future<void> acknowledgeStoredCopy() => database.transaction((db) async {
    await access.authorize(db);
    await access.audit(db, 'backup_recovery_copy_stored_confirmed');
  });
}
