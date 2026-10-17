/// Safe semantic codes only. Native SQL exceptions may include bound key bytes;
/// they must not cross into a framework error, log, report or screen.
final class DatabaseSecurityError implements Exception {
  const DatabaseSecurityError(this.code);
  final String code;
  @override
  String toString() => code;
}
