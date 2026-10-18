import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as hashes;
import 'package:http/http.dart' as http;
import 'package:kasir_platform/kasir_platform.dart';
import 'package:flutter/services.dart';
import '../../../data/database/durable_promotion.dart';
import 'backup_service.dart';
import 'drive_authorization.dart';

final class DriveFailure implements Exception {
  const DriveFailure(this.code, {this.retryable = false});
  final String code;
  final bool retryable;
  @override
  String toString() => code;
}

abstract interface class UploadSessionStore {
  Future<String?> read(String backupId);
  Future<void> write(String backupId, String? url);
}

final class KeystoreUploadSessions implements UploadSessionStore {
  const KeystoreUploadSessions([this.platform = const KasirPlatform()]);
  final KasirPlatform platform;
  @override
  Future<String?> read(String id) async {
    try {
      final value = await platform.key('drive-session-$id', allowCreate: false);
      return value.isEmpty ? null : value;
    } on PlatformException catch (error) {
      if (error.code != 'key_missing') rethrow;
      return null;
    }
  }

  @override
  Future<void> write(String id, String? url) =>
      platform.saveSecret('drive-session-$id', url ?? '');
}

final class DrivePage {
  const DrivePage(this.files, this.next);
  final List<Map<String, dynamic>> files;
  final String? next;
}

/// Drive transport consumes completed encrypted archives, never live databases.
/// Tokens/signed resumable URLs stay out of DB/logs/backups. Every request checks
/// the original account/consent generation; silent authorization is account-bound
/// and verified against Drive's stable permissionId before uploading any data.
final class DriveRest {
  DriveRest(
    this.policies,
    this.tokens, {
    http.Client? client,
    UploadSessionStore? sessions,
  }) : client = client ?? http.Client(),
       sessions = sessions ?? const KeystoreUploadSessions();
  final DrivePolicyStore policies;
  final DriveTokenSource tokens;
  final http.Client client;
  final UploadSessionStore sessions;
  static const namespace = bool.fromEnvironment('KASIR_INTEGRATION_TEST')
      ? 'kasir-integration-m5-v1'
      : 'kasir-operational-m5-v1';
  static const fields = 'id,name,size,md5Checksum,createdTime,appProperties';
  String? _token;
  void close() => client.close();
  static Uri uri(String path, [Map<String, String>? query]) =>
      Uri.https('www.googleapis.com', path, query);

  Future<void> guard(DrivePolicy expected, {bool automatic = false}) async {
    final actual = await policies.read();
    if (!actual.connected ||
        actual.generation != expected.generation ||
        actual.accountId != expected.accountId ||
        actual.permissionId != expected.permissionId ||
        (automatic && !actual.enabled)) {
      throw const DriveFailure('driveConsentChanged');
    }
  }

  static DriveFailure failure(int status, [String? body]) {
    if (status == 401) return const DriveFailure('driveNeedsAuthorization');
    if (status == 429 || status >= 500) {
      return const DriveFailure('driveTemporaryFailure', retryable: true);
    }
    if (status == 403) {
      if (_apiNotEnabled(body)) {
        return const DriveFailure('driveApiNotEnabled');
      }
      final reason = body ?? '';
      if (reason.contains('storageQuotaExceeded')) {
        return const DriveFailure('driveQuotaExceeded');
      }
      if (reason.contains('rateLimitExceeded') ||
          reason.contains('userRateLimitExceeded')) {
        return const DriveFailure('driveRateLimited', retryable: true);
      }
      return const DriveFailure('driveForbiddenOrNotConfigured');
    }
    if (status == 404) return const DriveFailure('driveFileUnavailable');
    return const DriveFailure('driveRequestFailed');
  }

  /// Only structured Google reason codes may identify a disabled API. Never
  /// expose upstream messages, project identifiers, or response bodies to UI.
  static bool _apiNotEnabled(String? body) {
    if (body == null) return false;
    try {
      final payload = jsonDecode(body);
      if (payload is! Map) return false;
      final error = payload['error'];
      if (error is! Map) return false;
      final errors = error['errors'];
      if (errors is List &&
          errors.any(
            (item) =>
                item is Map &&
                item['domain'] == 'usageLimits' &&
                item['reason'] == 'accessNotConfigured',
          )) {
        return true;
      }
      final details = error['details'];
      return details is List &&
          details.any((item) {
            if (item is! Map ||
                item['@type'] != 'type.googleapis.com/google.rpc.ErrorInfo' ||
                item['domain'] != 'googleapis.com' ||
                item['reason'] != 'SERVICE_DISABLED') {
              return false;
            }
            final metadata = item['metadata'];
            return metadata is Map &&
                metadata['service'] == 'drive.googleapis.com';
          });
    } on FormatException {
      return false;
    }
  }

  Future<http.StreamedResponse> _send(
    String method,
    Uri location,
    DrivePolicy policy, {
    Map<String, String> headers = const {},
    List<int>? bytes,
    bool automatic = false,
    bool initialIdentity = false,
  }) async {
    if (!initialIdentity) await guard(policy, automatic: automatic);
    try {
      _token ??= await tokens.token(policy);
    } on DriveAuthorizationRequired {
      // SDK null (silent consent unavailable) and HTTP 401 need the same UI/
      // scheduler status, without classifying other SDK failures as consent.
      throw const DriveFailure('driveNeedsAuthorization');
    }
    final request = http.Request(method, location)
      ..followRedirects = false
      ..headers.addAll({'Authorization': 'Bearer $_token', ...headers});
    if (bytes != null) request.bodyBytes = bytes;
    try {
      return await client.send(request).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      client.close();
      throw const DriveFailure('driveNetworkTimeout', retryable: true);
    } on IOException {
      throw const DriveFailure('driveOffline', retryable: true);
    } on http.ClientException {
      throw const DriveFailure('driveOffline', retryable: true);
    }
  }

  Future<String> _small(http.StreamedResponse response) async {
    final data = BytesBuilder(copy: false);
    await for (final bytes in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      if (data.length + bytes.length > 1048576) {
        throw const DriveFailure('driveMetadataTooLarge');
      }
      data.add(bytes);
    }
    final body = utf8.decode(data.takeBytes());
    if (response.statusCode == 401 && _token != null) {
      await tokens.invalidate(_token!);
      _token = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw failure(response.statusCode, body);
    }
    return body;
  }

  Future<Map<String, dynamic>> identify(
    DrivePolicy policy, {
    bool initial = false,
  }) async {
    final response = await _send(
      'GET',
      uri('/drive/v3/about', {'fields': 'user(permissionId,emailAddress)'}),
      policy,
      initialIdentity: initial,
    );
    final user =
        (jsonDecode(await _small(response)) as Map<String, dynamic>)['user']
            as Map<String, dynamic>;
    if ((user['emailAddress'] as String?)?.toLowerCase() !=
            policy.email?.toLowerCase() ||
        (!initial && user['permissionId'] != policy.permissionId)) {
      throw const DriveFailure('driveAccountMismatch');
    }
    return user;
  }

  static String escape(String value) =>
      value.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
  static String property(String key, String value) =>
      "appProperties has { key='$key' and value='${escape(value)}' }";
  Future<DrivePage> list(
    DrivePolicy policy, {
    String? pageToken,
    String? storeId,
    String? originId,
    String? backupId,
    bool completeOnly = true,
    bool automatic = false,
  }) async {
    final query = [
      "trashed=false",
      property('namespace', namespace),
      if (completeOnly) property('complete', '1'),
      if (storeId != null) property('storeId', storeId),
      if (originId != null) property('originId', originId),
      if (backupId != null) property('backupId', backupId),
    ].join(' and ');
    final response = await _send(
      'GET',
      uri('/drive/v3/files', {
        'spaces': 'appDataFolder',
        'q': query,
        'pageSize': '100',
        'orderBy': 'createdTime desc,name',
        'fields': 'nextPageToken,files($fields)',
        'pageToken': ?pageToken,
      }),
      policy,
      automatic: automatic,
    );
    final data = jsonDecode(await _small(response)) as Map<String, dynamic>;
    return DrivePage(
      (data['files'] as List? ?? []).cast<Map<String, dynamic>>(),
      data['nextPageToken'] as String?,
    );
  }

  static String fileId(String value) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,256}$').hasMatch(value)) {
      throw const DriveFailure('driveInvalidFileId');
    }
    return value;
  }

  Future<Map<String, dynamic>> metadata(
    DrivePolicy policy,
    String id, {
    bool automatic = false,
  }) async =>
      jsonDecode(
            await _small(
              await _send(
                'GET',
                uri('/drive/v3/files/${fileId(id)}', {'fields': fields}),
                policy,
                automatic: automatic,
              ),
            ),
          )
          as Map<String, dynamic>;

  static Uri uploadUri(String value) {
    final url = Uri.parse(value);
    if (url.scheme != 'https' ||
        url.host != 'www.googleapis.com' ||
        !url.path.startsWith('/upload/drive/v3/files') ||
        url.userInfo.isNotEmpty) {
      throw const DriveFailure('driveInvalidUploadLocation');
    }
    return url;
  }

  Future<Map<String, dynamic>> upload(
    DrivePolicy policy,
    PortableBackup backup, {
    bool automatic = false,
  }) async {
    await identify(policy);
    final size = await backup.file.length(),
        sha = await DurablePromotion.digest(backup.file);
    final md5 = (await hashes.md5.bind(backup.file.openRead()).first)
        .toString();
    final manifest = backup.manifest;
    final properties = {
      'namespace': namespace,
      'storeId': manifest.storeId,
      'originId': manifest.originId,
      'backupId': manifest.id,
      'format': '1',
      'schema': '${manifest.schema}',
      'createdAt': '${manifest.values['createdAt']}',
      'sha256': sha,
      'complete': '0',
    };
    final prior = await list(
      policy,
      backupId: manifest.id,
      completeOnly: false,
      automatic: automatic,
    );
    for (final item in prior.files) {
      if (item['size'] == '$size' &&
          item['md5Checksum'] == md5 &&
          _belongs(item, manifest.storeId, manifest.originId) &&
          (item['appProperties'] as Map)['sha256'] == sha) {
        return _complete(
          policy,
          item['id'] as String,
          properties,
          automatic: automatic,
        );
      }
    }
    var stored = await sessions.read(manifest.id);
    Uri? session = stored == null ? null : uploadUri(stored);
    var offset = 0;
    if (session != null) {
      final status = await _send(
        'PUT',
        session,
        policy,
        headers: {'Content-Range': 'bytes */$size', 'Content-Length': '0'},
        bytes: [],
        automatic: automatic,
      );
      if (status.statusCode == 308) {
        offset = _offset(status, size);
        await status.stream.drain<void>();
      } else if (status.statusCode == 200 || status.statusCode == 201) {
        final done = jsonDecode(await _small(status)) as Map<String, dynamic>;
        return _verify(
          policy,
          done['id'] as String,
          properties,
          size,
          md5,
          automatic,
        );
      } else if (status.statusCode == 404 || status.statusCode == 410) {
        await status.stream.drain<void>();
        session = null;
      } else {
        await _small(status);
        throw const DriveFailure('driveUploadStatusInvalid');
      }
    }
    if (session == null) {
      final start = await _send(
        'POST',
        uri('/upload/drive/v3/files', {
          'uploadType': 'resumable',
          'fields': fields,
        }),
        policy,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'X-Upload-Content-Type': 'application/octet-stream',
          'X-Upload-Content-Length': '$size',
        },
        bytes: utf8.encode(
          jsonEncode({
            'name': 'kasir-${manifest.id}.kasirbackup',
            'parents': ['appDataFolder'],
            'appProperties': properties,
          }),
        ),
        automatic: automatic,
      );
      await _small(start);
      final location = start.headers['location'];
      if (location == null) {
        throw const DriveFailure('driveUploadLocationMissing');
      }
      session = uploadUri(location);
      await sessions.write(manifest.id, session.toString());
    }
    final file = await backup.file.open();
    final deadline = DateTime.now().add(const Duration(minutes: 8));
    try {
      while (offset < size) {
        if (DateTime.now().isAfter(deadline)) {
          throw const DriveFailure('driveUploadDeferred', retryable: true);
        }
        await guard(policy, automatic: automatic);
        await file.setPosition(offset);
        final bytes = await file.read((size - offset).clamp(1, 262144));
        if (bytes.isEmpty) throw const DriveFailure('driveSnapshotChanged');
        final response = await _send(
          'PUT',
          session,
          policy,
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Range': 'bytes $offset-${offset + bytes.length - 1}/$size',
            'Content-Length': '${bytes.length}',
          },
          bytes: bytes,
          automatic: automatic,
        );
        if (response.statusCode == 308) {
          final next = _offset(response, size);
          await response.stream.drain<void>();
          if (next <= offset || next > offset + bytes.length) {
            throw const DriveFailure('driveUploadRangeInvalid');
          }
          offset = next;
        } else {
          final data =
              jsonDecode(await _small(response)) as Map<String, dynamic>;
          if (offset + bytes.length != size) {
            throw const DriveFailure('driveUploadPrematureCompletion');
          }
          final result = await _verify(
            policy,
            data['id'] as String,
            properties,
            size,
            md5,
            automatic,
          );
          await sessions.write(manifest.id, null);
          return result;
        }
      }
      throw const DriveFailure('driveUploadUnverified', retryable: true);
    } finally {
      await file.close();
    }
  }

  static int _offset(http.StreamedResponse response, int size) {
    final range = response.headers['range'];
    if (range == null) return 0;
    final match = RegExp(r'^bytes=0-(\d+)$').firstMatch(range);
    if (match == null) throw const DriveFailure('driveUploadRangeInvalid');
    final result = int.parse(match[1]!) + 1;
    if (result > size) throw const DriveFailure('driveUploadRangeInvalid');
    return result;
  }

  static bool _belongs(Map<String, dynamic> item, String store, String origin) {
    final properties = item['appProperties'];
    return properties is Map &&
        properties['namespace'] == namespace &&
        properties['storeId'] == store &&
        properties['originId'] == origin;
  }

  Future<Map<String, dynamic>> _verify(
    DrivePolicy policy,
    String id,
    Map<String, String> properties,
    int size,
    String md5,
    bool automatic,
  ) async {
    final item = await metadata(policy, id, automatic: automatic);
    if (item['size'] != '$size' ||
        item['md5Checksum'] != md5 ||
        !_belongs(item, properties['storeId']!, properties['originId']!) ||
        (item['appProperties'] as Map)['sha256'] != properties['sha256']) {
      throw const DriveFailure('driveChecksumMismatch');
    }
    return _complete(policy, id, properties, automatic: automatic);
  }

  Future<Map<String, dynamic>> _complete(
    DrivePolicy policy,
    String id,
    Map<String, String> properties, {
    required bool automatic,
  }) async {
    final response = await _send(
      'PATCH',
      uri('/drive/v3/files/${fileId(id)}', {'fields': fields}),
      policy,
      headers: {'Content-Type': 'application/json'},
      bytes: utf8.encode(
        jsonEncode({
          'appProperties': {...properties, 'complete': '1'},
        }),
      ),
      automatic: automatic,
    );
    return jsonDecode(await _small(response)) as Map<String, dynamic>;
  }

  /// Keep seven verified complete files of THIS store+origin+namespace only.
  /// Re-query the first page after deletions; mutation invalidates page tokens.
  Future<void> retainSeven(
    DrivePolicy policy,
    String store,
    String origin, {
    required String newId,
    bool automatic = false,
  }) async {
    final newest = await metadata(policy, newId, automatic: automatic);
    if (!_belongs(newest, store, origin) ||
        (newest['appProperties'] as Map)['complete'] != '1') {
      throw const DriveFailure('driveRetentionScopeInvalid');
    }
    while (true) {
      final page = await list(
        policy,
        storeId: store,
        originId: origin,
        automatic: automatic,
      );
      if (page.files.length <= 7) return;
      final keep = page.files.take(7).map((e) => e['id']).toSet();
      if (!keep.contains(newId)) {
        keep.remove(page.files[6]['id']);
        keep.add(newId);
      }
      final obsolete = page.files
          .where((e) => !keep.contains(e['id']))
          .toList();
      if (obsolete.isEmpty) return;
      for (final item in obsolete) {
        if (!_belongs(item, store, origin)) {
          throw const DriveFailure('driveRetentionScopeInvalid');
        }
        await _small(
          await _send(
            'DELETE',
            uri('/drive/v3/files/${fileId(item['id'] as String)}'),
            policy,
            automatic: automatic,
          ),
        );
      }
    }
  }

  Future<File> download(
    DrivePolicy policy,
    String id,
    File destination, {
    required int byteBudget,
  }) async {
    await identify(policy);
    final item = await metadata(policy, id);
    final properties = item['appProperties'];
    if (properties is! Map ||
        properties['namespace'] != namespace ||
        properties['complete'] != '1') {
      throw const DriveFailure('driveBackupUnverified');
    }
    final size = int.tryParse(item['size'] as String? ?? '');
    if (size == null ||
        size < 1 ||
        size > byteBudget ||
        await destination.exists()) {
      throw const DriveFailure('driveDownloadInvalid');
    }
    final response = await _send(
      'GET',
      uri('/drive/v3/files/${fileId(id)}', {'alt': 'media'}),
      policy,
    );
    if (response.statusCode != 200) {
      await _small(response);
      throw const DriveFailure('driveDownloadFailed');
    }
    final output = destination.openWrite();
    var received = 0;
    try {
      await for (final bytes in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        await guard(policy);
        received += bytes.length;
        if (received > size) throw const DriveFailure('driveDownloadTooLarge');
        output.add(bytes);
        await output.flush();
      }
      await output.close();
      if (received != size ||
          await DurablePromotion.digest(destination) != properties['sha256'] ||
          (await hashes.md5.bind(destination.openRead()).first).toString() !=
              item['md5Checksum']) {
        throw const DriveFailure('driveChecksumMismatch');
      }
      return destination;
    } catch (_) {
      await output.close();
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }
}
