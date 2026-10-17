import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'schema.dart';
import 'database_gate.dart';
import 'encrypted_database.dart';

final class DatabaseReplacement {
  const DatabaseReplacement(this.generation, this.succeeded);
  final int generation;
  final bool succeeded;
}

/// Owns one lazy connection and serializes operation lifetimes. Services may
/// coordinate repositories in a single dbTxn; widgets/Providers never get SQL.
/// A future backup/restore must enter [exclusive] instead of copying a live DB.
final class DatabaseCoordinator {
  DatabaseCoordinator({
    required DatabaseFactory factory,
    required String databasePath,
    this.schemaVersion = Schema.version,
    this.gate,
    this.encryption,
    this.closeAfterOperation = false,
    // ignore: prefer_initializing_formals
  }) : _factory = factory,
       _path = databasePath;
  final DatabaseFactory _factory;
  final String _path;
  final int schemaVersion;
  final DatabaseGate? gate;
  final EncryptedDatabase? encryption;
  final bool closeAfterOperation;
  bool _bootstrapped = false;
  String get databasePath => _path;
  Database? _database;
  Future<void> _tail = Future.value();
  bool _closed = false;
  final _commits = StreamController<int>.broadcast();
  int _revision = 0;
  int _generation = 0;
  int get generation => _generation;
  final _replacements = StreamController<DatabaseReplacement>.broadcast();
  final _inventoryChanges = StreamController<int>.broadcast();
  Stream<int> get inventoryChanges => _inventoryChanges.stream;
  Stream<DatabaseReplacement> get replacements => _replacements.stream;
  int get revision => _revision;

  /// Route-scoped readers invalidate mutable cursor sessions after a successful
  /// dbTxn. Rollbacks emit nothing; no feature state lives in this coordinator.
  Stream<int> get commits => _commits.stream;

  /// A manual acceptance fixture and its headless worker must select the same
  /// fresh sandbox DB. The override is compile-time and entirely ignored by an
  /// ordinary build; existing sandbox/operational files are never reset.
  static const androidDatabaseName =
      bool.fromEnvironment('KASIR_INTEGRATION_TEST')
      ? String.fromEnvironment(
          'KASIR_FIXTURE_DATABASE',
          defaultValue: 'kasir_app.db',
        )
      : 'kasir_app.db';

  static Future<DatabaseCoordinator> android({
    bool headless = false,
    String databaseName = androidDatabaseName,
  }) async {
    if (databaseName != 'kasir_app.db' &&
        (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
            !RegExp(
              r'^m5_(?:worker|acceptance)_[0-9]{1,20}\.db$',
            ).hasMatch(databaseName))) {
      throw StateError('fixtureDatabaseNotAllowed');
    }
    final location = path.join(await getDatabasesPath(), databaseName);
    return DatabaseCoordinator(
      factory: databaseFactory,
      databasePath: location,
      gate: const AndroidDatabaseGate(),
      encryption: EncryptedDatabase(
        location,
        keyName: databaseName == 'kasir_app.db'
            ? 'database-v1'
            : 'fixture-${databaseName.replaceAll('.', '-')}',
      ),
      closeAfterOperation: headless,
    );
  }

  Future<T> _serialize<T>(
    Future<T> Function() action, {
    bool acceptReplacement = false,
    int? generation,
  }) {
    final expectedGeneration = generation ?? _generation;
    Future<T> perform() async {
      if (!acceptReplacement && expectedGeneration != _generation) {
        throw StateError('databaseReplacedRetry');
      }
      try {
        return await action();
      } finally {
        if (closeAfterOperation) {
          await _database?.close();
          _database = null;
        }
      }
    }

    final result = _tail.then(
      (_) => gate == null ? perform() : gate!.run(perform),
    );
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Database> _open() async {
    if (_closed) throw StateError('Database sudah ditutup.');
    if (!_bootstrapped && encryption != null) {
      await encryption!.bootstrap();
      _bootstrapped = true;
    }
    if (_database != null) return _database!;
    final options = OpenDatabaseOptions(
      version: schemaVersion,
      singleInstance: false,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        // Android SQLiteDatabase rejects result-producing PRAGMAs via
        // execute(), even when assignment syntax is used.
        await db.rawQuery('PRAGMA busy_timeout = 5000');
      },
      onCreate: (db, version) => Schema.migrate(db, 0, version),
      onUpgrade: Schema.migrate,
      onDowngrade: (db, oldVersion, newVersion) async {
        throw StateError('Downgrade skema ditolak agar data tetap aman.');
      },
    );
    return _database =
        await (encryption?.open(options) ??
            _factory.openDatabase(_path, options: options));
  }

  /// Do not nest coordinator calls inside the callback: use its db/dbTxn.
  Future<T> read<T>(Future<T> Function(Database db) operation) =>
      _serialize(() async => operation(await _open()));

  /// Errors rollback all SQL in the callback; no device/network work inside.
  Future<T> transaction<T>(
    Future<T> Function(Transaction dbTxn) operation, {
    bool inventoryChanged = false,
    int? expectedGeneration,
  }) => _serialize(() async {
    final result = await (await _open()).transaction(operation);
    _commits.add(++_revision);
    if (inventoryChanged) _inventoryChanges.add(_revision);
    return result;
  }, generation: expectedGeneration);

  /// Gates ordinary readers/writers, including queued operations, for future
  /// maintenance. This is a boundary, not a backup implementation.
  Future<T> exclusive<T>(Future<T> Function(Database db) operation) =>
      read(operation);

  /// Maintenance owns the gate after closing the live connection. The callback
  /// must use private staging connections and must not re-enter this coordinator.
  Future<T> maintenance<T>(Future<T> Function(String path) operation) =>
      _serialize(() async {
        await _database?.close();
        _database = null;
        var success = false;
        try {
          final result = await operation(_path);
          success = true;
          return result;
        } finally {
          _bootstrapped = false;
          _generation++;
          _commits.add(++_revision);
          _replacements.add(DatabaseReplacement(_generation, success));
        }
      });

  /// Drain in-flight work then close. Subsequent operations are rejected.
  Future<void> close() => _serialize(() async {
    _closed = true;
    await _database?.close();
    _database = null;
    unawaited(_commits.close());
    unawaited(_replacements.close());
    unawaited(_inventoryChanges.close());
  }, acceptReplacement: true);
}
