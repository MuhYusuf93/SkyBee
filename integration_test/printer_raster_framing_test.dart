import 'package:integration_test/integration_test.dart';
import '../test/printer_raster_framing_test.dart'
    show printerRasterFramingSuite;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  printerRasterFramingSuite();
}
