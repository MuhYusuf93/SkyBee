import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

/// Flat CSV and typed, inline-string SpreadsheetML. Money is exact text, never
/// a floating point spreadsheet value. Rows flush every SQL page, not per book.
final class ReportFileWriter {
  ReportFileWriter(this.directory, this.xlsx, {List<String>? fieldKeys})
    : fieldKeys = List.unmodifiable(fieldKeys ?? columns);
  final Directory directory;
  final bool xlsx;
  final List<String> fieldKeys;
  final List<String> sheets = [];
  IOSink? _sink;
  int _row = 0;
  static const columns = [
    'section',
    'event_id',
    'sale_id',
    'created_utc',
    'kind',
    'origin',
    'reversed',
    'currency',
    'scale',
    'amount_minor',
    'amount_decimal',
    'cost_micros',
    'cost_status',
    'customer',
    'reason',
    'product_id',
    'sku',
    'barcode',
    'name',
    'quantity',
    'price_minor',
    'pricing_mode',
    'stock_tracking',
    'cost_basis',
    'gross_minor',
    'discount_minor',
    'promo_snapshot',
    'stock_pcs',
    'pcs_per_pack',
    'base_unit',
    'pack_label',
    'size_milli',
    'size_unit',
    'shelf',
    'note',
    'archived',
    'metric',
    'value',
    'unit',
    'zone',
    'period_start_utc',
    'period_end_exclusive_utc',
    'captured_utc',
  ];
  static String csv(Object? value) {
    var text = value?.toString() ?? '';
    // CSV has no cell types. Neutralize leading formula/control characters;
    // consumers must import identifier/money columns as text to retain zeros.
    if (value is String &&
        RegExp(r'^[\s\x00-\x1f]*[=+\-@]|^[\t\r\n]').hasMatch(text)) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  static String xml(String value) => value
      .replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f]'), '\uFFFD')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
  Future<void> start(String name) async {
    if (xlsx) {
      await endSheet();
      sheets.add(name);
      _row = 0;
      _sink = File(
        p.join(directory.path, 'sheet${sheets.length}.xml'),
      ).openWrite();
      _sink!.write(
        '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
      );
      _write(fieldKeys);
    } else if (_sink == null) {
      _sink = File(p.join(directory.path, 'report.csv')).openWrite();
      _sink!.write('\uFEFF');
      _write(fieldKeys);
    }
  }

  void add(Map<String, Object?> row) =>
      _write(fieldKeys.map((c) => row[c]).toList());
  void _write(List<Object?> values) {
    if (!xlsx) {
      _sink!.write('${values.map(csv).join(',')}\r\n');
      return;
    }
    if (++_row > 1048576) {
      throw StateError('reportSheetLimit');
    }
    _sink!.write('<row r="$_row">');
    for (var n = 0; n < values.length; n++) {
      var index = n + 1, col = '';
      while (index > 0) {
        index--;
        col = '${String.fromCharCode(65 + index % 26)}$col';
        index ~/= 26;
      }
      final value = values[n];
      if (value is int && value.abs() <= 999999999999999) {
        _sink!.write('<c r="$col$_row" t="n"><v>$value</v></c>');
      } else {
        _sink!.write(
          '<c r="$col$_row" t="inlineStr"><is><t xml:space="preserve">${xml(value?.toString() ?? '')}</t></is></c>',
        );
      }
    }
    _sink!.write('</row>');
  }

  Future<void> flush() async => _sink?.flush();
  Future<void> endSheet() async {
    if (_sink == null) return;
    if (xlsx) _sink!.write('</sheetData></worksheet>');
    await _sink!.flush();
    await _sink!.close();
    _sink = null;
  }

  Future<File> finish() async {
    await endSheet();
    if (!xlsx) return File(p.join(directory.path, 'report.csv'));
    final root = directory.path, names = List<String>.of(sheets);
    // Store streaming file entries: no complete XML/workbook is held in RAM.
    // ZIP runs off the UI isolate; OpenXML uses explicit cell types, no formulas.
    await Isolate.run(() async {
      const rel =
          'http://schemas.openxmlformats.org/package/2006/relationships';
      const office =
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
      final parts = <String, String>{
        '[Content_Types].xml':
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>${[for (var i = 1; i <= names.length; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}</Types>',
        '_rels/.rels':
            '<Relationships xmlns="$rel"><Relationship Id="r1" Type="$office/officeDocument" Target="xl/workbook.xml"/></Relationships>',
        'xl/workbook.xml':
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="$office"><sheets>${[for (var i = 0; i < names.length; i++) '<sheet name="${xml(names[i])}" sheetId="${i + 1}" r:id="r${i + 1}"/>'].join()}</sheets></workbook>',
        'xl/_rels/workbook.xml.rels':
            '<Relationships xmlns="$rel">${[for (var i = 1; i <= names.length; i++) '<Relationship Id="r$i" Type="$office/worksheet" Target="worksheets/sheet$i.xml"/>'].join()}</Relationships>',
      };
      final zip = ZipFileEncoder()
        ..create(p.join(root, 'report.xlsx'), level: ZipFileEncoder.store);
      try {
        for (final part in parts.entries) {
          zip.addArchiveFile(ArchiveFile.string(part.key, part.value));
        }
        for (var i = 1; i <= names.length; i++) {
          await zip.addFile(
            File(p.join(root, 'sheet$i.xml')),
            'xl/worksheets/sheet$i.xml',
            ZipFileEncoder.store,
          );
        }
      } finally {
        await zip.close();
      }
    });
    return File(p.join(root, 'report.xlsx'));
  }
}
