import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/data/database/durable_promotion.dart';

void main() {
  for (final phase in ['journal', 'oldMoved', 'newMoved', 'committed']) {
    test(
      'promotion restart after $phase recovers an entire verified file',
      () async {
        final dir = await Directory.systemTemp.createTemp('kasir_promotion_');
        final promotion = DurablePromotion('${dir.path}/database');
        try {
          await File(promotion.livePath).writeAsString('old', flush: true);
          await File(promotion.stagePath).writeAsString('new', flush: true);
          promotion.testPhase = (current) async {
            if (current == phase) throw StateError('Synthetic termination');
          };
          await expectLater(promotion.promote(() async {}), throwsStateError);
          await DurablePromotion(promotion.livePath).recover();
          expect(
            await File(promotion.livePath).readAsString(),
            phase == 'committed' ? 'new' : 'old',
          );
          expect(await File(promotion.oldPath).exists(), false);
          expect(await File(promotion.stagePath).exists(), false);
          await DurablePromotion(promotion.livePath).recover();
        } finally {
          await dir.delete(recursive: true);
        }
      },
    );
  }
  test(
    'unknown file hash stops recovery with original source retained',
    () async {
      final dir = await Directory.systemTemp.createTemp('kasir_promotion_');
      final promotion = DurablePromotion('${dir.path}/database');
      try {
        await File(promotion.livePath).writeAsString('old');
        await File(promotion.stagePath).writeAsString('new');
        promotion.testPhase = (phase) async {
          if (phase == 'newMoved') throw StateError('Synthetic termination');
        };
        await expectLater(promotion.promote(() async {}), throwsStateError);
        await File(promotion.livePath).writeAsString('unrecognized');
        await expectLater(promotion.recover(), throwsStateError);
        expect(await File(promotion.oldPath).readAsString(), 'old');
        expect(await File(promotion.journalPath).exists(), true);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
