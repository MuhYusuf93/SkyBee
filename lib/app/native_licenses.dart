import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Pub's license bundle covers Dart packages; native AAR/C dependencies need
/// their upstream grants too. Register lazily so cashier startup performs no IO.
void registerNativeLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    for (final entry in const {
      'SQLCipher for Android 4.19.1': 'sqlcipher-android-LICENSE.txt',
      'SQLCipher core 4.19.0 Community': 'sqlcipher-core-LICENSE.txt',
      'LibTomCrypt (SQLCipher provider; public-domain option)':
          'libtomcrypt-LICENSE.txt',
      'Google Tink 1.23.0': 'tink-LICENSE.txt',
      'Mbed TLS (native PIN PBKDF2)': 'mbedtls-LICENSE.txt',
    }.entries) {
      yield LicenseEntryWithLineBreaks([
        entry.key,
      ], await rootBundle.loadString('assets/third_party/${entry.value}'));
    }
  });
}
