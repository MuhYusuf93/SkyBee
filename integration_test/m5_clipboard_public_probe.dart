import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Manual Android preview reproduction with PUBLIC data, not a recovery key.
/// No DB, stored secret, account, file picker, or clipboard payload is read.
/// Only an explicit tap writes the public value using the production handler.
void main() {
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST')) {
    throw StateError('isolatedProbeOnly');
  }
  runApp(const MaterialApp(home: PublicClipboardProbe()));
}

class PublicClipboardProbe extends StatefulWidget {
  const PublicClipboardProbe({super.key});

  @override
  State<PublicClipboardProbe> createState() => _PublicClipboardProbeState();
}

class _PublicClipboardProbeState extends State<PublicClipboardProbe> {
  // Clearly PUBLIC; this is never persisted or used as any archive/DB key.
  static const publicCode =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  var busy = false;
  var status = 'Belum menyalin. Tidak ada database yang dibuka.';

  Future<void> copyPublicValue() async {
    setState(() => busy = true);
    try {
      const platform = MethodChannel('kasir_app/platform');
      if (await platform.invokeMethod<bool>('copyRecoveryCode', {
            'text': publicCode,
          }) !=
          true) {
        throw StateError('copyFailed');
      }
      // Description only: deliberately no Clipboard.getData/getPrimaryClip.
      final flags = await const MethodChannel(
        'kasir_app/clipboard_probe',
      ).invokeMapMethod<String, dynamic>('describePublicClip');
      final result = {
        'ownLabel': flags?['ownLabel'] == true,
        'sensitive': flags?['sensitive'] == true,
        'plainTextMime': flags?['plainTextMime'] == true,
      };
      debugPrint('M5_PUBLIC_CLIPBOARD_METADATA ${jsonEncode(result)}');
      if (mounted) setState(() => status = jsonEncode(result));
    } catch (_) {
      if (mounted) setState(() => status = 'Probe belum berhasil.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('UJI COBA — clipboard publik')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Probe ini hanya menyalin contoh publik. Bukan kode recovery. '
            'Tombol mengganti isi clipboard; tidak membaca isinya. '
            'Periksa panel Android tanpa membuka keyboard atau menempel.',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : copyPublicValue,
            child: const Text('Salin contoh PUBLIK satu kali'),
          ),
          const SizedBox(height: 20),
          Text(status),
        ],
      ),
    ),
  );
}
