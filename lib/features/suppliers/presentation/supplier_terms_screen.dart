import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/management_session_provider.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/supplier_terms.dart';

/// Warehouse can read the supplier's agreement, but every mutation is owner
/// authorized again by the service. No old receipt becomes paid or indebted.
class SupplierTermsScreen extends StatefulWidget {
  const SupplierTermsScreen({super.key, required this.id});
  final EntityId id;
  @override
  State<SupplierTermsScreen> createState() => _SupplierTermsScreenState();
}

class _SupplierTermsScreenState extends State<SupplierTermsScreen> {
  SupplierTerms? terms;
  bool allowed = false, busy = false, started = false;
  int generation = 0;
  String? error;
  bool get dirty => terms != null && allowed != terms!.allowsCredit;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      generation = context.read<AppServices>().database.generation;
      load();
    }
  }

  void check() {
    if (context.read<AppServices>().database.generation != generation) {
      throw const AppError('m3DraftChanged');
    }
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      check();
      final value = await context.read<AppServices>().suppliers.terms(
        widget.id,
      );
      if (mounted) {
        check();
        setState(() {
          terms = value;
          allowed = value.allowsCredit;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy || terms == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      check();
      final value = await context.read<AppServices>().suppliers.saveTerms(
        widget.id,
        terms!.revision,
        allowsCredit: allowed,
      );
      if (mounted) {
        check();
        setState(() {
          terms = value;
          allowed = value.allowsCredit;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner =
        context.watch<ManagementSessionProvider>().service.role ==
        ManagementRole.owner;
    return ManagementGate(
      capability: ManagementCapability.inventory,
      child: FormExitGuard(
        capability: ManagementCapability.inventory,
        dirty: dirty,
        dirtyCheck: () => dirty,
        busy: busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'm53SupplierTerms')),
            actions: const [LanguageButton()],
          ),
          body: SafeArea(
            child: ListView(
              key: ValueKey(
                terms == null
                    ? 'supplier-terms-loading'
                    : 'supplier-terms-ready',
              ),
              padding: const EdgeInsets.all(16),
              children: [
                if (busy) const LinearProgressIndicator(),
                if (terms != null) Text(terms!.name),
                if (error != null)
                  Text(
                    tr(context, error!),
                    key: const ValueKey('supplier-terms-error'),
                  ),
                Text(tr(context, 'm53SupplierTermsHelp')),
                if (!owner) Text(tr(context, 'm53SupplierTermsReadOnly')),
                if (terms != null)
                  SwitchListTile(
                    key: const ValueKey('supplier-allows-credit'),
                    title: Text(tr(context, 'm53SupplierAllowsCredit')),
                    value: owner ? allowed : terms?.allowsCredit ?? false,
                    onChanged: !owner || busy || terms == null
                        ? null
                        : (value) => setState(() => allowed = value),
                  ),
                if (owner)
                  FilledButton(
                    key: const ValueKey('supplier-terms-save'),
                    onPressed: busy || !dirty ? null : save,
                    child: Text(tr(context, 'save')),
                  ),
                if (!dirty || error == 'm53SupplierTermsChanged')
                  TextButton(
                    onPressed: busy ? null : load,
                    child: Text(tr(context, 'm5Refresh')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
