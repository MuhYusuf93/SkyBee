import 'package:integration_test/integration_test.dart';
import '../test/printer_document_test.dart' show printerDocumentSuite;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  printerDocumentSuite();
}
