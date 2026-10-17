import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/features/backup/domain/backup_export_name.dart';

void main() {
  test('keeps human names and normalizes the archive extension once', () {
    expect(BackupExportName.normalize(' Toko 名 17 '), 'Toko 名 17.kasirbackup');
    expect(BackupExportName.normalize('name.KASIRBACKUP'), 'name.kasirbackup');
    expect(BackupExportName.normalize('name.kasirbackup'), 'name.kasirbackup');
    expect(BackupExportName.normalize('x' * 116), '${'x' * 116}.kasirbackup');
  });
  test(
    'rejects empty names, paths, control characters and oversized titles',
    () {
      for (final value in [
        '',
        ' ',
        '.kasirbackup',
        '../file',
        r'C:\file',
        'folder/file',
        'file\nname',
        'file\u007f',
        'file?',
        'file:',
        '.hidden',
        'name..kasirbackup',
        'x' * 117,
      ]) {
        expect(
          () => BackupExportName.normalize(value),
          throwsFormatException,
          reason: 'Reject invalid filename without emitting user text',
        );
      }
    },
  );
}
