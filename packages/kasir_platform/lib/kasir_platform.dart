import 'package:flutter/services.dart';

/// Registered in foreground and headless Flutter engines. Secrets cross only
/// this private channel, never preferences, logging, assets or backup manifests.
final class KasirPlatform {
  const KasirPlatform();
  static const channel = MethodChannel('kasir_app/platform');
  Future<T?> callNullable<T>(String name, [Map<String, Object?>? args]) =>
      channel.invokeMethod<T>(name, args);
  Future<T> call<T>(String name, [Map<String, Object?>? args]) async =>
      (await channel.invokeMethod<T>(name, args))!;
  Future<void> channelCall(String name, [Map<String, Object?>? args]) =>
      channel.invokeMethod(name, args);
  Future<String> key(String name, {required bool allowCreate}) =>
      call('key', {'name': name, 'create': allowCreate});
  Future<void> saveSecret(String name, String secret) =>
      channel.invokeMethod('saveSecret', {'name': name, 'secret': secret});
  Future<String> acquire() => call('acquire');
  Future<void> release(String token) =>
      channel.invokeMethod('release', {'token': token});
  Future<void> cryptFile({
    required String input,
    required String output,
    required String key,
    required bool decrypt,
  }) => channel.invokeMethod('cryptFile', {
    'input': input,
    'output': output,
    'key': key,
    'decrypt': decrypt,
  });
  Future<Map<Object?, Object?>> securityInfo() => call('securityInfo');
  Future<int> freeBytes(String directory) =>
      call('freeBytes', {'path': directory});
  Future<void> send(Uint8List bytes) =>
      channel.invokeMethod('btWrite', {'bytes': bytes});
}
