import 'package:sqflite/sqflite.dart';
import '../../../data/database/database_coordinator.dart';

/// Startup boundary. Opening/configuring SQLite belongs here, not in a widget.
/// No store data is seeded; only schema metadata/default settings are created.
abstract interface class FoundationReadiness {
  Future<void> check();
  Future<void> dispose();
}

final class FoundationService implements FoundationReadiness {
  // Public constructor labels describe dependencies without exposing fields.
  FoundationService({
    required Future<DatabaseCoordinator> Function() openDatabase,
    // ignore: prefer_initializing_formals
  }) : _openDatabase = openDatabase;
  final Future<DatabaseCoordinator> Function() _openDatabase;
  Future<DatabaseCoordinator>? _opening;
  bool _disposed = false;

  @override
  Future<void> check() async {
    if (_disposed) throw StateError('Service sudah ditutup.');
    final database = await (_opening ??= _openDatabase().catchError((
      Object error,
      StackTrace stack,
    ) {
      _opening = null;
      Error.throwWithStackTrace(error, stack);
    }));
    if (_disposed) {
      await database.close();
      throw StateError('Service sudah ditutup.');
    }
    await database.read((db) async {
      final foreignKeys = await db.rawQuery('PRAGMA foreign_keys');
      if (foreignKeys.single.values.single != 1) {
        throw StateError('Foreign key tidak aktif.');
      }
      await db.getVersion();
    });
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final opening = _opening;
    if (opening != null) {
      try {
        await (await opening).close();
      } catch (_) {
        // An opening failure has no live connection to dispose.
      }
    }
  }
}
