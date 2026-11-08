/// Code 128 with mandatory horizontal quiet zones. All callers render
/// these modules at an integer number of dots to preserve the check symbol.
abstract final class Code128Modules {
  static const quiet = 10;
  static const _startB = 104;
  static const _startC = 105;
  static const _switchB = 100;
  static const _stop = 106;

  static List<bool> numeric(String digits) {
    if (digits.length.isOdd || !RegExp(r'^[0-9]{2,80}$').hasMatch(digits)) {
      throw const FormatException('invalidCode128Data');
    }
    final data = [
      for (var at = 0; at < digits.length; at += 2)
        int.parse(digits.substring(at, at + 2)),
    ];
    return _encode(_startC, data);
  }

  /// Preserve existing product barcodes literally, including leading zeros.
  /// For odd digit runs, keep compact Code C pairs and switch for the last digit.
  static List<bool> text(String value) {
    if (value.isEmpty ||
        value.length > 80 ||
        value.codeUnits.any((unit) => unit < 32 || unit > 126)) {
      throw const FormatException('m54LabelCode128Unavailable');
    }
    if (RegExp(r'^[0-9]{4,}$').hasMatch(value)) {
      if (value.length.isEven) return numeric(value);
      return _encode(_startC, [
        for (var i = 0; i < value.length - 1; i += 2)
          int.parse(value.substring(i, i + 2)),
        _switchB,
        value.codeUnitAt(value.length - 1) - 32,
      ]);
    }
    return _encode(_startB, [for (final ascii in value.codeUnits) ascii - 32]);
  }

  static List<bool> _encode(int start, List<int> data) {
    var check = start;
    for (var i = 0; i < data.length; i++) {
      check += (i + 1) * data[i];
    }
    return [
      for (var i = 0; i < quiet; i++) false,
      for (final symbol in [start, ...data, check % 103, _stop])
        for (var run = 0; run < _patterns[symbol].length; run++)
          for (var dot = 0; dot < _patterns[symbol].codeUnitAt(run) - 48; dot++)
            run.isEven,
      for (var i = 0; i < quiet; i++) false,
    ];
  }

  // Symbol widths adapted from ZXing core 3.4.1 Code128Reader.CODE_PATTERNS.
  // Copyright ZXing authors. Apache-2.0, assets/third_party/barcode-core-LICENSE.txt.
  static const _patterns = [
    '212222',
    '222122',
    '222221',
    '121223',
    '121322',
    '131222',
    '122213',
    '122312',
    '132212',
    '221213',
    '221312',
    '231212',
    '112232',
    '122132',
    '122231',
    '113222',
    '123122',
    '123221',
    '223211',
    '221132',
    '221231',
    '213212',
    '223112',
    '312131',
    '311222',
    '321122',
    '321221',
    '312212',
    '322112',
    '322211',
    '212123',
    '212321',
    '232121',
    '111323',
    '131123',
    '131321',
    '112313',
    '132113',
    '132311',
    '211313',
    '231113',
    '231311',
    '112133',
    '112331',
    '132131',
    '113123',
    '113321',
    '133121',
    '313121',
    '211331',
    '231131',
    '213113',
    '213311',
    '213131',
    '311123',
    '311321',
    '331121',
    '312113',
    '312311',
    '332111',
    '314111',
    '221411',
    '431111',
    '111224',
    '111422',
    '121124',
    '121421',
    '141122',
    '141221',
    '112214',
    '112412',
    '122114',
    '122411',
    '142112',
    '142211',
    '241211',
    '221114',
    '413111',
    '241112',
    '134111',
    '111242',
    '121142',
    '121241',
    '114212',
    '124112',
    '124211',
    '411212',
    '421112',
    '421211',
    '212141',
    '214121',
    '412121',
    '111143',
    '111341',
    '131141',
    '114113',
    '114311',
    '411113',
    '411311',
    '113141',
    '114131',
    '311141',
    '411131',
    '211412',
    '211214',
    '211232',
    '2331112',
  ];
}
