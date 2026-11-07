import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/app_error.dart';
import '../../../data/database/database_coordinator.dart';
import '../../cashier/application/cashier_store.dart';
import '../../management/application/management_service.dart';

/// Only the immutable normalized image is persisted inside SQLCipher. Pixels
/// are preserved at full size including all margins around the user's code.
final class QrisImageAsset {
  QrisImageAsset._(Uint8List bytes, this.width, this.height)
    : bytes = bytes.asUnmodifiableView(),
      hash = sha256.convert(bytes).toString();
  final Uint8List bytes;
  final int width, height;
  final String hash;
}

final class QrisAssetService {
  const QrisAssetService(this.database, this.access, this.store, this.platform);
  final DatabaseCoordinator database;
  final ManagementService access;
  final CashierStore store;
  final KasirPlatform platform;
  static const _maxBytes = 4194304;
  static const _invalid = AppError('m54QrisImageInvalid');

  Future<QrisImageAsset?> choose() async {
    await access.authorizeCurrent();
    final selected = File(
      path.join(
        path.dirname(database.databasePath),
        'm54_qris_${const Uuid().v4()}.input',
      ),
    );
    try {
      final result = await access.systemInteraction(
        () => platform.callNullable<String>('pickImport', {
          'path': selected.path,
          'mime': 'image/*',
          'maxBytes': _maxBytes,
        }),
      );
      if (result == null) return null;
      if (result != selected.path ||
          !await selected.exists() ||
          await selected.length() > _maxBytes) {
        throw _invalid;
      }
      final asset = await normalize(await selected.readAsBytes());
      await access.authorizeCurrent();
      return asset;
    } finally {
      if (await selected.exists()) await selected.delete();
    }
  }

  static Future<QrisImageAsset> normalize(Uint8List input) async {
    if (input.isEmpty || input.length > _maxBytes) throw _invalid;
    final buffer = await ui.ImmutableBuffer.fromUint8List(input);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width, height = descriptor.height;
      if (width < 64 ||
          height < 64 ||
          width > 4096 ||
          height > 4096 ||
          width * height > _maxBytes) {
        throw _invalid;
      }
      codec = await descriptor.instantiateCodec();
      if (codec.frameCount != 1) throw _invalid;
      image = (await codec.getNextFrame()).image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null || png.lengthInBytes > _maxBytes) throw _invalid;
      return QrisImageAsset._(
        png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        width,
        height,
      );
    } catch (_) {
      throw _invalid;
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  Future<void> save(QrisImageAsset? value, {required String? expectedHash}) =>
      database.transaction((dbTxn) async {
        await access.authorize(dbTxn);
        if (database.schemaVersion < 43) throw _invalid;
        final current = (await dbTxn.query(
          'store_qris_asset',
          columns: ['hash'],
          where: 'id=1',
        )).firstOrNull?['hash'];
        if (current != expectedHash) {
          throw const AppError('m54QrisImageChanged');
        }
        if (value == null) {
          await dbTxn.delete('store_qris_asset', where: 'id=1');
        } else {
          await dbTxn.insert('store_qris_asset', {
            'id': 1,
            'bytes': value.bytes,
            'hash': value.hash,
            'width': value.width,
            'height': value.height,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await access.audit(
          dbTxn,
          value == null ? 'qris_image_removed' : 'qris_image_saved',
        );
        await access.authorize(dbTxn);
      });

  Future<QrisImageAsset?> ownerImage() => database.read((db) async {
    await access.authorize(db);
    final image = await _imageOn(db);
    await access.authorize(db);
    return image;
  });

  Future<Uint8List?> checkoutImage() =>
      store.read(database, (db) async => (await _imageOn(db))?.bytes);

  Future<QrisImageAsset?> _imageOn(DatabaseExecutor db) async {
    if (database.schemaVersion < 43) return null;
    final row = (await db.query(
      'store_qris_asset',
      columns: ['bytes', 'width', 'height'],
      where: 'id=1',
    )).firstOrNull;
    return row == null
        ? null
        : QrisImageAsset._(
            row['bytes'] as Uint8List,
            row['width'] as int,
            row['height'] as int,
          );
  }

  static Future<void> validate(DatabaseExecutor db) async {
    const invalid = FormatException('backupQrisImageInvalid');
    if ((await db.rawQuery('''SELECT 1 FROM store_qris_asset WHERE id<>1 OR
      typeof(bytes)<>'blob' OR length(bytes) NOT BETWEEN 1 AND 4194304 OR
      typeof(width)<>'integer' OR typeof(height)<>'integer' OR width NOT BETWEEN 64 AND 4096 OR
      height NOT BETWEEN 64 AND 4096 OR width*height>4194304 OR
      typeof(hash)<>'text' OR length(hash)<>64 LIMIT 1''')).isNotEmpty) {
      throw invalid;
    }
    final rows = await db.query('store_qris_asset', limit: 2);
    if (rows.isEmpty) return;
    if (rows.length != 1) throw invalid;
    final row = rows.single;
    final bytes = row['bytes'] as Uint8List;
    if (sha256.convert(bytes).toString() != row['hash']) throw invalid;
    try {
      final asset = await normalize(bytes);
      if (asset.width != row['width'] || asset.height != row['height']) {
        throw invalid;
      }
    } catch (_) {
      throw invalid;
    }
  }
}
