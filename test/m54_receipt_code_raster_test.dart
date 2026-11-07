import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/domain/sale_receipt_code.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/features/printer/application/receipt_code_layout.dart';
import 'package:kasir_app/features/printer/application/receipt_layout.dart';
import 'package:kasir_app/features/printer/domain/code128_modules.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final code = SaleReceiptCode.issue(const IdGenerator().next());
  ReceiptCodeLayout render(PrinterProfile profile) =>
      ReceiptCodeLayout.forReceipt(
        token: code.token,
        qrText: code.qr,
        profile: profile,
      );

  test(
    'M54 receipt code128 draws two-dot modules and quiet zones in 58 mm',
    () async {
      const profile = PrinterProfile();
      final symbol = render(profile);
      expect(symbol.format, ReceiptCodeFormat.code128);
      expect(symbol.width, 352);
      final modules = Code128Modules.numeric(code.token);
      expect(modules, hasLength(176));
      expect(modules.take(10).any((bit) => bit), isFalse);
      expect(modules.skip(166).any((bit) => bit), isFalse);
      expect(
        modules.skip(10).take(11).map((v) => v ? 1 : 0).join(),
        '11010011100',
      );
      var strip = 0;
      await for (final tile in symbol.tiles(
        profile,
        ReceiptLayout.rasterRows,
      )) {
        try {
          expect(tile.width, 384);
          expect(tile.height, 24);
          if (strip++ == 0) {
            final packed = await ReceiptLayout.encodeTile(tile);
            final bits = List.generate(
              tile.width,
              (x) => (packed[8 + 4 * 48 + x ~/ 8] & (128 >> (x % 8))) != 0,
            );
            expect(bits.take(36).any((v) => v), isFalse);
            expect(bits.skip(16).take(352), [
              for (final bit in modules) ...[bit, bit],
            ]);
            expect(bits.skip(348).any((v) => v), isFalse);
          }
        } finally {
          tile.dispose();
        }
      }
      expect(strip, 3);
    },
  );

  test(
    'M54 receipt format round trips and falls back to an unscaled QR',
    () async {
      const qr = PrinterProfile(receiptCode: ReceiptCodeFormat.qr);
      expect(
        PrinterProfile.fromJson(qr.toJson()).receiptCode,
        ReceiptCodeFormat.qr,
      );
      const narrow = PrinterProfile(dots: 192, left: 24, right: 24);
      for (final profile in [qr, narrow]) {
        final symbol = render(profile);
        expect(symbol.format, ReceiptCodeFormat.qr);
        expect(symbol.width, symbol.height);
        expect(symbol.width, lessThanOrEqualTo(profile.effectiveDots));
        var height = 0;
        await for (final tile in symbol.tiles(
          profile,
          ReceiptLayout.rasterRows,
        )) {
          try {
            height += tile.height;
            expect(tile.width, profile.dots);
          } finally {
            tile.dispose();
          }
        }
        expect(height, symbol.height);
      }
    },
  );
}
