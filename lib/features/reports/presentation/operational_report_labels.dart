/// Persisted/export field names retain snake_case; ARB semantic identifiers
/// follow the repository's camelCase contract, including dynamic report fields.
String operationalReportKey(String prefix, String code) =>
    '$prefix${code.split('_').map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}').join()}';
