import 'package:timezone/timezone.dart' as tz;
import '../../../core/money/money.dart';

/// Versioned portable metadata contains checksums and provenance, never device
/// keys, recovery material, Google credentials or customer names.
final class BackupManifest {
  BackupManifest(this.values) {
    if (values['format'] != 1 ||
        values['cipher'] != 'SQLCipher' ||
        values['archiveCipher'] != 'Tink-AES256-GCM-HKDF-64KiB' ||
        values['id'] is! String ||
        !RegExp(
          r'^[a-zA-Z0-9-]{1,80}$',
        ).hasMatch(values['id'] as String? ?? '') ||
        values['schema'] is! int ||
        values['createdAt'] is! int ||
        (values['createdAt'] as int) < 1 ||
        (values['createdAt'] as int) > 8640000000000000 ||
        (values['schema'] as int) < 1 ||
        values['files'] is! Map) {
      throw const FormatException('backupManifestInvalid');
    }
    for (final name in ['id', 'storeId', 'originId']) {
      if (values[name] is! String ||
          !RegExp(r'^[a-zA-Z0-9-]{1,80}$').hasMatch(values[name] as String)) {
        throw const FormatException('backupManifestInvalid');
      }
    }
    try {
      final currency = CurrencyPolicy.forCode(values['currency'] as String);
      if (values['currencyScale'] != currency.scale) {
        throw const FormatException('backupManifestInvalid');
      }
      tz.getLocation(values['timeZone'] as String);
      if (values['appVersion'] is! String ||
          !RegExp(
            r'^\d+\.\d+\.\d+\+\d+$',
          ).hasMatch(values['appVersion'] as String)) {
        throw const FormatException('backupManifestInvalid');
      }
    } catch (_) {
      throw const FormatException('backupManifestInvalid');
    }
    final files = values['files'] as Map;
    if (!files.containsKey('database.db') ||
        files.keys.any((name) => !['database.db', 'logo.png'].contains(name))) {
      throw const FormatException('backupManifestInvalid');
    }
    for (final value in files.values) {
      if (value is! Map ||
          value['bytes'] is! int ||
          (value['bytes'] as int) < 1 ||
          value['sha256'] is! String ||
          !RegExp(
            r'^[a-f0-9]{64}$',
          ).hasMatch(value['sha256'] as String? ?? '')) {
        throw const FormatException('backupManifestInvalid');
      }
    }
  }
  final Map<String, dynamic> values;
  String get id => values['id'] as String;
  int get schema => values['schema'] as int;
  String get storeId => values['storeId'] as String;
  String get originId => values['originId'] as String;
  Map<String, dynamic> get files =>
      Map<String, dynamic>.from(values['files'] as Map);
}
