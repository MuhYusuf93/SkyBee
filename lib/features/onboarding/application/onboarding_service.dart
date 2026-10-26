import '../../../core/domain/app_error.dart';
import '../../../data/database/database_coordinator.dart';
import '../../management/application/management_service.dart';
import '../data/onboarding_store.dart';
import '../domain/onboarding_draft.dart';

/// Persists only whitelisted non-secret draft values. Completion is one SQL
/// transaction so failure cannot leave a usable PIN with half-applied setup.
final class OnboardingService {
  const OnboardingService(this.database, this.access);
  final DatabaseCoordinator database;
  final ManagementService access;
  Future<bool> get needed => database.read(OnboardingStore.needsSetup);
  Future<OnboardingProgress> load() => database.transaction((dbTxn) async {
    await OnboardingStore.requireFresh(dbTxn);
    if ((await dbTxn.query('onboarding_progress')).isEmpty) {
      await dbTxn.insert('onboarding_progress', {
        'id': 1,
        'draft_json': const OnboardingDraft().encode(),
        'step': 1,
        'revision': 1,
        'pins_ready': 0,
      });
    }
    return OnboardingStore.progress(dbTxn);
  });
  Future<OnboardingProgress> save(
    OnboardingDraft value, {
    required int step,
    required int revision,
  }) => database.transaction((dbTxn) async {
    final previous = await OnboardingStore.expect(dbTxn, revision);
    value.validateBounds();
    if (step < 1 || step > 7) throw const AppError('m53SetupDraftInvalid');
    final changedPattern = value.taskPattern != previous.draft.taskPattern;
    final ready = previous.pinsReady && !changedPattern;
    if (step > 3 && !ready) throw const AppError('m53SetupPinsRequired');
    if (step > 1) {
      final region =
          (await dbTxn.query(
                'store_settings',
                columns: ['phone_region'],
              )).single['phone_region']
              as String;
      value.identity(region);
    }
    if (changedPattern) await dbTxn.delete('onboarding_credentials');
    await dbTxn.update('onboarding_progress', {
      'draft_json': value.encode(),
      'step': step,
      'revision': revision + 1,
      'pins_ready': ready ? 1 : 0,
      if (changedPattern) 'preparation_id': null,
    }, where: 'id=1');
    return OnboardingStore.progress(dbTxn);
  });

  Future<void> finish(int revision) => database
      .transaction((dbTxn) async {
        final current = await OnboardingStore.expect(dbTxn, revision);
        if (!current.pinsReady || current.step != 7) {
          throw const AppError('m53SetupPinsRequired');
        }
        final region =
            (await dbTxn.query(
                  'store_settings',
                  columns: ['phone_region'],
                )).single['phone_region']
                as String;
        final identity = current.draft.identity(region);
        final credentials = await dbTxn.query('onboarding_credentials');
        final expected = current.draft.taskPattern == 3 ? 2 : 1;
        if (credentials.length != expected ||
            !credentials.any((r) => r['role'] == 'owner') ||
            (expected == 2 &&
                !credentials.any((r) => r['role'] == 'warehouse'))) {
          throw const AppError('m53SetupPinsRequired');
        }
        for (final row in credentials) {
          final values = Map<String, Object?>.from(row)..remove('role');
          await dbTxn.insert(
            row['role'] == 'owner'
                ? 'management_credentials'
                : 'warehouse_credentials',
            values,
          );
        }
        await dbTxn.update('store_settings', {
          'name': identity.name,
          'address': identity.address,
          'contact_number': identity.contact,
        }, where: 'id=1');
        final policyRevision =
            (await dbTxn.query(
                  'store_feature_policy',
                  columns: ['revision'],
                )).single['revision']
                as int;
        await dbTxn.update('store_feature_policy', {
          ...current.draft.policy(policyRevision).values,
          'onboarding_completed': 1,
          'revision': policyRevision + 1,
        }, where: 'id=1');
        await dbTxn.rawUpdate(
          'UPDATE management_access_epoch SET revision=revision+1 WHERE id=1',
        );
        await access.audit(dbTxn, 'onboarding_completed');
        await dbTxn.delete('onboarding_credentials');
        await dbTxn.delete('onboarding_progress');
      }, inventoryChanged: true)
      .then((_) => access.lock());
}
