import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/management/application/pin_hasher.dart';
import 'package:kasir_app/features/management/application/management_service.dart';

/// Native KDF must match the old Dart algorithm, not merely auto-fallback.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kasir_app/pin_kdf');
  Future<Uint8List?> native(
    String input,
    List<int> salt, {
    Object rounds = 600000,
    int bits = 256,
  }) => channel.invokeMethod<Uint8List>('derivePbkdf2Sha256', {
    'password': Uint8List.fromList(utf8.encode(input)),
    'salt': Uint8List.fromList(salt),
    'iterations': rounds,
    'bits': bits,
  });
  test(
    'native PBKDF2 matches independent ASCII recovery and UTF8 vectors',
    () async {
      final backend = await channel.invokeMapMethod<String, Object?>(
        'backendInfo',
      );
      expect(backend!['available'], isTrue);
      expect(backend['mainThread'], isFalse);
      debugPrint('PIN_BACKEND_INFO ${jsonEncode(backend)}');
      final vectors = <(String, List<int>, String)>[
        (
          'pin:0001',
          List.generate(32, (i) => i),
          'baecb82b90f2089fbc1e369780cab3302ac4a19f2332c8db18f8ecc630317c9e',
        ),
        (
          'recovery:${'A' * 32}',
          List.generate(32, (i) => 31 - i),
          '7316b0d9bb057720a87ae322b1e10eca208829a55295b5e3aaad4a223d12623c',
        ),
        (
          'pin:00é1',
          List.generate(32, (i) => 128 + i),
          'bb4288f7fc5cfeeb8c3340aa3a7f0efab58d73eb6a1b687e8b023a0072e019b4',
        ),
      ];
      for (final vector in vectors) {
        final result = (await native(vector.$1, vector.$2))!;
        expect(result.length, 32);
        expect(
          result.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
          vector.$3,
        );
      }
      // Exercise the PBKDF2/HMAC boundary cases, including a password longer
      // than SHA256's 64-byte block and a non-default accepted iteration count.
      for (final vector in <(String, int, int, String)>[
        (
          '',
          16,
          600000,
          'ffa81c4acdf4b1394384005f0aaf083dd4c7bae97d8dc466581ecf75bb005eb9',
        ),
        (
          'X' * 100,
          32,
          600001,
          'cae1b5172f5c313bad3d70813c6fd312f6fea854dfdc2974318d8e5dfc203825',
        ),
      ]) {
        final bytes = (await native(
          vector.$1,
          List.generate(vector.$2, (i) => i),
          rounds: vector.$3,
        ))!;
        expect(
          bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
          vector.$4,
        );
      }
      final legacyWatch = Stopwatch()..start();
      final legacy = await const PinHasher(
        preferAndroidNative: false,
      ).derive(vectors.first.$1, vectors.first.$2);
      legacyWatch.stop();
      expect(
        listEquals(legacy, await native(vectors.first.$1, vectors.first.$2)),
        isTrue,
      );
      debugPrint(
        'PIN_BACKEND_LEGACY_SAMPLE ${jsonEncode({'microseconds': legacyWatch.elapsedMicroseconds, 'iterations': 600000, 'bits': 256, 'scope': 'forced Dart debug reference only'})}',
      );
    },
  );
  test(
    'native bridge rejects weak and non-integer parameters without fallback downgrade',
    () async {
      for (final rounds in <Object>[1, 599999, 2000001, 600000.5, 4295567296]) {
        await expectLater(
          native('synthetic', List<int>.filled(32, 0), rounds: rounds),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'KDF_PARAMETERS',
            ),
          ),
        );
      }
      await expectLater(
        native('synthetic', List<int>.filled(32, 0), bits: 128),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        native('synthetic', List<int>.filled(8, 0)),
        throwsA(isA<PlatformException>()),
      );
    },
  );
  test(
    'native backend unlocks independently seeded pre-optimization Dart verifier unchanged',
    () async {
      // The historical Realme fixture is not present on other phones. Seed an
      // independent old-backend verifier in a new nonce DB, close, then verify
      // through the native production backend without rewriting its bytes.
      final path =
          '${await getDatabasesPath()}/pin_old_verifier_${DateTime.now().microsecondsSinceEpoch}.db';
      final seed = DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: path,
      );
      try {
        await ManagementService(
          seed,
          StoreClock(),
          hasher: const PinHasher(preferAndroidNative: false),
        ).configure('Synthetic old Dart verifier', '0001', '0001');
      } finally {
        await seed.close();
      }
      final db = DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: path,
      );
      final services = AppServices(db);
      try {
        final before = (await db.read(
          (d) => d.query('management_credentials'),
        )).single;
        final watch = Stopwatch()..start();
        await services.management.unlock('0001');
        final elapsed = watch.elapsedMicroseconds;
        services.management.requireAccess();
        final after = (await db.read(
          (d) => d.query('management_credentials'),
        )).single;
        expect(
          listEquals(before['salt'] as List<int>, after['salt'] as List<int>),
          isTrue,
        );
        expect(
          listEquals(
            before['pin_verifier'] as List<int>,
            after['pin_verifier'] as List<int>,
          ),
          isTrue,
        );
        expect(after['kdf_name'], 'PBKDF2-HMAC-SHA256');
        expect(after['kdf_parameters'], before['kdf_parameters']);
        debugPrint(
          'PIN_BACKEND_OLD_VERIFIER ${jsonEncode({'unlock_us': elapsed, 'verifier_preserved': true, 'iterations': 600000, 'bits': 256})}',
        );
      } finally {
        services.management.lock();
        await db.close();
        await deleteDatabase(path);
      }
    },
  );
  test(
    'native KDF five short samples with full 600k rounds, no invented SLA',
    () async {
      final samples = <int>[];
      for (var i = 0; i < 5; i++) {
        final watch = Stopwatch()..start();
        expect(
          (await native('pin:0001', List.generate(32, (n) => n)))!.length,
          32,
        );
        samples.add(watch.elapsedMicroseconds);
      }
      debugPrint(
        'PIN_BACKEND_NATIVE_SAMPLES ${jsonEncode({'samples_us': samples, 'iterations': 600000, 'bits': 256, 'mode': 'debug Mbed TLS native KDF', 'device': 'explicit runner target'})}',
      );
    },
  );
}
