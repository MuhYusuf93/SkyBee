import 'package:dlibphonenumber/dlibphonenumber.dart';
import 'app_error.dart';

/// Offline syntax/metadata validation only; never probes a phone, SMTP or URL.
/// Phone region belongs to the shop, independent from language/currency.
final class ContactValidation {
  static String? phone(String? input, {String region = 'ID'}) {
    final value = input?.trim() ?? '';
    if (value.isEmpty) return null;
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(value) || value.startsWith('+620')) {
      throw const AppError('m52PhoneInvalid');
    }
    try {
      final util = PhoneNumberUtil.instance;
      final number = util.parse(value, region);
      if (!util.isValidNumber(number)) throw const AppError('m52PhoneInvalid');
      return util.format(number, PhoneNumberFormat.e164);
    } on Object {
      throw const AppError('m52PhoneInvalid');
    }
  }

  static String? email(String? input) {
    final value = input?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@.]+(?:\.[^\s@.]+)+$').hasMatch(value)) {
      throw const AppError('m52EmailInvalid');
    }
    return value;
  }

  static String? website(String? input) {
    var value = input?.trim() ?? '';
    if (value.isEmpty) return null;
    if (!value.contains('://')) value = 'https://$value';
    final uri = Uri.tryParse(value);
    if (value.length > 2048 ||
        value.contains(RegExp(r'\s')) ||
        uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        !RegExp(
          r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$',
        ).hasMatch(uri.host)) {
      throw const AppError('m52WebsiteInvalid');
    }
    return uri.replace(host: uri.host.toLowerCase()).toString();
  }
}
