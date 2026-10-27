import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/member_models.dart';

/// Owner edits a stable profile; sale snapshots and receivable balances are
/// never editable here. Services recheck role and revision around the write.
class MemberForm extends StatefulWidget {
  const MemberForm({super.key, this.member});
  final MemberProfile? member;
  @override
  State<MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<MemberForm> {
  final name = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController();
  final requestId = const IdGenerator().next();
  bool busy = false;
  String? error;
  late String baseline;
  String get current =>
      jsonEncode([name.text.trim(), phone.text.trim(), address.text.trim()]);
  @override
  void initState() {
    super.initState();
    name.text = widget.member?.name ?? '';
    phone.text = widget.member?.phone ?? '';
    address.text = widget.member?.address ?? '';
    baseline = current;
    for (final controller in [name, phone, address]) {
      controller.addListener(edited);
    }
  }

  void edited() {
    if (mounted) setState(() {});
  }

  Future<void> save() async {
    if (busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final service = context.read<AppServices>().members;
      final input = MemberInput(
        name: name.text,
        phone: phone.text,
        address: address.text,
      );
      final old = widget.member;
      if (old == null) {
        await service.create(input, requestId: requestId);
      } else {
        await service.update(old.id, old.revision, input);
      }
      if (!mounted) return;
      setState(() {
        baseline = current;
        busy = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = safeError(e);
        });
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [name, phone, address]) {
      controller.removeListener(edited);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: FormExitGuard(
      busy: busy,
      dirty: current != baseline,
      dirtyCheck: () => current != baseline,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            tr(
              context,
              widget.member == null ? 'm53MemberCreate' : 'm53Members',
            ),
          ),
          actions: const [LanguageButton()],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.member?.needsReview ?? false)
              Text(tr(context, 'm53MemberRepairRequired')),
            ManagedTextField(
              key: const ValueKey('member-owner-name'),
              controller: name,
              enabled: !busy,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: tr(context, 'm53MemberName'),
              ),
            ),
            const SizedBox(height: 12),
            ManagedTextField(
              key: const ValueKey('member-owner-phone'),
              controller: phone,
              enabled: !busy,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: tr(context, 'm53MemberPhone'),
                helperText: tr(context, 'm53MemberPhoneHelp'),
              ),
            ),
            const SizedBox(height: 12),
            ManagedTextField(
              key: const ValueKey('member-owner-address'),
              controller: address,
              enabled: !busy,
              decoration: InputDecoration(
                labelText: tr(context, 'm53MemberAddress'),
              ),
            ),
            if (error != null)
              Text(
                tr(context, error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(tr(context, busy ? 'loading' : 'save')),
            ),
          ],
        ),
      ),
    ),
  );
}
