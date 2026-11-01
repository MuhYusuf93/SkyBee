import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/m53_retention_host_fixture.dart';
import 'package:kasir_app/features/backup/application/completed_snapshot_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late RetentionHostFixture f;
  late CompletedSnapshotSource verifier;
  setUp(() async {
    f = RetentionHostFixture();
    await f.initialize();
    verifier = CompletedSnapshotSource(f.database);
  });
  tearDown(() => f.dispose());
  test(
    'closed creation receipt allows only unchanged original bytes',
    () async {
      final manifest = await f.add(0), file = f.archive(manifest);
      final proof = await verifier.verify(file, manifest);
      await verifier.recheck(file, proof);
      await file.writeAsString('PUBLIC CHANGED', mode: FileMode.append);
      await expectLater(
        verifier.verify(file, manifest),
        throwsA(isA<CompletedSnapshotInvalid>()),
      );
      await expectLater(
        verifier.recheck(file, proof),
        throwsA(isA<CompletedSnapshotInvalid>()),
      );
    },
  );
  test(
    'missing file or missing encrypted creation receipt never authorizes resume',
    () async {
      final m = await f.add(0), file = f.archive(m);
      await file.delete();
      await expectLater(
        verifier.verify(file, m),
        throwsA(isA<CompletedSnapshotInvalid>()),
      );
      final other = await f.add(0);
      await f.database.exclusive(
        (db) =>
            db.delete('local_backups', where: 'id=?', whereArgs: [other.id]),
      );
      await expectLater(
        verifier.verify(f.archive(other), other),
        throwsA(isA<CompletedSnapshotInvalid>()),
      );
    },
  );
  test(
    'creation manifest key order may differ but its values and exact original path may not',
    () async {
      final m = await f.add(0), file = f.archive(m);
      Object? reverse(Object? value) {
        if (value is Map) {
          final keys = value.keys.cast<String>().toList().reversed;
          return {for (final key in keys) key: reverse(value[key])};
        }
        if (value is List) return value.map(reverse).toList();
        return value;
      }

      await f.database.exclusive(
        (db) => db.update(
          'local_backups',
          {'manifest_json': jsonEncode(reverse(m.values))},
          where: 'id=?',
          whereArgs: [m.id],
        ),
      );
      await verifier.verify(file, m);
      await f.database.exclusive(
        (db) => db.update(
          'local_backups',
          {'archive_path': 'PUBLIC-OTHER.kasirbackup'},
          where: 'id=?',
          whereArgs: [m.id],
        ),
      );
      await expectLater(
        verifier.verify(file, m),
        throwsA(isA<CompletedSnapshotInvalid>()),
      );
    },
  );
  test(
    'another current store or altered creation manifest is rejected',
    () async {
      final m = await f.add(0), file = f.archive(m);
      await f.database.exclusive(
        (db) => db.update(
          'local_backups',
          {'manifest_json': '{}'},
          where: 'id=?',
          whereArgs: [m.id],
        ),
      );
      await expectLater(
        verifier.verify(file, m),
        throwsA(isA<CompletedSnapshotInvalid>()),
      );
      final other = await f.add(0);
      await f.database.exclusive(
        (db) =>
            db.update('m5_store', {'store_id': 'PUBLIC-OTHER'}, where: 'id=1'),
      );
      await expectLater(
        verifier.verify(f.archive(other), other),
        throwsA(isA<CompletedSnapshotInvalid>()),
      );
    },
  );
}
