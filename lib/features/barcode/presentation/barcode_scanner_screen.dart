import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../l10n/localization.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/management_gate.dart';
import '../application/barcode_access.dart';
import '../domain/barcode_camera.dart';
import 'barcode_scanner_controller.dart';

/// Shared cashier/warehouse camera route. A selected frame needs confirmation,
/// then Scan again before another physical scan can change the caller's draft.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({
    super.key,
    required this.lookup,
    this.inventory = false,
    this.registerUnknown,
    this.camera,
  });
  final Future<BarcodeFeedback> Function(String code) lookup;
  final Future<void> Function(String code)? registerUnknown;
  final bool inventory;
  final BarcodeCamera? camera;
  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver, RouteAware {
  late final BarcodeScannerController controller;
  late final StreamSubscription<int> management;
  late final StreamSubscription<void> cashier;
  late final StreamSubscription<Object?> replacement;
  RouteObserver<ModalRoute<dynamic>>? observer;
  @override
  void initState() {
    super.initState();
    final services = context.read<AppServices>();
    final access = BarcodeAccess(
      services.database,
      services.management,
      services.cashierLock,
      inventory: widget.inventory,
    );
    controller = BarcodeScannerController(
      camera: widget.camera ?? services.barcodeCameraFactory(),
      authorize: access.authorize,
      permission: access.permission,
      lookup: widget.lookup,
    );
    management = services.management.sessionChanges.listen((_) {
      if (widget.inventory) controller.suspend();
    });
    cashier = services.cashierLock.changes.listen((_) => controller.suspend());
    replacement = services.database.replacements.listen(
      (_) => controller.suspend(clear: true),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<RouteObserver<ModalRoute<dynamic>>?>();
    if (observer != next) {
      observer?.unsubscribe(this);
      observer = next;
    }
    final route = ModalRoute.of(context);
    if (route != null) observer?.subscribe(this, route);
  }

  @override
  void didPushNext() => controller.suspend(inactive: true);
  @override
  void didPopNext() => controller.resume();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.resume();
    } else {
      controller.suspend(inactive: true);
    }
  }

  @override
  void dispose() {
    observer?.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(management.cancel());
    unawaited(cashier.cancel());
    unawaited(replacement.cancel());
    controller.dispose();
    super.dispose();
  }

  Future<void> accept() async {
    await controller.accept();
    if (!mounted) return;
    // A platform may suppress audio. The visible outcome is always primary.
    try {
      await SystemSound.play(
        controller.feedback?.success == true
            ? SystemSoundType.click
            : SystemSoundType.alert,
      );
    } catch (_) {
      /* Visual fallback remains. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(tr(context, 'm53CameraScan'))),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(tr(context, 'm53CameraHelp')),
                    if (controller.busy) const LinearProgressIndicator(),
                    if (controller.error != null)
                      Text(tr(context, controller.error!)),
                    FilledButton(
                      key: const ValueKey('barcode-camera-arm'),
                      onPressed: controller.busy ? null : controller.prepare,
                      child: Text(
                        tr(
                          context,
                          controller.previewReady
                              ? 'm53CameraScanAgain'
                              : 'm53CameraStart',
                        ),
                      ),
                    ),
                    Text(
                      tr(
                        context,
                        controller.armed ? 'm53CameraAim' : 'm53CameraPaused',
                      ),
                    ),
                    if (controller.value case final value?) ...[
                      Text(tr(context, 'm53CameraSelectedCode')),
                      SelectableText(value.text),
                      if (controller.choices.length > 1) ...[
                        Text(tr(context, 'm53CameraEquivalentCodes')),
                        RadioGroup<String>(
                          groupValue: value.format,
                          onChanged: (format) {
                            if (format != null) {
                              controller.selectCode(
                                controller.choices.singleWhere(
                                  (c) => c.format == format,
                                ),
                              );
                            }
                          },
                          child: Column(
                            children: [
                              for (final option in controller.choices)
                                RadioListTile<String>(
                                  key: ValueKey('camera-code-${option.format}'),
                                  value: option.format,
                                  enabled:
                                      !controller.busy && !controller.consumed,
                                  title: Text(
                                    '${option.format.replaceAll('_', '-')}: ${option.text}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      FilledButton(
                        key: const ValueKey('barcode-camera-accept'),
                        onPressed: controller.busy || controller.consumed
                            ? null
                            : accept,
                        child: Text(tr(context, 'm53CameraUseCode')),
                      ),
                    ],
                    if (controller.feedback case final outcome?) ...[
                      Text(tr(context, outcome.message)),
                      if (outcome.unknown &&
                          widget.inventory &&
                          widget.registerUnknown != null)
                        OutlinedButton(
                          onPressed: controller.busy
                              ? null
                              : () async {
                                  controller.suspend();
                                  await widget.registerUnknown!(
                                    controller.value!.text,
                                  );
                                },
                          child: Text(tr(context, 'm53CameraRegisterProduct')),
                        ),
                    ],
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text(tr(context, 'm53CameraManualFallback')),
                    ),
                  ],
                ),
              ),
            ),
            if (controller.previewReady)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 280,
                  child: controller.camera.needsPlatformView
                      ? AndroidView(
                          viewType: 'kasir_app/barcode_camera',
                          onPlatformViewCreated: controller.attach,
                          creationParamsCodec: const StandardMessageCodec(),
                        )
                      : const ColoredBox(color: Colors.black),
                ),
              ),
          ],
        ),
      ),
    );
    return widget.inventory
        ? ManagementGate(
            capability: ManagementCapability.inventory,
            child: body,
          )
        : body;
  }
}
