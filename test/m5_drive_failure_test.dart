import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/features/backup/application/drive_rest.dart';

void main() {
  test(
    'disabled Drive API has actionable status without response disclosure',
    () {
      final body = jsonEncode({
        'error': {
          'message': 'Private upstream message: never expose this text',
          'errors': [
            {'domain': 'usageLimits', 'reason': 'accessNotConfigured'},
          ],
        },
      });
      final failure = DriveRest.failure(403, body);
      expect(failure.code, 'driveApiNotEnabled');
      expect(failure.retryable, isFalse);
      expect(failure.toString(), isNot(contains('Private')));
    },
  );

  test(
    'Google ErrorInfo SERVICE_DISABLED is specific to the Drive service',
    () {
      String body(String service) => jsonEncode({
        'error': {
          'details': [
            {
              '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
              'reason': 'SERVICE_DISABLED',
              'domain': 'googleapis.com',
              'metadata': {'service': service},
            },
          ],
        },
      });
      expect(
        DriveRest.failure(403, body('drive.googleapis.com')).code,
        'driveApiNotEnabled',
      );
      expect(
        DriveRest.failure(403, body('unrelated.googleapis.com')).code,
        'driveForbiddenOrNotConfigured',
      );
    },
  );

  test(
    'unstructured error messages never imply an API configuration cause',
    () {
      for (final body in [
        'not JSON accessNotConfigured',
        jsonEncode({
          'error': {'message': 'accessNotConfigured'},
        }),
        jsonEncode({
          'error': {'errors': 'accessNotConfigured'},
        }),
        jsonEncode({'error': null}),
      ]) {
        expect(
          DriveRest.failure(403, body).code,
          'driveForbiddenOrNotConfigured',
        );
      }
      expect(
        DriveRest.failure(
          500,
          '{"error":{"errors":[{"reason":"accessNotConfigured"}]}}',
        ).retryable,
        isTrue,
      );
    },
  );
}
