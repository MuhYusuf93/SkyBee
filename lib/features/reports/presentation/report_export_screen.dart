import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import '../domain/report_models.dart';
import '../domain/operational_report.dart';
import '../application/report_export_service.dart';
import '../application/report_destination_service.dart';

/// Only progress and bounded artifact handles live in the route, never SQL rows.
class ReportExportScreen extends StatefulWidget {
  const ReportExportScreen({super.key, this.filter, this.operational})
    : assert((filter == null) != (operational == null));
  final ReportFilter? filter;
  final OperationalScope? operational;
  @override
  State<ReportExportScreen> createState() => _ReportExportState();
}

class _ReportExportState extends State<ReportExportScreen> {
  final control = ReportExportControl();
  ReportArtifact? artifact;
  ReportDestinationService? destination;
  String? token, message;
  bool busy = false, xlsx = true;
  int rows = 0;
  void cancel() {
    control.cancel();
    final selected = token;
    if (selected != null) unawaited(destination!.cancel(selected));
  }

  Future<void> generate() async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    final app = context.read<AppServices>();
    destination = ReportDestinationService(app.management);
    try {
      void progress(int n) {
        if (mounted) setState(() => rows = n);
      }

      final result = widget.operational != null
          ? await app.operationalReports.export(
              widget.operational!,
              xlsx: xlsx,
              control: control,
              progress: progress,
            )
          : await app.reportExport.create(
              widget.filter!,
              xlsx: xlsx,
              control: control,
              progress: progress,
            );
      if (!mounted) {
        await result.dispose();
        return;
      }
      artifact = result;
      token = await destination!.choose(xlsx: xlsx);
      if (!mounted) {
        if (token != null) await destination!.cancel(token!);
        await result.dispose();
        return;
      }
      message = token == null ? 'm5Cancelled' : 'm51ExportSelected';
    } on ReportExportCancelled {
      message = 'm5Cancelled';
    } on Object {
      message = 'm51ExportFailed';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> write() async {
    if (busy || token == null || artifact == null) return;
    setState(() => busy = true);
    try {
      await destination!.write(token!, artifact!);
      message = control.cancelled ? 'm5Cancelled' : 'm51ExportVerified';
    } on Object {
      message = control.cancelled ? 'm5Cancelled' : 'm51ExportFailed';
    } finally {
      token = null;
      await artifact?.dispose();
      artifact = null;
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    control.cancel();
    if (token != null) unawaited(destination!.cancel(token!));
    if (!busy) unawaited(artifact?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, 'm51Export'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr(context, 'm51ExportPolicy')),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('CSV')),
              ButtonSegment(value: true, label: Text('XLSX')),
            ],
            selected: {xlsx},
            onSelectionChanged: busy || artifact != null
                ? null
                : (v) => setState(() => xlsx = v.single),
          ),
          if (busy) ...[
            const LinearProgressIndicator(),
            Text('${tr(context, 'm51ExportRows')}: $rows'),
            TextButton(onPressed: cancel, child: Text(tr(context, 'cancel'))),
          ],
          if (message != null)
            Text(
              tr(context, message!),
              key: const ValueKey('report-export-status'),
            ),
          FilledButton(
            onPressed: busy || artifact != null || control.cancelled
                ? null
                : generate,
            child: Text(tr(context, 'm51ExportCreate')),
          ),
          if (token != null)
            FilledButton(
              onPressed: busy ? null : write,
              child: Text(tr(context, 'm51ExportWrite')),
            ),
          if (artifact != null && !busy)
            TextButton(
              onPressed: () async {
                if (token != null) await destination!.cancel(token!);
                token = null;
                await artifact!.dispose();
                artifact = null;
                if (mounted) setState(() => message = 'm5Cancelled');
              },
              child: Text(tr(context, 'cancel')),
            ),
        ],
      ),
    ),
  );
}
