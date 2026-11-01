import 'dart:io';
import 'package:kasir_platform/kasir_platform.dart';
import '../../../data/database/database_gate.dart';

/// Private plaintext preparation outlives SQL reads (for example XLSX ZIP IO).
/// Reset takes this lease before SQL; native SAF streams have a separate drain.
/// Do not retain it while waiting for a user or a report destination picker.
DatabaseGate defaultReportWorkGate([
  KasirPlatform platform = const KasirPlatform(),
]) => Platform.isAndroid
    ? AndroidDatabaseGate(platform, 'report-work')
    : const DirectDatabaseGate();
