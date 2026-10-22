/// Identity is transport specific. USB serial hashes are stable only when the
/// Android adapter can disambiguate them; temporary IDs require re-selection
/// after detach/process restart. Never infer a printer from VID/PID alone.
abstract final class PrinterDevice {
  static String transport(String id) =>
      id.startsWith('usb:') ? 'usb' : 'bluetooth';
  static bool valid(String id) =>
      !id.contains(RegExp(r'\s')) &&
      (RegExp(r'^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$').hasMatch(id) ||
          RegExp(
            r'^usb:t:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}:[0-9]{1,3}$',
          ).hasMatch(id) ||
          RegExp(
            r'^usb:s:[0-9a-f]{4}:[0-9a-f]{4}:[0-9a-f]{64}:[0-9]{1,3}$',
          ).hasMatch(id));
}
