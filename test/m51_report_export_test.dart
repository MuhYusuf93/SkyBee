import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/m51_report_export_suite.dart';
import 'dart:io';
import 'package:kasir_app/features/reports/application/report_file_writer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  m51ReportExportSuite(databaseFactoryFfi);
  test(
    'XLSX writer preserves full SQLite money and literal formulas',
    () async {
      final directory = await Directory(
        'build/m51-report-reader/precision',
      ).create(recursive: true);
      final writer = ReportFileWriter(directory, true);
      await writer.start('Exact');
      writer.add({
        'section': 'precision',
        'barcode': '000123',
        'amount_minor': '9223372036854775807',
        'amount_decimal': '92233720368547758.07',
        'quantity': 9223372036854775807,
        'name': '=1+2',
        'note': '@SUM(1,2)\n"Quoted", Indonesia — English',
      });
      await writer.finish();
    },
  );
}
