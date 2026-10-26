import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/management/application/management_service.dart';
import 'package:kasir_app/features/management/application/strong_biometrics.dart';
import 'package:kasir_app/features/management/domain/session_policy.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';

class SyntheticStrongBiometrics implements StrongBiometrics {
  bool available = true, locked = false, invalidated = false;
  int screenGeneration = 0, calls = 0;
  String? boundEpoch;
  AppError? failure;
  Completer<void>? pending, started;
  @override
  Future<BiometricState> status(String scope, String epoch) async {
    final changed = invalidated || (boundEpoch != null && boundEpoch != epoch);
    if (changed) boundEpoch = null;
    return BiometricState(
      available: available,
      enabled: boundEpoch != null,
      invalidated: changed,
    );
  }

  @override
  Future<void> authenticate(
    String scope,
    String epoch, {
    required bool enroll,
    required String title,
    required String pinAlternative,
  }) async {
    calls++;
    started?.complete();
    if (!available) throw const AppError('m51BiometricUnavailable');
    if (failure != null) throw failure!;
    await pending?.future;
    if (enroll) boundEpoch = epoch;
  }

  @override
  Future<void> clear(String scope) async => boundEpoch = null;
  @override
  Future<ScreenSecurityState> screenState() async =>
      ScreenSecurityState(locked, screenGeneration);
}

void m51SecuritySuite(DatabaseFactory factory) {
  late Directory directory;
  late Map<String, Object?> verifier;
  late DatabaseCoordinator db;
  late AppServices app;
  late SyntheticStrongBiometrics bio;
  late StoreClock clock;
  var counter = 0, ticks = 1000;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m51_security_');
    final seed = DatabaseCoordinator(
      factory: factory,
      databasePath: p.join(
        directory.path,
        'm5_regression_${DateTime.now().microsecondsSinceEpoch}_${counter++}.db',
      ),
    );
    try {
      final services = AppServices(seed);
      await services.management.configure('Synthetic security', '0001', '0001');
      verifier = Map.of(
        (await seed.read((sql) => sql.query('management_credentials'))).single,
      );
      // Each case injects an earlier synthetic wall clock. Start its attempt
      // accounting at that clock rather than carrying the host setup time.
      verifier['last_attempt_at'] = 0;
    } finally {
      await seed.close();
    }
  });
  setUp(() async {
    ticks = 1000;
    clock = StoreClock(
      now: () => DateTime.utc(2026, 10, 19),
      elapsedMilliseconds: () => ticks,
    );
    db = DatabaseCoordinator(
      factory: factory,
      databasePath: p.join(
        directory.path,
        'm5_regression_${DateTime.now().microsecondsSinceEpoch}_${counter++}.db',
      ),
    );
    await db.transaction(
      (sql) => sql.insert('management_credentials', verifier),
    );
    bio = SyntheticStrongBiometrics();
    app = AppServices(db, clock: clock, biometrics: bio);
    await app.management.unlock('0001');
  });
  tearDown(() async => db.close());
  tearDownAll(() async {
    if (!p.isWithin(Directory.systemTemp.path, directory.path) ||
        !p.basename(directory.path).startsWith('kasir_m51_security_')) {
      throw StateError('Unsafe cleanup');
    }
    await directory.delete(recursive: true);
  });
  Future<void> policy(SessionPolicy value) async {
    await app.management.reauthenticate('0001', 'security');
    await app.management.saveSessionPolicy(value);
  }

  Future<void> enable() async {
    await app.management.reauthenticate('0001', 'security');
    await app.management.setBiometrics(
      true,
      title: 'PUBLIC synthetic biometric',
      pinAlternative: 'Use app PIN',
    );
  }

  Future<void> unlockBio() => app.management.unlockBiometric(
    title: 'PUBLIC synthetic biometric',
    pinAlternative: 'Use app PIN',
  );

  test(
    'immediate default and timed policies preserve cashier draft; resume does not extend idle',
    () async {
      final draft = await app.cart.open();
      expect(app.management.sessionPolicy, SessionPolicy.immediate);
      app.management.backgrounded();
      expect(app.management.isUnlocked, false);
      expect((await app.cart.open()).id, draft.id);
      for (final choice in [
        SessionPolicy.oneMinute,
        SessionPolicy.fiveMinutes,
        SessionPolicy.fifteenMinutes,
      ]) {
        await policy(choice);
        ticks += choice.idle.inMilliseconds - 1;
        app.management.inactive();
        app.management.backgrounded();
        await app.management.evaluateResume();
        expect(app.management.isUnlocked, true);
        ticks += 2;
        await app.management.evaluateResume();
        expect(app.management.isUnlocked, false);
        expect((await app.cart.open()).id, draft.id);
      }
    },
  );
  test(
    'legacy schema9 upgrade retains immediate background and 5-minute idle',
    () async {
      final oldPath = p.join(
        directory.path,
        'm5_regression_${DateTime.now().microsecondsSinceEpoch}_${counter++}.db',
      );
      var old = DatabaseCoordinator(
        factory: factory,
        databasePath: oldPath,
        schemaVersion: 9,
      );
      await old.transaction(
        (sql) => sql.insert(
          'management_credentials',
          {...verifier}
            ..remove('last_pin_verified_at')
            ..remove('last_pin_clock_seen_at'),
        ),
      );
      await old.close();
      old = DatabaseCoordinator(factory: factory, databasePath: oldPath);
      try {
        final service = ManagementService(old, clock, biometrics: bio);
        await service.unlock('0001');
        expect(service.sessionPolicy, SessionPolicy.legacy);
        ticks += const Duration(minutes: 4).inMilliseconds;
        expect(service.isUnlocked, true);
        service.backgrounded();
        expect(service.isUnlocked, false);
      } finally {
        await old.close();
      }
    },
  );
  test(
    'scoped dialog redacts without revival; manual-lock and expired callbacks are rejected',
    () async {
      var answer = Completer<String>();
      var started = Completer<void>();
      var pending = app.management.systemInteraction(() {
        started.complete();
        return answer.future;
      });
      await started.future;
      app.management.inactive();
      expect(app.management.isUnlocked, true);
      app.management.backgrounded();
      expect(app.management.isUnlocked, false);
      answer.complete('public-untrusted-selection');
      expect(await pending, 'public-untrusted-selection');
      await app.management.evaluateResume();
      expect(app.management.isUnlocked, false);
      await app.management.unlock('0001');
      answer = Completer<String>();
      started = Completer<void>();
      pending = app.management.systemInteraction(() {
        started.complete();
        return answer.future;
      });
      final rejected = expectLater(pending, throwsA(isA<AppError>()));
      await started.future;
      app.management.lock();
      await app.management.unlock('0001');
      answer.complete('STALE');
      await rejected;
      answer = Completer<String>();
      started = Completer<void>();
      pending = app.management.systemInteraction(() {
        started.complete();
        return answer.future;
      });
      final expired = expectLater(pending, throwsA(isA<AppError>()));
      await started.future;
      ticks += 60001;
      answer.complete('EXPIRED');
      await expired;
    },
  );
  test(
    'fresh proof is purpose-bound, fixed deadline and revoked on lock',
    () async {
      await policy(SessionPolicy.fifteenMinutes);
      expect(
        () => app.management.requireFresh('recovery'),
        throwsA(isA<AppError>()),
      );
      await app.management.reauthenticate('0001', 'recovery');
      app.management.requireFresh('recovery');
      expect(
        () => app.management.requireFresh('restore'),
        throwsA(isA<AppError>()),
      );
      ticks += 60001;
      app.management.touch();
      expect(app.management.isUnlocked, true);
      expect(app.management.hasFresh('recovery'), false);
      await app.management.reauthenticate('0001', 'restore');
      app.management.lock();
      expect(app.management.hasFresh('restore'), false);
    },
  );
  test(
    'biometric opt-in requires fresh PIN; cancel/OS lockout never authenticate; PIN fallback works',
    () async {
      await expectLater(
        app.management.setBiometrics(
          true,
          title: 'Public',
          pinAlternative: 'PIN',
        ),
        throwsA(isA<AppError>()),
      );
      await enable();
      app.management.lock();
      bio.failure = const AppError('m51BiometricCancelled');
      await expectLater(unlockBio(), throwsA(isA<AppError>()));
      expect(app.management.isUnlocked, false);
      bio.failure = const AppError('m51BiometricLockout');
      await expectLater(unlockBio(), throwsA(isA<AppError>()));
      expect(app.management.isUnlocked, false);
      bio.failure = null;
      await unlockBio();
      expect(app.management.isUnlocked, true);
      app.management.lock();
      await app.management.unlock('0001');
      expect(app.management.isUnlocked, true);
    },
  );
  test(
    'unsupported biometrics and app PIN lockout do not reach biometric authentication',
    () async {
      bio.available = false;
      app.management.lock();
      final prior = bio.calls;
      await expectLater(unlockBio(), throwsA(isA<AppError>()));
      expect(bio.calls, prior);
      await app.management.unlock('0001');
      bio.available = true;
      await enable();
      app.management.lock();
      for (var i = 0; i < 3; i++) {
        await expectLater(
          app.management.unlock('9999'),
          throwsA(isA<AppError>()),
        );
      }
      final before = bio.calls;
      await expectLater(unlockBio(), throwsA(isA<AppError>()));
      expect(bio.calls, before);
    },
  );
  test(
    'late biometric success after explicit lock is rejected; enrollment invalidation and screen-off revoke grace',
    () async {
      await enable();
      app.management.lock();
      bio.pending = Completer<void>();
      bio.started = Completer<void>();
      final pending = unlockBio();
      final rejected = expectLater(pending, throwsA(isA<AppError>()));
      await bio.started!.future;
      app.management.lock();
      bio.pending!.complete();
      await rejected;
      expect(app.management.isUnlocked, false);
      bio.pending = null;
      bio.started = null;
      await app.management.unlock('0001');
      await policy(SessionPolicy.fifteenMinutes);
      bio.invalidated = true;
      await app.management.evaluateResume();
      expect(app.management.isUnlocked, false);
      bio.invalidated = false;
      await app.management.unlock('0001');
      bio.screenGeneration++;
      await app.management.evaluateResume();
      expect(app.management.isUnlocked, false);
      final restarted = ManagementService(db, clock, biometrics: bio);
      expect(restarted.isUnlocked, false);
    },
  );
  test(
    'another service PIN rotation must revoke stale protected reads/writes',
    () async {
      final id = await app.inventory.create(
        ProductInput(
          name: 'Synthetic old capability',
          sellingPrice: Money(12000, 'IDR', 0),
        ),
      );
      final other = ManagementService(db, clock, biometrics: bio);
      await other.changePin('0001', '0002', '0002');
      await expectLater(app.inventory.detail(id), throwsA(isA<AppError>()));
      await expectLater(
        app.inventory.create(
          ProductInput(
            name: 'MUST NOT EXIST',
            sellingPrice: Money(12000, 'IDR', 0),
          ),
        ),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'resume of a new biometric prompt ignores a prior locked session screen epoch',
    () async {
      await enable();
      app.management.lock();
      bio.screenGeneration++;
      bio.pending = Completer<void>();
      bio.started = Completer<void>();
      final authentication = unlockBio();
      await bio.started!.future;
      await app.management.evaluateResume();
      bio.pending!.complete();
      await authentication;
      expect(app.management.isUnlocked, true);
    },
  );
}
