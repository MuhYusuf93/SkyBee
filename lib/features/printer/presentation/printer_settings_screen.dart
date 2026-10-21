import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/managed_text_field.dart';
import '../application/receipt_layout.dart';
import '../domain/printer_profile.dart';
import 'printer_settings_provider.dart';
import 'receipt_preview.dart';

/// Form/controller lifetime spans Android permission/pair dialogs, while the
/// gate removes all protected content immediately until PIN is entered again.
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});
  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  PrinterSettingsProvider? _state;
  final dots = TextEditingController(text: '384'),
      left = TextEditingController(text: '8'),
      right = TextEditingController(text: '8'),
      shift = TextEditingController(text: '0'),
      feed = TextEditingController(text: '${const PrinterProfile().feed}');
  String? device;
  String name = '';
  int paper = 58, font = 24, logoPercent = 100, lineGap = 6;
  bool bold = false, logo = true;
  String header = 'center', footer = 'center';
  String? outcome;
  PrinterProfile profile() => PrinterProfile(
    paperMm: paper,
    dots: int.parse(dots.text),
    left: int.parse(left.text),
    right: int.parse(right.text),
    shift: int.parse(shift.text),
    font: font,
    bold: bold,
    logo: logo,
    headerAlign: header,
    footerAlign: footer,
    feed: int.parse(feed.text),
    logoPercent: logoPercent,
    lineGap: lineGap,
  )..validate();
  void choose(Map<String, Object?> row) {
    setState(() {
      device = (row['device_id'] ?? row['id']) as String;
      name = row['name'] as String? ?? '';
      if (row['settings_json'] != null) {
        apply(
          PrinterProfile.fromJson(
            jsonDecode(row['settings_json'] as String) as Map<String, dynamic>,
          ),
        );
      }
    });
  }

  void apply(PrinterProfile value) {
    paper = value.paperMm;
    font = value.font;
    logoPercent = value.logoPercent;
    lineGap = value.lineGap;
    bold = value.bold;
    logo = value.logo;
    header = value.headerAlign;
    footer = value.footerAlign;
    dots.text = '${value.dots}';
    left.text = '${value.left}';
    right.text = '${value.right}';
    shift.text = '${value.shift}';
    feed.text = '${value.feed}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state ??= PrinterSettingsProvider(context.read<AppServices>().printers)
      ..load();
  }

  @override
  void dispose() {
    _state?.dispose();
    for (final c in [dots, left, right, shift, feed]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> task(Future<void> Function() action) async {
    await _state!.run(action);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _state!,
    child: ManagementGate(
      child: Consumer<PrinterSettingsProvider>(
        builder: (context, state, _) => Scaffold(
          appBar: AppBar(title: Text(tr(context, 'm51PrinterTitle'))),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'bluetooth', label: Text('Bluetooth')),
                    ButtonSegment(value: 'usb', label: Text('USB')),
                  ],
                  selected: {state.transport},
                  onSelectionChanged: state.busy
                      ? null
                      : (value) async {
                          setState(() {
                            device = null;
                            name = '';
                            outcome = null;
                          });
                          await state.selectTransport(value.single);
                        },
                ),
                Text(tr(context, state.usb ? 'm51UsbHelp' : 'm5PrinterHelp')),
                if (state.busy)
                  LinearProgressIndicator(
                    semanticsLabel: tr(context, 'loading'),
                  ),
                if (device == null) ...[
                  if (state.message != null && !state.permissionDenied)
                    Text(tr(context, state.message!)),
                  if (outcome != null) Text(tr(context, outcome!)),
                  if (!state.permissionDenied)
                    Text(tr(context, state.connectionStatus)),
                  if (state.connectedDevice != null)
                    Text(state.connectedDevice!),
                ],
                if (!state.usb) Text(tr(context, 'm5BluetoothPermissionHelp')),
                Wrap(
                  spacing: 8,
                  children: [
                    if (state.usb)
                      OutlinedButton(
                        onPressed: state.busy ? null : state.loadUsb,
                        child: Text(tr(context, 'm51UsbLoad')),
                      ),
                    OutlinedButton(
                      onPressed: state.busy ? null : state.chooseLogo,
                      child: Text(tr(context, 'm5ChooseLogo')),
                    ),
                    if (state.pendingLogo != null)
                      FilledButton(
                        onPressed: state.busy ? null : state.applyLogo,
                        child: Text(tr(context, 'm5ApplyLogo')),
                      ),
                    TextButton(
                      onPressed: state.busy ? null : state.removeLogo,
                      child: Text(tr(context, 'm5RemoveLogo')),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (!state.usb)
                      OutlinedButton(
                        onPressed: state.busy ? null : state.paired,
                        child: Text(tr(context, 'm5Paired')),
                      ),
                    if (!state.usb)
                      OutlinedButton(
                        onPressed: state.busy ? null : state.discover,
                        child: Text(tr(context, 'm5Discover')),
                      ),
                    if (state.scanning)
                      OutlinedButton(
                        onPressed: state.service.cancel,
                        child: Text(tr(context, 'cancel')),
                      ),
                  ],
                ),
                if (state.permissionDenied)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      tr(context, 'm5PrinterPermissionDenied'),
                      key: const ValueKey('printer-permission-notice'),
                    ),
                  ),
                for (final row in state.devices)
                  ListTile(
                    title: Text(row['name'] as String? ?? ''),
                    subtitle: Text('${row['id']}'),
                    selected: device == row['id'],
                    onTap: state.busy ? null : () => choose(row),
                    trailing: state.usb
                        ? const Icon(Icons.usb)
                        : row['paired'] == true
                        ? Tooltip(
                            message: tr(context, 'm5Paired'),
                            child: const Icon(Icons.link),
                          )
                        : TextButton(
                            onPressed: state.busy
                                ? null
                                : () => task(() async {
                                    await state.service.pair(
                                      row['id'] as String,
                                    );
                                    outcome = 'm5PairRequested';
                                  }),
                            child: Text(tr(context, 'm5Pair')),
                          ),
                  ),
                if (state.usb &&
                    state.devices.any((row) => row['sessionOnly'] == true))
                  Text(tr(context, 'm51UsbTemporary')),
                const Divider(),
                Text(tr(context, 'm5SavedPrinters')),
                for (final row in state.saved)
                  ListTile(
                    title: Text(row['name'] as String),
                    subtitle: Text(row['device_id'] as String),
                    selected: device == null
                        ? row['selected'] == 1
                        : device == row['device_id'],
                    onTap: state.busy ? null : () => choose(row),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: state.busy ? null : () => state.load(),
                      child: Text(tr(context, 'm5FirstPage')),
                    ),
                    if (state.saved.length == 50)
                      TextButton(
                        onPressed: state.busy
                            ? null
                            : () => state.load(
                                after: state.saved.last['device_id'] as String,
                              ),
                        child: Text(tr(context, 'm5NextPage')),
                      ),
                  ],
                ),
                if (device != null) ...[
                  Text('$name · $device'),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 58, label: Text('58 mm')),
                      ButtonSegment(value: 80, label: Text('80 mm')),
                    ],
                    selected: {paper},
                    onSelectionChanged: state.busy
                        ? null
                        : (value) => setState(
                            () => apply(
                              value.single == 80
                                  ? PrinterProfile.generic80
                                  : const PrinterProfile(),
                            ),
                          ),
                  ),
                  for (final field in [
                    (dots, 'm5PrintableDots'),
                    (left, 'm5LeftDots'),
                    (right, 'm5RightDots'),
                    (shift, 'm5ShiftDots'),
                    (feed, 'm5Feed'),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ManagedTextField(
                        controller: field.$1,
                        enabled: !state.busy,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: tr(context, field.$2),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  Text(tr(context, 'm5GeometryHelp')),
                  SegmentedButton<int>(
                    segments: [
                      for (final size in [18, 24, 32])
                        ButtonSegment(value: size, label: Text('$size dots')),
                    ],
                    selected: {font},
                    onSelectionChanged: state.busy
                        ? null
                        : (value) => setState(() => font = value.single),
                  ),
                  SwitchListTile(
                    title: Text(tr(context, 'm5Bold')),
                    value: bold,
                    onChanged: state.busy
                        ? null
                        : (value) => setState(() => bold = value),
                  ),
                  SwitchListTile(
                    title: Text(tr(context, 'm5Logo')),
                    value: logo,
                    onChanged: state.busy
                        ? null
                        : (value) => setState(() => logo = value),
                  ),
                  for (final option in [
                    ('m5LogoSize', logoPercent, [50, 75, 100]),
                    ('m5LineGap', lineGap, [0, 3, 6, 9]),
                  ])
                    DropdownButtonFormField<int>(
                      key: ValueKey('${option.$1}-${option.$2}'),
                      initialValue: option.$2,
                      decoration: InputDecoration(
                        labelText: tr(context, option.$1),
                      ),
                      items: [
                        for (final value in option.$3)
                          DropdownMenuItem(
                            value: value,
                            child: Text(
                              option.$1 == 'm5LogoSize'
                                  ? '$value%'
                                  : '$value dots',
                            ),
                          ),
                      ],
                      onChanged: state.busy
                          ? null
                          : (value) => setState(() {
                              if (option.$1 == 'm5LogoSize') {
                                logoPercent = value!;
                              } else {
                                lineGap = value!;
                              }
                            }),
                    ),
                  for (final section in ['header', 'footer'])
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        '$section-${section == 'header' ? header : footer}',
                      ),
                      initialValue: section == 'header' ? header : footer,
                      decoration: InputDecoration(
                        labelText: tr(
                          context,
                          section == 'header'
                              ? 'm5HeaderAlign'
                              : 'm5FooterAlign',
                        ),
                      ),
                      items: [
                        for (final value in ['left', 'center', 'right'])
                          DropdownMenuItem(
                            value: value,
                            child: Text(
                              tr(context, switch (value) {
                                'center' => 'm5AlignCenter',
                                'right' => 'm5AlignRight',
                                _ => 'm5AlignLeft',
                              }),
                            ),
                          ),
                      ],
                      onChanged: state.busy
                          ? null
                          : (value) => setState(() {
                              if (section == 'header') {
                                header = value!;
                              } else {
                                footer = value!;
                              }
                            }),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      // Keep feedback with the action at the end of this long
                      // form. Updating an offscreen header looks like no-op.
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilledButton(
                            onPressed: state.busy
                                ? null
                                : () async {
                                    await state.connect(device!);
                                    if (mounted &&
                                        state.connectedDevice != null &&
                                        state.usb) {
                                      setState(
                                        () => device = state.connectedDevice,
                                      );
                                    }
                                  },
                            child: Text(tr(context, 'm5Connect')),
                          ),
                          Semantics(
                            liveRegion: true,
                            child: Text(tr(context, state.connectionStatus)),
                          ),
                          if (state.message != null && !state.permissionDenied)
                            Text(tr(context, state.message!)),
                          if (outcome != null) Text(tr(context, outcome!)),
                        ],
                      ),
                      if (state.usb &&
                          state.message == 'm51UsbPermissionDenied')
                        TextButton(
                          onPressed: state.busy
                              ? null
                              : () async {
                                  await state.connect(
                                    device!,
                                    retryUsbPermission: true,
                                  );
                                  if (mounted &&
                                      state.connectedDevice != null) {
                                    setState(
                                      () => device = state.connectedDevice,
                                    );
                                  }
                                },
                          child: Text(tr(context, 'm51UsbRetryPermission')),
                        ),
                      TextButton(
                        onPressed: state.busy ? null : state.checkConnection,
                        child: Text(tr(context, 'm5CheckConnection')),
                      ),
                      FilledButton(
                        onPressed: state.busy
                            ? null
                            : () => task(() async {
                                device = await state.service.save(
                                  device!,
                                  name,
                                  profile(),
                                );
                                outcome = 'm5PrinterSaved';
                              }),
                        child: Text(tr(context, 'save')),
                      ),
                      OutlinedButton(
                        onPressed: state.busy
                            ? null
                            : () => setState(
                                () => apply(
                                  paper == 80
                                      ? PrinterProfile.generic80
                                      : const PrinterProfile(),
                                ),
                              ),
                        child: Text(tr(context, 'm5ResetTemplate')),
                      ),
                      OutlinedButton(
                        onPressed: state.busy
                            ? null
                            : () {
                                try {
                                  final layout = ReceiptLayout.calibration(
                                    profile(),
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (context) => ManagementGate(
                                        child: Scaffold(
                                          appBar: AppBar(
                                            title: Text(
                                              tr(context, 'm5Preview'),
                                            ),
                                          ),
                                          body: ReceiptPreview(
                                            layout: layout,
                                            logo: state.currentLogo,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                } catch (_) {
                                  setState(() => outcome = 'm5ProfileInvalid');
                                }
                              },
                        child: Text(tr(context, 'm5Preview')),
                      ),
                      OutlinedButton(
                        onPressed: state.busy
                            ? null
                            : () => task(() async {
                                final printing = context
                                    .read<AppServices>()
                                    .printing;
                                device = await state.service.save(
                                  device!,
                                  name,
                                  profile(),
                                );
                                final id = await printing.prepareCalibration();
                                final status = await printing.send(id);
                                outcome = status == 'submitted'
                                    ? 'm5DataSent'
                                    : status == 'unknown'
                                    ? 'm5DeliveryUnknown'
                                    : 'm5NotSent';
                              }),
                        child: Text(tr(context, 'm5TestPrint')),
                      ),
                      TextButton(
                        onPressed: state.busy
                            ? null
                            : () => task(() async {
                                await state.service.forget(device!);
                                device = null;
                                outcome = 'm5PrinterForgotten';
                              }),
                        child: Text(tr(context, 'm5ForgetPrinter')),
                      ),
                      TextButton(
                        onPressed: state.busy ? null : state.disconnect,
                        child: Text(tr(context, 'm5Disconnect')),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
