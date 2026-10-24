import 'package:flutter_test/flutter_test.dart';
import 'printer_raster_framing_test.dart' as framing;
import 'printer80_probe_test.dart' as probe;

/// One build for native raster framing and read-only paired-device inventory.
/// Physical output remains disabled unless explicitly authorized by defines.
void main() {
  group('native raster', framing.main);
  group('paired inventory', probe.main);
}
