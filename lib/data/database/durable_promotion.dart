import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';

/// Two renames are not atomic. This journal makes every interruption explicit:
/// until committed, startup restores the old verified file; after committed it
/// finishes cleanup. Unknown hashes stop recovery rather than discarding data.
final class DurablePromotion {
  DurablePromotion(this.livePath, {this.syncDirectory});
  final String livePath;
  final Future<void> Function(String directory)? syncDirectory;
  Future<void> _sync() async => syncDirectory?.call(File(livePath).parent.path);
  String get stagePath => '$livePath.incoming';
  String get oldPath => '$livePath.previous';
  String get journalPath => '$livePath.promotion';
  Future<void> Function(String phase)? testPhase;

  static Future<String> digest(File file) async {
    final sink = Sha256().newHashSink();
    await for (final chunk in file.openRead()) {
      sink.add(chunk);
    }
    sink.close();
    return (await sink.hash()).bytes
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<void> _journal(Map<String, Object?> value) async {
    final temp = File('$journalPath.new');
    await temp.writeAsString(jsonEncode(value), flush: true);
    await temp.rename(journalPath);
    await _sync();
  }

  Future<void> recover() async {
    final journal = File(journalPath);
    if (!await journal.exists()) {
      if (await File(oldPath).exists()) {
        throw StateError('promotionJournalMissing');
      }
      return;
    }
    final data =
        jsonDecode(await journal.readAsString()) as Map<String, dynamic>;
    if (data['format'] != 1 ||
        data['committed'] is! bool ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['old'] as String? ?? '') ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['new'] as String? ?? '')) {
      throw StateError('promotionJournalInvalid');
    }
    final live = File(livePath), old = File(oldPath), stage = File(stagePath);
    Future<void> expect(File file, String hash) async {
      if (!await file.exists() || await digest(file) != hash) {
        throw StateError('promotionRecoveryNeedsInspection');
      }
    }

    if (data['committed'] == true) {
      await expect(live, data['new'] as String);
      if (await old.exists()) {
        await expect(old, data['old'] as String);
        await old.delete();
      }
    } else if (await old.exists()) {
      await expect(old, data['old'] as String);
      if (await live.exists()) {
        await expect(live, data['new'] as String);
        await live.delete();
      }
      await old.rename(livePath);
    } else {
      await expect(live, data['old'] as String);
    }
    if (await stage.exists()) {
      await expect(stage, data['new'] as String);
      await stage.delete();
    }
    await _sync();
    await journal.delete();
    await _sync();
    if (await File('$journalPath.new').exists()) {
      await File('$journalPath.new').delete();
    }
  }

  /// Caller closes all live connections, removes/checkpoints sidecars, validates
  /// staging and owns the cross-engine gate throughout this call and recovery.
  Future<void> promote(Future<void> Function() verifyReopen) async {
    if (await File(journalPath).exists() || await File(oldPath).exists()) {
      throw StateError('promotionAlreadyPending');
    }
    final data = <String, Object?>{
      'format': 1,
      'old': await digest(File(livePath)),
      'new': await digest(File(stagePath)),
      'committed': false,
    };
    await _journal(data);
    await testPhase?.call('journal');
    await File(livePath).rename(oldPath);
    await _sync();
    await testPhase?.call('oldMoved');
    await File(stagePath).rename(livePath);
    await _sync();
    await testPhase?.call('newMoved');
    await verifyReopen();
    // Verification may modify journal mode/header. Record the final file hash.
    data['new'] = await digest(File(livePath));
    data['committed'] = true;
    await _journal(data);
    await testPhase?.call('committed');
    await recover();
  }
}
