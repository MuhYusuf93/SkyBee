import 'dart:convert';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/contact_validation.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';

/// Only non-secret setup values. Credentials and recovery material have no
/// place in this codec, including when restoring a locally saved draft.
final class OnboardingDraft {
  const OnboardingDraft({
    this.name = '',
    this.address = '',
    this.contact = '',
    this.taskPattern = 1,
    this.selfManaged = true,
    this.stockMode = StockMode.partial,
    this.wholesale = false,
    this.packaging = false,
    this.cost = false,
    this.barcode = false,
    this.expiry = false,
    this.wantsPrinter = false,
  });
  final String name, address, contact;
  final int taskPattern;
  final bool selfManaged,
      wholesale,
      packaging,
      cost,
      barcode,
      expiry,
      wantsPrinter;
  final StockMode stockMode;
  static const _keys = {
    'version',
    'name',
    'address',
    'contact',
    'taskPattern',
    'selfManaged',
    'stockMode',
    'wholesale',
    'packaging',
    'cost',
    'barcode',
    'expiry',
    'wantsPrinter',
  };

  factory OnboardingDraft.decode(String text) {
    if (text.length > 16384) throw const AppError('m53SetupDraftInvalid');
    try {
      final value = jsonDecode(text);
      if (value is! Map<String, dynamic> ||
          value.keys.any((k) => !_keys.contains(k)) ||
          value['version'] is! int ||
          value['version'] != 1) {
        throw const AppError('m53SetupDraftInvalid');
      }
      String string(String key) => value[key] as String? ?? '';
      bool flag(String key, {bool fallback = false}) =>
          value[key] as bool? ?? fallback;
      final pattern = value['taskPattern'] as int? ?? 1;
      final result = OnboardingDraft(
        name: string('name'),
        address: string('address'),
        contact: string('contact'),
        taskPattern: pattern,
        selfManaged: flag('selfManaged', fallback: pattern == 1),
        stockMode: StockMode.values.byName(
          value['stockMode'] as String? ?? 'partial',
        ),
        wholesale: flag('wholesale'),
        packaging: flag('packaging'),
        cost: flag('cost'),
        barcode: flag('barcode'),
        expiry: flag('expiry'),
        wantsPrinter: flag('wantsPrinter'),
      );
      result.validateBounds();
      return result;
    } catch (_) {
      throw const AppError('m53SetupDraftInvalid');
    }
  }
  void validateBounds() {
    if (name.runes.length > 120 ||
        address.runes.length > 500 ||
        contact.length > 64 ||
        ![1, 2, 3].contains(taskPattern) ||
        (selfManaged && taskPattern != 1) ||
        (taskPattern == 3 && stockMode != StockMode.all)) {
      throw const AppError('m53SetupDraftInvalid');
    }
  }

  String encode() {
    validateBounds();
    return jsonEncode({
      'version': 1,
      'name': name,
      'address': address,
      'contact': contact,
      'taskPattern': taskPattern,
      'selfManaged': selfManaged,
      'stockMode': stockMode.name,
      'wholesale': wholesale,
      'packaging': packaging,
      'cost': cost,
      'barcode': barcode,
      'expiry': expiry,
      'wantsPrinter': wantsPrinter,
    });
  }

  ({String name, String? address, String? contact}) identity(String region) {
    validateBounds();
    if (name.trim().isEmpty) throw const AppError('storeNameIsRequired');
    return (
      name: name.trim(),
      address: address.trim().isEmpty ? null : address.trim(),
      contact: ContactValidation.phone(contact, region: region),
    );
  }

  OnboardingDraft copyWith({
    String? name,
    String? address,
    String? contact,
    int? taskPattern,
    bool? selfManaged,
    StockMode? stockMode,
    bool? wholesale,
    bool? packaging,
    bool? cost,
    bool? barcode,
    bool? expiry,
    bool? wantsPrinter,
  }) {
    final pattern = taskPattern ?? this.taskPattern;
    return OnboardingDraft(
      name: name ?? this.name,
      address: address ?? this.address,
      contact: contact ?? this.contact,
      taskPattern: pattern,
      selfManaged: selfManaged ?? (pattern == 1 && this.selfManaged),
      stockMode: pattern == 3 ? StockMode.all : stockMode ?? this.stockMode,
      wholesale: wholesale ?? this.wholesale,
      packaging: packaging ?? this.packaging,
      cost: cost ?? this.cost,
      barcode: barcode ?? this.barcode,
      expiry: expiry ?? this.expiry,
      wantsPrinter: wantsPrinter ?? this.wantsPrinter,
    );
  }

  StoreFeaturePolicy policy(int revision) => StoreFeaturePolicy(
    enforced: true,
    taskPattern: taskPattern,
    stockMode: stockMode,
    wholesale: wholesale,
    packaging: packaging,
    cost: cost,
    barcode: barcode,
    expiry: expiry,
    revision: revision,
  );
}

/// Persisted revision/step and readiness are service-owned metadata, never
/// inferred from whether a PIN text controller happens to contain four digits.
final class OnboardingProgress {
  const OnboardingProgress({
    required this.draft,
    required this.step,
    required this.revision,
    required this.pinsReady,
  });
  final OnboardingDraft draft;
  final int step, revision;
  final bool pinsReady;
}
