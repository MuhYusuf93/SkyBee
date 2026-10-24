import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';

void main() {
  test('legacy footer default becomes three without rewriting queued jobs', () {
    for (var feed = 0; feed <= 8; feed++) {
      final legacy = PrinterProfile(feed: feed, topFeed: 2).toJson()
        ..remove('footerFeedVersion');
      final original = jsonEncode(legacy);
      final settings = PrinterProfile.fromJson(legacy);
      expect(settings.feed, feed == 6 ? 3 : feed);
      expect(settings.topFeed, 2);
      expect(PrinterProfile.fromSnapshotJson(legacy).feed, feed);
      expect(jsonEncode(legacy), original);
      expect(PrinterProfile.fromJson(settings.toJson()).feed, settings.feed);
    }
  });

  test(
    'all explicit manual footer values survive serialization and reopen',
    () {
      for (var feed = 0; feed <= 8; feed++) {
        final saved =
            jsonDecode(jsonEncode(PrinterProfile(feed: feed).toJson()))
                as Map<String, dynamic>;
        expect(PrinterProfile.fromJson(saved).feed, feed);
        expect(PrinterProfile.fromJson(saved).topFeed, 3);
        expect(PrinterProfile.fromSnapshotJson(saved).feed, feed);
      }
    },
  );
}
