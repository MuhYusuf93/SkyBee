import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'app/kasir_app.dart';
import 'data/database/database_coordinator.dart';
import 'demo/skybee_demo_seed.dart';
import 'demo/skybee_upgrade_audit.dart';

/// Dedicated opt-in debug launcher; ordinary main.dart cannot seed a store.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode ||
      !const bool.fromEnvironment('KASIR_SKYBEE_DEMO') ||
      const bool.fromEnvironment('KASIR_INTEGRATION_TEST')) {
    throw StateError('skybeeDemoDebugPackageRequired');
  }
  final identity = await const MethodChannel(
    'kasir_app/skybee_demo',
  ).invokeMapMethod<String, Object?>('identity');
  if (identity?['package'] != 'com.example.kasir_app.skybee' ||
      identity?['debuggable'] != true) {
    throw StateError('skybeeDemoWrongPackage');
  }
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Menyiapkan skybee kasir…'))),
    ),
  );
  final database = await DatabaseCoordinator.android();
  final marker = File(
    p.join(p.dirname(database.databasePath), 'skybee-demo-seed-v1.json'),
  );
  try {
    await marker.parent.create(recursive: true);
    if (await marker.exists()) {
      final saved = jsonDecode(await marker.readAsString()) as Map;
      if (saved['status'] != 'complete') {
        throw StateError('skybeeDemoSeedInterrupted');
      }
      await SkybeeUpgradeAudit.upgradeExisting(
        database,
        File(p.join(marker.parent.path, 'skybee-m52-upgrade-audit.json')),
        originalSnapshot: File(
          p.join(
            marker.parent.parent.path,
            'cache',
            'skybee-m52-original-v13.db',
          ),
        ),
      );
    } else {
      // A started marker prevents a crash or partial setup from being silently
      // retried over existing data. Never reseed after the user starts testing.
      await marker.writeAsString(
        jsonEncode({'status': 'started'}),
        flush: true,
      );
      final summary = await SkybeeDemoSeed.populate(database);
      await marker.writeAsString(jsonEncode(summary), flush: true);
    }
    await database.close();
    runApp(const KasirApp());
  } catch (_) {
    await database.close();
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Persiapan data demo belum selesai. Data yang sudah ada tetap disimpan.',
            ),
          ),
        ),
      ),
    );
  }
}
