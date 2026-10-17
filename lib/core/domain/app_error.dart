/// Semantic message code; presentation localizes it, never raw SQL/auth details.
final class AppError implements Exception {
  const AppError(this.message, {this.arguments = const {}});
  final String message;
  final Map<String, Object> arguments;
  @override
  String toString() => message;
}

String safeError(Object error) => switch (error) {
  AppError() =>
    error.arguments.isEmpty
        ? error.message
        : '${error.message}:${error.arguments['count']}',
  FormatException() || RangeError() => 'checkQuantityAmountAndDateUseWhole',
  _ => 'operationFailedTryAgainOrCheckDevice',
};
