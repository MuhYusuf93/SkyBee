import '../../../core/domain/app_error.dart';
import '../../../data/database/database_coordinator.dart';
import '../../cashier_lock/application/cashier_lock_service.dart';
import '../../management/application/management_service.dart';
import '../../settings/application/settings_service.dart';
import '../domain/barcode_camera.dart';

/// A route-scoped generation, not an access grant. Every camera acceptance still
/// crosses the existing lookup/mutation services and their persisted guards.
final class BarcodeAccess {
  BarcodeAccess(
    this.database,
    this.management,
    this.cashier, {
    required this.inventory,
  }) : generation = database.generation;
  final DatabaseCoordinator database;
  final ManagementService management;
  final CashierLockService cashier;
  final bool inventory;
  final int generation;
  Future<void> authorize() => database.read((sql) async {
    if (generation != database.generation) {
      throw const AppError('m53CameraStoreChanged');
    }
    if (!(await SettingsService.policyOn(sql)).barcode) {
      throw const AppError('m53CameraFeatureOff');
    }
    if (inventory) {
      await management.authorize(
        sql,
        capability: ManagementCapability.inventory,
      );
    } else {
      final proof = await CashierLockService.beginOn(sql, cashier);
      await CashierLockService.endOn(sql, proof);
    }
  });
  Future<CameraAvailability> permission(
    Future<CameraAvailability> Function() action,
  ) async {
    await authorize();
    final result = inventory
        ? await management.systemInteraction(action)
        : await action();
    await authorize();
    return result;
  }
}
