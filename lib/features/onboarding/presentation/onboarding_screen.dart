import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../l10n/localization.dart';
import '../../management/application/management_service.dart';
import '../../management/presentation/pin_boxes.dart';
import '../../printer/presentation/printer_settings_screen.dart';
import '../../settings/domain/store_feature_policy.dart';
import '../../settings/presentation/locale_provider.dart';
import 'onboarding_controller.dart';

/// A route-local wizard. Only text controllers retain raw PINs, and recovery
/// plaintext exists solely until acknowledgement; neither enters draft state.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onCompleted});
  final VoidCallback onCompleted;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  late final OnboardingController state;
  final _name = TextEditingController(),
      _address = TextEditingController(),
      _contact = TextEditingController();
  final _pins = List.generate(4, (_) => TextEditingController());
  final _focus = List.generate(4, (_) => FocusNode());
  bool _active = true, _visible = false, _redo = false, _showRecovery = true;
  int _pinEdit = 0, _lastSubmitted = -1;
  String? _recoveryCode;
  OnboardingPinProof? _proof;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state = OnboardingController(context.read<AppServices>().onboarding);
    unawaited(_load());
  }

  Future<void> _load() async {
    await state.load();
    if (!mounted) return;
    _name.text = state.draft.name;
    _address.text = state.draft.address;
    _contact.text = state.draft.contact;
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (!mounted) return;
    setState(() {
      _active = value == AppLifecycleState.resumed;
      if (!_active) {
        _visible = false;
        _showRecovery = false;
      }
    });
    if (!_active && _proof == null) unawaited(state.autosave());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.dispose();
    for (final controller in [_name, _address, _contact, ..._pins]) {
      controller.dispose();
    }
    for (final focus in _focus) {
      focus.dispose();
    }
    _recoveryCode = null;
    _proof = null;
    super.dispose();
  }

  Widget _languages() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final language in ['id', 'en'])
        TextButton(
          key: ValueKey('setup-language-$language'),
          onPressed: () => state.run(() async {
            await context.read<LocaleProvider>().selectLanguage(language);
          }),
          child: Text(language.toUpperCase()),
        ),
    ],
  );
  Future<void> _back() async {
    if (state.busy || _proof != null) return;
    if (state.step > 1) {
      await state.move(state.step - 1);
    } else {
      await state.run(() async {
        await state.flush();
        await SystemNavigator.pop();
      });
    }
  }

  void _pinChanged(String value) {
    _pinEdit++;
    final count = state.draft.taskPattern == 3 ? 4 : 2;
    if (_pins.take(count).every((c) => c.text.length == 4) &&
        _lastSubmitted != _pinEdit) {
      _lastSubmitted = _pinEdit;
      unawaited(_prepare());
    }
  }

  Future<void> _prepare() => state.run(() async {
    final result = await state.prepare(
      ownerPin: _pins[0].text,
      confirmation: _pins[1].text,
      warehousePin: state.draft.taskPattern == 3 ? _pins[2].text : null,
      warehouseConfirmation: state.draft.taskPattern == 3
          ? _pins[3].text
          : null,
    );
    for (final pin in _pins) {
      pin.clear();
    }
    if (!mounted) return;
    setState(() {
      _recoveryCode = result.recoveryCode;
      _proof = result.proof;
      _showRecovery = _active;
      _visible = false;
    });
  });
  Future<void> _acknowledge() => state.run(() async {
    await state.acknowledge(_proof!);
    if (!mounted) return;
    setState(() {
      _proof = null;
      _recoveryCode = null;
      _redo = false;
    });
  });
  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (state.step == 7) {
      await state.run(() async {
        await state.finish();
        if (mounted) widget.onCompleted();
      });
    } else if (state.step == 3 && !(state.progress?.pinsReady ?? false)) {
      await _prepare();
    } else {
      await state.move(state.step + 1);
    }
  }

  Future<void> _printer() => state.run(() async {
    // Set only non-secret preference before opening the existing public route.
    await state.flush();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const PrinterSettingsScreen(publicAccess: true),
      ),
    );
  });
  Widget _help(String key) => IconButton(
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: SingleChildScrollView(child: Text(tr(context, key))),
        actions: [
          _languages(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'close')),
          ),
        ],
      ),
    ),
    icon: const Icon(Icons.help_outline),
  );
  Widget _text(
    TextEditingController controller,
    String key,
    ValueChanged<String> changed, {
    int lines = 1,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextField(
      controller: controller,
      enabled: !state.busy,
      maxLines: lines,
      maxLength: maxLength,
      keyboardType: identical(controller, _contact)
          ? TextInputType.phone
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: tr(context, key),
        border: const OutlineInputBorder(),
      ),
      onChanged: changed,
    ),
  );
  Widget _feature(
    String label,
    String help,
    bool checked,
    ValueChanged<bool> change, {
    bool review = false,
  }) => CheckboxListTile(
    title: Text(tr(context, label)),
    secondary: review ? null : _help(help),
    value: checked,
    onChanged: review || state.busy ? null : (value) => change(value!),
  );
  List<Widget> _features({bool review = false}) => [
    _feature(
      'm53SetupWholesale',
      'm53WholesaleHelp',
      state.draft.wholesale,
      (v) => state.update(state.draft.copyWith(wholesale: v)),
      review: review,
    ),
    _feature(
      'm53SetupPackaging',
      'm53SetupPackagingHelp',
      state.draft.packaging,
      (v) => state.update(state.draft.copyWith(packaging: v)),
      review: review,
    ),
    _feature(
      'm53SetupCost',
      'm53CostHelp',
      state.draft.cost,
      (v) => state.update(state.draft.copyWith(cost: v)),
      review: review,
    ),
    _feature(
      'm53SetupBarcode',
      'm53BarcodeHelp',
      state.draft.barcode,
      (v) => state.update(state.draft.copyWith(barcode: v)),
      review: review,
    ),
    _feature(
      'm53SetupExpiry',
      'm53ExpiryHelp',
      state.draft.expiry,
      (v) => state.update(state.draft.copyWith(expiry: v)),
      review: review,
    ),
  ];
  List<Widget> _security() {
    if (_proof != null) {
      return [
        Text(tr(context, 'saveRecoveryCode')),
        Text(tr(context, 'writeThisCodeDownAndStoreIt')),
        if (_showRecovery)
          SelectableText(
            _recoveryCode!,
            key: const ValueKey('setup-recovery-code'),
          )
        else
          TextButton(
            onPressed: () => setState(() => _showRecovery = true),
            child: Text(tr(context, 'm53SetupShowRecovery')),
          ),
        FilledButton(
          key: const ValueKey('setup-recovery-ack'),
          onPressed: state.busy || !_showRecovery ? null : _acknowledge,
          child: Text(tr(context, 'iHaveSavedIt')),
        ),
      ];
    }
    if ((state.progress?.pinsReady ?? false) && !_redo) {
      return [
        Text(tr(context, 'm53SetupPinsReady')),
        TextButton(
          onPressed: state.busy ? null : () => setState(() => _redo = true),
          child: Text(tr(context, 'm53SetupRedoPin')),
        ),
      ];
    }
    final labels = [
      'm53SetupOwnerPin',
      'm53SetupOwnerConfirm',
      'm53WarehousePin',
      'm53SetupWarehouseConfirm',
    ];
    return [
      Text(tr(context, 'm53SetupPinHelp')),
      for (var i = 0; i < (state.draft.taskPattern == 3 ? 4 : 2); i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: KeyedSubtree(
            key: ValueKey('setup-pin-$i'),
            child: PinBoxes(
              controller: _pins[i],
              focusNode: _focus[i],
              label: tr(context, labels[i]),
              enabled: !state.busy,
              visible: _visible,
              onChanged: _pinChanged,
              onSubmitted: (_) => _prepare(),
            ),
          ),
        ),
      SwitchListTile(
        title: Text(tr(context, 'm53SetupVisiblePin')),
        value: _visible,
        onChanged: state.busy ? null : (v) => setState(() => _visible = v),
      ),
      FilledButton(
        key: const ValueKey('setup-prepare-pin'),
        onPressed: state.busy ? null : _prepare,
        child: Text(tr(context, 'm53SetupPreparePin')),
      ),
    ];
  }

  List<Widget> _body() => switch (state.step) {
    1 => [
      _text(
        _name,
        'storeName',
        (v) => state.update(state.draft.copyWith(name: v)),
        maxLength: 120,
      ),
      _text(
        _address,
        'm53SetupAddress',
        (v) => state.update(state.draft.copyWith(address: v)),
        lines: 3,
        maxLength: 500,
      ),
      _text(
        _contact,
        'm53SetupContact',
        (v) => state.update(state.draft.copyWith(contact: v)),
        maxLength: 64,
      ),
    ],
    2 => [
      CheckboxListTile(
        title: Text(tr(context, 'm53SetupSelfManaged')),
        value: state.draft.selfManaged,
        onChanged: state.busy
            ? null
            : (v) => state.update(
                state.draft.copyWith(
                  selfManaged: v,
                  taskPattern: v == true ? 1 : null,
                ),
              ),
      ),
      DropdownButtonFormField<int>(
        key: ValueKey('setup-task-${state.draft.selfManaged}'),
        initialValue: state.draft.taskPattern,
        isExpanded: true,
        decoration: InputDecoration(labelText: tr(context, 'm53TaskPattern')),
        items: [
          for (final pattern in [1, 2, 3])
            DropdownMenuItem(
              value: pattern,
              child: Text(
                tr(context, 'm53Pattern$pattern'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: state.busy || state.draft.selfManaged
            ? null
            : (v) => state.update(state.draft.copyWith(taskPattern: v)),
      ),
      const SizedBox(height: 16),
      Text(tr(context, 'm53SetupTaskHelp')),
    ],
    3 => _security(),
    4 => [
      if (state.draft.taskPattern == 3)
        Text(tr(context, 'm53SetupStockRequired'))
      else
        DropdownButtonFormField<StockMode>(
          key: const ValueKey('setup-stock-mode'),
          initialValue: state.draft.stockMode,
          isExpanded: true,
          decoration: InputDecoration(labelText: tr(context, 'm53StockMode')),
          items: [
            for (final mode in StockMode.values)
              DropdownMenuItem(
                value: mode,
                child: Text(tr(context, 'm53Stock${mode.name}')),
              ),
          ],
          onChanged: state.busy
              ? null
              : (v) => state.update(state.draft.copyWith(stockMode: v)),
        ),
      const SizedBox(height: 16),
      Text(tr(context, 'm53StockHelp')),
      Text(tr(context, 'm53CostHelp')),
    ],
    5 => [Text(tr(context, 'm53SetupOptionalFeatures')), ..._features()],
    6 => [
      Text(tr(context, 'm53SetupPrinterHelp')),
      FilledButton.tonal(
        key: const ValueKey('setup-open-printer'),
        onPressed: state.busy
            ? null
            : () {
                state.update(state.draft.copyWith(wantsPrinter: true));
                unawaited(_printer());
              },
        child: Text(tr(context, 'm53SetupOpenPrinter')),
      ),
    ],
    _ => [
      ListTile(
        title: Text(tr(context, 'storeName')),
        subtitle: Text(state.draft.name),
      ),
      if (state.draft.address.trim().isNotEmpty)
        ListTile(
          title: Text(tr(context, 'm53SetupAddress')),
          subtitle: Text(state.draft.address),
        ),
      if (state.draft.contact.trim().isNotEmpty)
        ListTile(
          title: Text(tr(context, 'm53SetupContact')),
          subtitle: Text(state.draft.contact),
        ),
      ListTile(
        title: Text(tr(context, 'm53TaskPattern')),
        subtitle: Text(tr(context, 'm53Pattern${state.draft.taskPattern}')),
      ),
      ListTile(
        title: Text(tr(context, 'm53StockMode')),
        subtitle: Text(tr(context, 'm53Stock${state.draft.stockMode.name}')),
      ),
      Text(tr(context, 'm53SetupPinsReady')),
      ..._features(review: true),
      Text(tr(context, 'm53SetupOffline')),
    ],
  };
  String get _title => switch (state.step) {
    1 => 'm53SetupIdentity',
    2 => 'm53TaskPattern',
    3 => 'm53SetupSecurity',
    4 => 'm53StockMode',
    5 => 'm53SetupFeatures',
    6 => 'm53SetupPrinter',
    _ => 'm53SetupReview',
  };
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'm53SetupTitle')),
          actions: [_languages()],
        ),
        body: !_active
            ? Center(child: Text(tr(context, 'm53SetupSecurityHidden')))
            : state.progress == null
            ? Center(
                child: state.error == null
                    ? const CircularProgressIndicator()
                    : Text(tr(context, state.error!)),
              )
            : Column(
                children: [
                  if (state.busy) const LinearProgressIndicator(),
                  Expanded(
                    child: SingleChildScrollView(
                      key: ValueKey('setup-step-${state.step}'),
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${tr(context, 'm53SetupStep')} ${state.step}/7',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tr(context, _title),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              ..._body(),
                              if (state.error != null)
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    tr(context, state.error!),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              if (state.saved)
                                Text(tr(context, 'm53SetupSaved')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_proof == null)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            if (state.step > 1)
                              TextButton(
                                key: const ValueKey('setup-back'),
                                onPressed: state.busy ? null : _back,
                                child: Text(tr(context, 'm53SetupBack')),
                              ),
                            const Spacer(),
                            FilledButton(
                              key: const ValueKey('setup-next'),
                              onPressed:
                                  state.busy || (state.step == 3 && _redo)
                                  ? null
                                  : _next,
                              child: Text(
                                tr(
                                  context,
                                  state.step == 7
                                      ? 'm53SetupFinish'
                                      : state.step == 6 &&
                                            !state.draft.wantsPrinter
                                      ? 'm53SetupSkipPrinter'
                                      : 'm53SetupNext',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    ),
  );
}
