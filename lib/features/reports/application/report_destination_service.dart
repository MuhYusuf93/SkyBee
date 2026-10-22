import 'package:kasir_platform/kasir_platform.dart';
import '../../management/application/management_service.dart';
import 'report_export_service.dart';

/// Picking an output is untrusted and writes zero report bytes. The explicit
/// second action requires a live, persisted-epoch authorization after return.
final class ReportDestinationService {
  const ReportDestinationService(
    this.access, {
    this.platform = const KasirPlatform(),
  });
  final ManagementService access;
  final KasirPlatform platform;
  Future<String?> choose({required bool xlsx}) => access.systemInteraction(
    () => platform.callNullable<String>('chooseReportExport', {
      'displayName':
          'kasir_report_${DateTime.now().millisecondsSinceEpoch}.${xlsx ? 'xlsx' : 'csv'}',
      'mime': xlsx
          ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          : 'text/csv',
    }),
    discard: (token) async {
      if (token != null) await cancel(token);
    },
  );
  Future<void> cancel(String token) =>
      platform.channelCall('cancelReportExport', {'token': token});
  Future<void> write(String token, ReportArtifact artifact) async {
    try {
      await access.authorizeCurrent();
      final generation = access.generation;
      await platform
          .call<bool>('writeReportExport', {
            'token': token,
            'path': artifact.file.path,
          })
          .timeout(const Duration(minutes: 2));
      if (generation != access.generation) {
        throw StateError('reportSessionChanged');
      }
      await access.authorizeCurrent();
    } catch (_) {
      await cancel(token);
      rethrow;
    }
  }
}
