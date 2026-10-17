import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kasir_app/features/alerts/application/android_stock_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Standalone release probe: no DB is opened, no permission requested, no
/// notification posted, and no account/recovery code accessed. PrepareOnly must
/// verify its isolated APK before direct launch; the wrapper restores prior APK.
Future<void> main() async {
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST')) {
    throw StateError('isolatedProbeOnly');
  }
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getDatabasesPath();
  Future<Map<String, String>> hashes() async {
    final result = <String, String>{};
    for (final name in ['kasir_app.db', 'm5_acceptance_1792150309449.db']) {
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final file = File(p.join(directory, '$name$suffix'));
        result['$name$suffix'] = await file.exists()
            ? (await sha256.bind(file.openRead()).first).toString()
            : 'ABSENT';
      }
    }
    return result;
  }

  final before = await hashes();
  var initialized = false;
  String? errorCode;
  try {
    await AndroidStockNotifications(
      FlutterLocalNotificationsPlugin(),
    ).initialize(() {});
    initialized = true;
  } on PlatformException catch (error) {
    errorCode = error.code;
  } catch (error) {
    errorCode = error.runtimeType.toString();
  }
  final after = await hashes();
  final result = {
    'initialized': initialized,
    'errorCode': errorCode,
    'databaseFilesUnchanged': jsonEncode(before) == jsonEncode(after),
    'release': const bool.fromEnvironment('dart.vm.product'),
  };
  debugPrint('M5_NOTIFICATION_RELEASE_PROBE ${jsonEncode(result)}');
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('UJI COBA M5 probe selesai'))),
    ),
  );
}
