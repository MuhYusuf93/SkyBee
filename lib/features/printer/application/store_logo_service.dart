import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../data/database/database_coordinator.dart';
import '../../management/application/management_service.dart';

/// Logos are bounded immutable receipt assets. Replacing the shop logo never
/// changes a historical receipt; file selection does not bypass a relocked PIN.
final class StoreLogoService {
  const StoreLogoService(
    this.database,
    this.access, {
    this.platform = const KasirPlatform(),
  });
  final DatabaseCoordinator database;
  final ManagementService access;
  final KasirPlatform platform;
  Future<File?> choose() async {
    await access.authorizeCurrent();
    final path = p.join(
      p.dirname(database.databasePath),
      'm5_logo_${const Uuid().v4()}.input',
    );
    final result = await access.systemInteraction(
      () => platform.callNullable<String>('pickImport', {
        'path': path,
        'mime': 'image/*',
        'maxBytes': 4194304,
      }),
      discard: (result) async {
        if (result == path && await File(path).exists()) {
          await File(path).delete();
        }
      },
    );
    return result == null ? null : File(result);
  }

  static Future<Uint8List> normalize(Uint8List input) async {
    if (input.isEmpty || input.length > 4194304) {
      throw const FormatException('logoInvalid');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(input);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width, height = descriptor.height;
      if (width < 1 ||
          height < 1 ||
          width * height > 4194304 ||
          height * 576 / width > 1024) {
        throw const FormatException('logoInvalid');
      }
      codec = await descriptor.instantiateCodec(
        targetWidth: width.clamp(1, 576),
      );
      image = (await codec.getNextFrame()).image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null || png.lengthInBytes > 4194304) {
        throw const FormatException('logoInvalid');
      }
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  Future<void> apply(File selected) async {
    await access.authorizeCurrent();
    if (await selected.length() > 4194304) {
      throw const FormatException('logoInvalid');
    }
    final bytes = await normalize(await selected.readAsBytes());
    final hash = sha256.convert(bytes).toString();
    final output = File(
      p.join(p.dirname(database.databasePath), 'logos', '$hash.png'),
    );
    await output.parent.create(recursive: true);
    if (!await output.exists()) await output.writeAsBytes(bytes, flush: true);
    await database.transaction((dbTxn) async {
      await access.authorize(dbTxn);
      await dbTxn.rawInsert(
        'INSERT OR IGNORE INTO receipt_assets(hash,bytes) VALUES(?,?)',
        [hash, bytes],
      );
      await dbTxn.rawInsert(
        'INSERT OR IGNORE INTO m5_store(id,store_id) VALUES(1,?)',
        [const Uuid().v4()],
      );
      await dbTxn.update('m5_store', {'logo_asset': hash}, where: 'id=1');
      await dbTxn.update('store_settings', {
        'logo_path': output.path,
      }, where: 'id=1');
    });
  }

  Future<void> remove() => database.transaction((dbTxn) async {
    await access.authorize(dbTxn);
    await dbTxn.update('m5_store', {'logo_asset': null}, where: 'id=1');
    await dbTxn.update('store_settings', {'logo_path': null}, where: 'id=1');
  });
  Future<Uint8List?> current() async {
    await access.authorizeCurrent();
    return database.read((db) async {
      await access.authorize(db);
      final rows = await db.rawQuery(
        'SELECT a.bytes FROM m5_store s JOIN receipt_assets a ON a.hash=s.logo_asset WHERE s.id=1',
      );
      return rows.isEmpty ? null : rows.single['bytes'] as Uint8List;
    });
  }
}
