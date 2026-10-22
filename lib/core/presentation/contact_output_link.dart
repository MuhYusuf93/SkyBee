import 'package:flutter/material.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:provider/provider.dart';
import '../../app/app_services.dart';
import '../domain/contact_validation.dart';
import '../../l10n/localization.dart';

/// Output only. Resolves current local-number metadata on the explicit tap;
/// editing a field never launches another app or contacts an external server.
class ContactOutputLink extends StatelessWidget {
  const ContactOutputLink.phone(
    this.value, {
    super.key,
    this.managementProtected = false,
  }) : phone = true;
  const ContactOutputLink.website(
    this.value, {
    super.key,
    this.managementProtected = false,
  }) : phone = false;
  final String value;
  final bool phone, managementProtected;
  static String phoneUrl(String value, {String region = 'ID'}) {
    final canonical = ContactValidation.phone(value, region: region);
    if (canonical == null) throw const FormatException('Empty phone');
    return 'https://wa.me/${canonical.substring(1)}';
  }

  static String websiteUrl(String value) =>
      ContactValidation.website(value) ??
      (throw const FormatException('Empty website'));
  Future<void> open(BuildContext context) async {
    try {
      final services = context.read<AppServices>();
      final generation = services.management.generation;
      if (managementProtected) services.management.requireAccess();
      final url = phone
          ? phoneUrl(value, region: await services.settings.phoneRegion())
          : websiteUrl(value);
      if (!context.mounted) return;
      if (managementProtected) {
        services.management.requireAccess();
        if (generation != services.management.generation) return;
      }
      await const KasirPlatform().channelCall('openContactUrl', {
        'url': url,
        'phone': phone,
      });
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'm52ContactOpenFailed'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: value.trim().isEmpty ? null : () => open(context),
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      alignment: Alignment.centerLeft,
    ),
    child: Text(value),
  );
}
