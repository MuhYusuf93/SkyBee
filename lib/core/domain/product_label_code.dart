import 'value_types.dart';

/// App-local product identity, not a URL, executable command, GS1 or assigned
/// retail barcode. Existing SKU/barcode values are never rewritten to use it.
abstract final class ProductLabelCode {
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static String encode(EntityId id) {
    if (!_uuid.hasMatch(id.value)) {
      throw const FormatException('m53LabelIdentityInvalid');
    }
    return 'SBP1${id.value}';
  }

  static EntityId? productId(String text) {
    if (!text.startsWith('SBP1') || !_uuid.hasMatch(text.substring(4))) {
      return null;
    }
    // Preserve the stored identity's case as well as its digits. Canonicalizing
    // UUID text could make a legacy uppercase primary key unreachable.
    return EntityId(text.substring(4));
  }
}
