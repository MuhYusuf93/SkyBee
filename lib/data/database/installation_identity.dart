import 'package:sqflite/sqflite.dart';
import '../../core/domain/value_types.dart';

/// Historic audit foreign keys remain intact after restore. Only the explicit
/// current-installation pointer changes; row order must never select an origin.
final class InstallationIdentity {
  static Future<String> current(DatabaseExecutor db, int now) async {
    final modern = (await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name='active_installation'",
    )).isNotEmpty;
    if (modern) {
      final current = await db.query('active_installation', where: 'id=1');
      if (current.isNotEmpty) {
        return current.single['installation_id'] as String;
      }
    }
    final previous = await db.query(
      'installation_metadata',
      orderBy: 'created_at,id COLLATE BINARY',
      limit: 1,
    );
    final id = previous.isEmpty
        ? const IdGenerator().next().value
        : previous.single['id'] as String;
    if (previous.isEmpty) {
      await db.insert('installation_metadata', {'id': id, 'created_at': now});
    }
    if (modern) {
      await db.insert('active_installation', {'id': 1, 'installation_id': id});
    }
    return id;
  }

  static Future<void> restored(DatabaseExecutor db, int now) async {
    final id = const IdGenerator().next().value;
    await db.insert('installation_metadata', {'id': id, 'created_at': now});
    await db.delete('active_installation');
    await db.insert('active_installation', {'id': 1, 'installation_id': id});
  }
}
