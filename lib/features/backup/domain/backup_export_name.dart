/// Display names are metadata for ACTION_CREATE_DOCUMENT, never private paths.
/// Keep the archive extension and a single-component filename while
/// preserving user text (including spaces and Unicode) instead of slugging it.
final class BackupExportName {
  static const extension = '.kasirbackup';
  static String normalize(String input) {
    var value = input.trim();
    if (!value.toLowerCase().endsWith(extension)) value += extension;
    final stem = value.substring(0, value.length - extension.length);
    if (stem.trim().isEmpty ||
        stem.startsWith('.') ||
        stem.endsWith('.') ||
        value.length > 128 ||
        RegExp(r'[<>:"/\\|?*\x00-\x1f\x7f]').hasMatch(value)) {
      throw const FormatException('backupExportNameInvalid');
    }
    return '${value.substring(0, value.length - extension.length)}$extension';
  }
}
