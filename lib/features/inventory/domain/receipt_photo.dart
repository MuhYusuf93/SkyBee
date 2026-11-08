import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';

/// A re-encoded camera frame in memory. Reject metadata-bearing JPEGs before
/// the page can be persisted or accepted from a staged backup.
final class ReceiptPhotoAsset {
  ReceiptPhotoAsset._(Uint8List jpeg, this.width, this.height)
    : jpeg = Uint8List.fromList(jpeg).asUnmodifiableView(),
      hash = sha256.convert(jpeg).toString();

  static const maxBytes = 768 * 1024;
  static const maxWidth = 1280;
  static const maxHeight = 2560;
  static const maxPages = 8;
  static const invalid = AppError('m54ReceiptPhotoInvalid');

  final Uint8List jpeg;
  final int width, height;
  final String hash;

  factory ReceiptPhotoAsset.fromJpeg(Uint8List bytes) {
    if (bytes.length < 16 ||
        bytes.length > maxBytes ||
        bytes[0] != 0xff ||
        bytes[1] != 0xd8 ||
        bytes[bytes.length - 2] != 0xff ||
        bytes.last != 0xd9) {
      throw invalid;
    }
    int? width, height;
    var offset = 2;
    while (offset + 4 < bytes.length) {
      if (bytes[offset++] != 0xff) throw invalid;
      while (offset < bytes.length && bytes[offset] == 0xff) {
        offset++;
      }
      if (offset + 2 >= bytes.length) throw invalid;
      final marker = bytes[offset++];
      final length = (bytes[offset] << 8) | bytes[offset + 1];
      if (length < 2 || offset + length >= bytes.length) throw invalid;
      // A camera frame's normal encoder can include JFIF or Adobe color
      // metadata. EXIF, XMP, ICC profiles, IPTC and comments are omitted.
      if (marker == 0xfe ||
          (marker >= 0xe1 && marker <= 0xef && marker != 0xee)) {
        throw invalid;
      }
      if (marker == 0xc0) {
        if (length < 8 || width != null || bytes[offset + 2] != 8) {
          throw invalid;
        }
        height = (bytes[offset + 3] << 8) | bytes[offset + 4];
        width = (bytes[offset + 5] << 8) | bytes[offset + 6];
      }
      if (marker == 0xda) {
        if (width == null ||
            height == null ||
            width < 64 ||
            height < 64 ||
            width > maxWidth ||
            height > maxHeight) {
          throw invalid;
        }
        // Baseline camera output has one scan. Later APP segments, appended
        // data and concatenated images cannot be hidden in the scan payload.
        for (var index = offset + length; index < bytes.length - 2; index++) {
          if (bytes[index] != 0xff) continue;
          final next = bytes[++index];
          if (next != 0 && (next < 0xd0 || next > 0xd7)) throw invalid;
        }
        return ReceiptPhotoAsset._(bytes, width, height);
      }
      offset += length;
    }
    throw invalid;
  }
}

final class ReceiptPhotoPage {
  ReceiptPhotoPage(Map<String, Object?> row) : row = Map.unmodifiable(row);
  final Map<String, Object?> row;
  EntityId get id => EntityId(row['id'] as String);
  int get position => row['position'] as int;
  int get width => row['width'] as int;
  int get height => row['height'] as int;
  int get rotation => row['quarter_turns'] as int;
  int get bytes => row['byte_length'] as int;
}
