import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/domain/app_error.dart';
import '../../management/application/management_service.dart';
import '../application/onboarding_service.dart';
import '../domain/onboarding_draft.dart';

/// One wizard's non-secret state. Autosaves are serialized and return only a
/// revision; a slow save cannot overwrite newer text entered by the user.
final class OnboardingController extends ChangeNotifier {
  OnboardingController(this.service);
  final OnboardingService service;
  OnboardingDraft draft = const OnboardingDraft();
  OnboardingProgress? progress;
  int step = 1, _edit = 0, _saved = 0;
  bool busy = false, _disposed = false;
  String? error;
  bool get saved => progress != null && _saved == _edit;
  Timer? _debounce;
  Future<void> _tail = Future.value();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<void> load() => run(() async {
    progress = await service.load();
    draft = progress!.draft;
    step = progress!.step;
  });
  void update(OnboardingDraft value) {
    if (busy || _disposed) return;
    draft = value;
    _edit++;
    error = null;
    _notify();
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(autosave()),
    );
  }

  Future<void> autosave() async {
    try {
      await flush();
    } catch (e) {
      error = safeError(e);
      _notify();
    }
  }

  Future<void> flush({int? targetStep}) => _serial(() async {
    final current = progress;
    if (current == null) return;
    final target = targetStep ?? current.step;
    if (_saved == _edit && current.step == target) return;
    final snapshot = draft, version = _edit;
    progress = await service.save(
      snapshot,
      step: target,
      revision: current.revision,
    );
    _saved = version;
    _notify();
  });
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
    } catch (e) {
      error = safeError(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> move(int target) => run(() async {
    _debounce?.cancel();
    await flush(targetStep: target);
    step = target;
  });
  Future<({String recoveryCode, OnboardingPinProof proof})> prepare({
    required String ownerPin,
    required String confirmation,
    String? warehousePin,
    String? warehouseConfirmation,
  }) async {
    _debounce?.cancel();
    await flush(targetStep: 3);
    final result = await service.access.prepareOnboardingPins(
      revision: progress!.revision,
      ownerPin: ownerPin,
      confirmation: confirmation,
      warehousePin: warehousePin,
      warehouseConfirmation: warehouseConfirmation,
    );
    progress = await service.load();
    return result;
  }

  Future<void> acknowledge(OnboardingPinProof proof) async {
    await service.access.acknowledgeOnboardingRecovery(proof);
    progress = await service.load();
    step = progress!.step;
  }

  Future<void> finish() async {
    _debounce?.cancel();
    await flush(targetStep: 7);
    await service.finish(progress!.revision);
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
