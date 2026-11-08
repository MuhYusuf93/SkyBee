import 'dart:typed_data';

import 'package:kasir_platform/kasir_platform.dart';
import 'package:qr/qr.dart';

import '../../../core/domain/app_error.dart';
import '../../../core/security/recovery_mnemonic.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../l10n/app_localizations_id.dart';
import '../../management/application/management_service.dart';
import 'backup_service.dart';

final class RecoverySheetDestination {
  const RecoverySheetDestination._(this._token, this._generation);
  final String _token;
  final int _generation;
}

/// The native renderer receives bounded text and a vector QR matrix. It does
/// not read the store key or choose any destination.
final class RecoverySheetRenderer {
  const RecoverySheetRenderer(this.platform);

  final KasirPlatform platform;

  Future<Uint8List> render({
    required String entropy,
    required String storeId,
    required String store,
    required String date,
    required String language,
  }) async {
    final strings = language == 'id'
        ? AppLocalizationsId()
        : AppLocalizationsEn();
    final words = RecoveryMnemonic.entropyToMnemonic(entropy).split(' ');
    final qr = QrImage(
      QrCode(
        payload: QrPayload.fromString(
          RecoveryMnemonic.recoveryQr(storeId: storeId, entropy: entropy),
        ),
        errorCorrectLevel: QrErrorCorrectLevel.quartile,
      ),
    );
    final size = qr.moduleCount;
    final matrix = Uint8List(size * size);
    for (var row = 0; row < size; row++) {
      for (var column = 0; column < size; column++) {
        matrix[row * size + column] = qr.isDark(row, column) ? 1 : 0;
      }
    }
    try {
      final encoded = await platform.call<Uint8List>('renderRecoverySheet', {
        'words': words,
        'size': size,
        'qr': matrix,
        'title': strings.m54RecoverySheetTitle,
        'store': '${strings.storeName} · $store',
        'metadata':
            '$date   •   ${RecoveryMnemonic.version}   •   ${storeId.substring(0, 8)}',
        'warning': strings.m54RecoverySheetPaperWarning,
        'wordHeading': strings.m54RecoverySheetWordHeading,
        'qrHeading': strings.m54RecoverySheetQrHeading,
        'instructions': strings.m54RecoverySheetInstructions,
        'footer': strings.m54RecoverySheetFooter,
      });
      // Flutter's Android channel decoder can return an immutable view.
      // Keep an owned buffer so callers can clear the working copy in finally.
      return Uint8List.fromList(encoded);
    } finally {
      matrix.fillRange(0, matrix.length, 0);
    }
  }
}

/// SAF picks an empty target first. A fresh owner proof after returning from
/// SAF is required before the service reads any secret or writes any bytes.
final class RecoverySheetService {
  const RecoverySheetService(this.backup);

  static const ownerPurpose = 'recoverySheet';
  final BackupService backup;

  Future<RecoverySheetDestination?> choose() async {
    await backup.access.authorizeCurrent();
    final generation = backup.database.generation;
    final token = await backup.access.systemInteraction(
      () => backup.platform.callNullable<String>('chooseReportExport', {
        'displayName': 'SkyBee-Recovery-Sheet.pdf',
        'mime': 'application/pdf',
      }),
      discard: (token) async {
        if (token != null) await _cancel(token);
      },
    );
    return token == null ? null : RecoverySheetDestination._(token, generation);
  }

  Future<void> cancel(RecoverySheetDestination target) =>
      _cancel(target._token);

  Future<void> _cancel(String token) =>
      backup.platform.channelCall('cancelReportExport', {'token': token});

  Future<void> output(
    FreshActionProof proof,
    String language, {
    RecoverySheetDestination? target,
    required void Function() requireIntent,
  }) async {
    final access = backup.access;
    final generation = backup.database.generation;
    Uint8List? bytes;
    Future<void> authorized() async {
      requireIntent();
      await access.authorizeCurrent();
      access.requireClaim(proof, ownerPurpose);
      requireIntent();
      if (backup.database.generation != generation ||
          (target != null && target._generation != generation)) {
        throw const AppError('m53CameraStoreChanged');
      }
    }

    try {
      await authorized();
      final data = await backup.recoveryForSheet(proof);
      bytes = await RecoverySheetRenderer(backup.platform).render(
        entropy: data.entropy,
        storeId: data.storeId,
        store: data.store,
        date: data.date,
        language: language,
      );
      await authorized();
      if (target != null) {
        await backup.platform.call<bool>('writeRecoverySheet', {
          'token': target._token,
          'bytes': bytes,
        });
      } else {
        await access.systemInteraction(() {
          requireIntent();
          return backup.platform.call<bool>('shareRecoverySheet', {
            'bytes': bytes,
          });
        });
      }
    } finally {
      if (bytes != null) bytes.fillRange(0, bytes.length, 0);
      access.releaseClaim(proof);
      if (target != null) await cancel(target);
    }
  }
}
