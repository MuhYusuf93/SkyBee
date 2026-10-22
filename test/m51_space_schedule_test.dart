import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';
import 'package:kasir_app/features/backup/application/space_maintenance_service.dart';

class _Schedule extends WorkmanagerPlatform {
  int calls = 0;
  @override
  Future<void> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    OutOfQuotaPolicy? outOfQuotaPolicy,
    ForegroundServiceConfig? foregroundServiceConfig,
    bool expedited = false,
  }) async {
    calls++;
    expect(uniqueName, SpaceMaintenanceService.task);
    expect(taskName, uniqueName);
    expect(initialDelay, const Duration(hours: 6));
    expect(constraints!.requiresCharging, true);
    expect(constraints.requiresDeviceIdle, true);
    expect(existingWorkPolicy, ExistingWorkPolicy.keep);
    expect(expedited, false);
    expect(inputData, isNull);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'space scheduler requests idle charging delayed work with no secret payload',
    () async {
      final previous = WorkmanagerPlatform.instance, recording = _Schedule();
      WorkmanagerPlatform.instance = recording;
      try {
        await SpaceMaintenanceService.enqueue(Workmanager());
        expect(recording.calls, 1);
      } finally {
        WorkmanagerPlatform.instance = previous;
      }
    },
  );
}
