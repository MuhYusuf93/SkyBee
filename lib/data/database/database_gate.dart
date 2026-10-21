import 'package:kasir_platform/kasir_platform.dart';

/// Covers a complete operation, including opening/closing headless connections.
/// A SQL transaction alone cannot coordinate a file promotion with another engine.
abstract interface class DatabaseGate {
  Future<T> run<T>(Future<T> Function() action);
}

abstract interface class TryDatabaseGate implements DatabaseGate {
  Future<bool> tryRun(Future<void> Function() action);
}

/// Host/service fixtures have no native process boundary. Android never selects
/// this gate implicitly; ordinary composition uses the shared file lease.
final class DirectDatabaseGate implements TryDatabaseGate {
  const DirectDatabaseGate();
  @override
  Future<T> run<T>(Future<T> Function() action) => action();
  @override
  Future<bool> tryRun(Future<void> Function() action) async {
    await action();
    return true;
  }
}

final class AndroidDatabaseGate implements TryDatabaseGate {
  const AndroidDatabaseGate([
    this.platform = const KasirPlatform(),
    this.name = 'database',
  ]);
  final KasirPlatform platform;
  final String name;
  @override
  Future<bool> tryRun(Future<void> Function() action) async {
    final token = await platform.callNullable<String>('tryAcquire', {
      'name': name,
    });
    if (token == null) return false;
    try {
      await action();
      return true;
    } finally {
      await platform.release(token);
    }
  }

  @override
  Future<T> run<T>(Future<T> Function() action) async {
    final token = await platform.call<String>('acquire', {'name': name});
    try {
      return await action();
    } finally {
      await platform.release(token);
    }
  }
}
