import 'package:kasir_platform/kasir_platform.dart';

/// Covers a complete operation, including opening/closing headless connections.
/// A SQL transaction alone cannot coordinate a file promotion with another engine.
abstract interface class DatabaseGate {
  Future<T> run<T>(Future<T> Function() action);
}

final class AndroidDatabaseGate implements DatabaseGate {
  const AndroidDatabaseGate([
    this.platform = const KasirPlatform(),
    this.name = 'database',
  ]);
  final KasirPlatform platform;
  final String name;
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
