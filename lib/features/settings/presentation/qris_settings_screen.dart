import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import 'language_button.dart';
import '../application/qris_asset_service.dart';

/// Owner controls one local image. Selecting a file creates a preview draft;
/// replacing or removing the active image requires an explicit Save.
class QrisSettingsScreen extends StatefulWidget {
  const QrisSettingsScreen({super.key});
  @override
  State<QrisSettingsScreen> createState() => _QrisSettingsScreenState();
}

class _QrisSettingsScreenState extends State<QrisSettingsScreen> {
  QrisImageAsset? baseline, draft;
  bool busy = false, loaded = false, remove = false;
  String? error;
  bool get dirty => remove || (draft != null && draft!.hash != baseline?.hash);
  QrisImageAsset? get visible => remove ? null : draft ?? baseline;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> _run(
    Future<void> Function(QrisAssetService service) action,
  ) async {
    if (busy) return;
    final service = context.read<AppServices>().qrisAssets;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action(service);
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() => _run((service) async {
    final value = await service.ownerImage();
    if (mounted) {
      setState(() {
        baseline = value;
        loaded = true;
        draft = null;
        remove = false;
      });
    }
  });

  Future<void> choose() => _run((service) async {
    final selected = await service.choose();
    if (mounted && selected != null) {
      setState(() {
        draft = selected;
        remove = false;
      });
    }
  });

  Future<void> save() => _run((service) async {
    final value = visible;
    await service.save(value, expectedHash: baseline?.hash);
    if (mounted) {
      setState(() {
        baseline = value;
        draft = null;
        remove = false;
      });
    }
  });

  @override
  Widget build(BuildContext context) {
    final asset = visible;
    return ManagementGate(
      child: FormExitGuard(
        dirty: dirty,
        busy: busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'm54QrisImageTitle')),
            actions: const [LanguageButton()],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(tr(context, 'm54QrisImageHelp')),
                if (busy) const LinearProgressIndicator(),
                if (error != null) Text(tr(context, error!)),
                if (loaded) ...[
                  if (asset != null)
                    SizedBox(
                      height: 260,
                      child: InteractiveViewer(
                        child: Image.memory(
                          asset.bytes,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    )
                  else
                    Text(tr(context, 'm54QrisImageMissing')),
                  OutlinedButton(
                    onPressed: busy ? null : choose,
                    child: Text(tr(context, 'm54QrisImageChoose')),
                  ),
                  if (asset != null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              draft = null;
                              remove = baseline != null;
                            }),
                      child: Text(tr(context, 'm54QrisImageRemove')),
                    ),
                  FilledButton(
                    onPressed: busy || !dirty ? null : save,
                    child: Text(tr(context, 'save')),
                  ),
                  if (dirty)
                    TextButton(
                      onPressed: busy ? null : load,
                      child: Text(tr(context, 'cancel')),
                    ),
                ] else if (!busy)
                  TextButton(
                    onPressed: load,
                    child: Text(tr(context, 'tryAgain')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
