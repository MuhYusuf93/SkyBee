import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'app/kasir_app.dart';
import 'data/database/database_coordinator.dart';
import 'gemini_seed.dart';

/// Entrypoint mandiri aplikasi pengujian Gemini.
/// Terisolasi penuh dari alur utama Codex dan tidak menyentuh database operasional.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode || const bool.fromEnvironment('KASIR_INTEGRATION_TEST')) {
    throw StateError('geminiDebugPackageRequired');
  }

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Menyiapkan data toko pengujian Gemini…',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              Text(
                '100 produk, 50 transaksi, kategori, supplier, pelanggan',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  var database = await DatabaseCoordinator.android();
  final marker = File(
    p.join(p.dirname(database.databasePath), 'gemini-seed-marker.json'),
  );

  try {
    await marker.parent.create(recursive: true);
    if (await marker.exists()) {
      final saved = jsonDecode(await marker.readAsString()) as Map;
      if (saved['status'] != 'complete') {
        // Reset DB jika interrupted
        await database.close();
        await databaseFactory.deleteDatabase(database.databasePath);
        database = await DatabaseCoordinator.android();
        final summary = await GeminiDemoSeed.populate(database);
        await marker.writeAsString(jsonEncode(summary), flush: true);
      }
    } else {
      await marker.writeAsString(
        jsonEncode({'status': 'started'}),
        flush: true,
      );
      final summary = await GeminiDemoSeed.populate(database);
      await marker.writeAsString(jsonEncode(summary), flush: true);
    }
    await database.close();
    runApp(const KasirApp());
  } catch (e, stack) {
    debugPrint('Gemini seed error: $e\n$stack');
    await database.close();
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Persiapan data pengujian belum selesai.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('$e', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
