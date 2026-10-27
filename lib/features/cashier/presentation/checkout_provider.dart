import '../domain/tender_draft.dart';
import 'dart:convert';
import '../../members/domain/member_models.dart';
import 'package:flutter/material.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/contact_validation.dart';
import '../../../core/domain/value_types.dart';
import '../domain/cash_tender.dart';
import '../application/quick_cash_service.dart';
import '../application/cart_service.dart';
import '../application/checkout_service.dart';
import '../domain/cashier_models.dart';
import 'cart_provider.dart';

/// Owns payment form only. Basket stays in CartProvider; SQL/math stays service.
final class CheckoutProvider extends ChangeNotifier {
  CheckoutProvider(
    this.cart,
    this.drafts,
    this.service, {
    this.quickCash,
    this.phoneRegion,
  }) {
    final input = cart.snapshot!.input;
    digits = input.tenderDetails == null
        ? TenderDraft(
            cart.snapshot!.currency,
            input.cash ? input.tenderRaw : '',
          )
        : TenderDraft.restore(cart.snapshot!.currency, input.tenderDetails!);
    if (!input.cash && input.paid != null) digits.amount(input.paid!);
    quickMode = input.quickMode;
    mode = input.cash ? input.mode : PaymentMode.paid;
    selected = input.customer.id;
    name.text = input.customer.name;
    phone.text = input.customer.phone;
    address.text = input.customer.address;
    useMember = input.memberOptIn ?? input.memberIntent;
    _updateMode();
    _savedInputKey = _inputKey(this.input);
    name.addListener(_customerEdited);
    phone.addListener(_customerEdited);
    address.addListener(_customerEdited);
  }
  final CartProvider cart;
  final CartService drafts;
  final CheckoutService service;
  final QuickCashService? quickCash;
  final Future<String> Function()? phoneRegion;
  String region = 'ID';
  String? get phoneError {
    if (!needsMember) return null;
    if (selected != null) {
      return needsCustomer && selectedNeedsReview
          ? 'm53MemberRepairRequired'
          : null;
    }
    if (phone.text.trim().isEmpty) return 'm53MemberPhoneRequired';
    try {
      ContactValidation.phone(phone.text, region: region);
      return null;
    } catch (e) {
      return safeError(e);
    }
  }

  late final TenderDraft digits;
  bool quickMode = false;
  List<int> amounts = [];
  Future<void> _saveTail = Future.value();
  Money? get tender => digits.money;
  CashTender? get settlement =>
      tender == null ? null : CashTender(cart.snapshot!.total, tender!);
  bool get needsCustomer =>
      settlement != null && settlement!.debt.amountMinor > 0;
  bool useMember = false, selectedNeedsReview = false;
  bool get needsMember => needsCustomer || useMember;
  String? get nameError =>
      needsMember && selected == null && name.text.trim().isEmpty
      ? 'm53MemberNameRequired'
      : null;
  late String _savedInputKey;
  static String _inputKey(CheckoutInput value) => jsonEncode([
    value.mode.name,
    value.tender?.amountMinor,
    value.tenderRaw,
    value.tenderDetails?.encode(),
    value.quickMode,
    value.memberIntent,
    value.memberOptIn,
    value.customer.id?.value,
    value.customer.name.trim(),
    value.customer.phone.trim(),
    value.customer.address.trim(),
  ]);
  bool get hasUnsavedInput => _inputKey(input) != _savedInputKey;
  CheckoutInput get input => CheckoutInput(
    cash: true,
    mode: mode,
    tender: tender,
    tenderRaw: digits.raw,
    tenderDetails: service.database.schemaVersion >= 21
        ? digits.snapshot
        : null,
    quickMode: quickMode,
    memberIntent: service.database.schemaVersion >= 22 && needsMember,
    memberOptIn: useMember,
    customer: CustomerChoice(
      id: selected,
      name: name.text,
      phone: phone.text,
      address: address.text,
    ),
  );
  Future<void> loadAmounts() async {
    final code = cart.snapshot!.currency.code;
    try {
      region = await phoneRegion?.call() ?? 'ID';
      amounts = await quickCash?.read(code) ?? QuickCashService.defaults(code);
    } on Object {
      amounts = QuickCashService.defaults(code);
      error = 'm3OperationFailed';
    }
    if (!_disposed) notifyListeners();
  }

  void _customerEdited() {
    if (!submitting && !_disposed && !_settingCustomer) persist();
  }

  Future<void> persist() {
    final snapshot = cart.snapshot!;
    final saved = input;
    final generation = service.database.generation;
    final key = _inputKey(saved);
    if (!_disposed) notifyListeners();
    return _saveTail = _saveTail
        .then((_) async {
          if (generation != service.database.generation) {
            throw const AppError('m3OperationFailed');
          }
          await drafts.saveInput(snapshot.id, snapshot.revision, saved);
          _savedInputKey = key;
          if (!_disposed) notifyListeners();
        })
        .catchError((Object e) {
          error = e is AppError ? e.message : 'm3OperationFailed';
          if (!_disposed) notifyListeners();
        });
  }

  Future<void> key(String value) async {
    if (submitting) return;
    try {
      digits.key(value);
      error = null;
      _updateMode();
      await persist();
    } on Object {
      error = 'm3InvalidPayment';
    }
    if (!_disposed) notifyListeners();
  }

  void _updateMode() {
    mode = tender == null || !needsCustomer
        ? PaymentMode.paid
        : tender!.amountMinor == 0
        ? PaymentMode.debt
        : PaymentMode.partial;
  }

  Future<void> receive(Money amount) async {
    if (submitting) return;
    digits.amount(amount);
    _updateMode();
    error = null;
    await persist();
    if (!_disposed) notifyListeners();
  }

  Future<void> exact() async {
    if (submitting) return;
    digits.exact(cart.snapshot!.total);
    _updateMode();
    error = null;
    await persist();
    if (!_disposed) notifyListeners();
  }

  Future<void> addDenomination(Money amount) async {
    if (submitting) return;
    try {
      digits.receive(amount);
      _updateMode();
      error = null;
      await persist();
    } catch (_) {
      error = 'm3InvalidPayment';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> removeDenomination(int amount) async {
    if (submitting) return;
    if (digits.remove(amount)) {
      _updateMode();
      error = null;
      await persist();
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> useQuick(bool value) async {
    quickMode = value;
    await persist();
    if (!_disposed) notifyListeners();
  }

  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  late PaymentMode mode;
  EntityId? selected;
  bool submitting = false;
  bool _disposed = false;
  bool _settingCustomer = false;
  String? error;
  void selectMode(PaymentMode value) {
    mode = value;
    if (value == PaymentMode.debt) {
      receive(
        Money(0, cart.snapshot!.currency.code, cart.snapshot!.currency.scale),
      );
    }
    error = null;
    notifyListeners();
  }

  void customer(MemberProfile value) {
    _settingCustomer = true;
    selected = value.id;
    selectedNeedsReview = value.needsReview || value.archived;
    useMember = true;
    name.text = value.name;
    phone.text = value.phone ?? '';
    address.text = value.address;
    _settingCustomer = false;
    persist();
    notifyListeners();
  }

  void setUseMember(bool value) {
    if (submitting || (!value && needsCustomer)) return;
    useMember = value;
    persist();
  }

  void newCustomer({bool clearFields = false}) {
    if (selected == null && !clearFields) return;
    selected = null;
    selectedNeedsReview = false;
    if (clearFields) {
      _settingCustomer = true;
      name.clear();
      phone.clear();
      address.clear();
      _settingCustomer = false;
    }
    persist();
    notifyListeners();
  }

  Future<SaleReceipt?> submit() async {
    if (submitting || _disposed) return null;
    submitting = true;
    final generation = service.database.generation;
    error = null;
    notifyListeners();
    try {
      await cart.beginCheckout();
      if (generation != service.database.generation) {
        throw const AppError('m3OperationFailed');
      }
      final snapshot = cart.snapshot!;
      await _saveTail;
      if (tender == null) throw const AppError('m51TenderRequired');
      if (phoneError != null) throw AppError(phoneError!);
      if (nameError != null) throw AppError(nameError!);
      final savedInput = input;
      await drafts.saveInput(snapshot.id, snapshot.revision, savedInput);
      _savedInputKey = _inputKey(savedInput);
      if (generation != service.database.generation) {
        throw const AppError('m3OperationFailed');
      }
      final result = await service.submit(
        snapshot.id,
        snapshot.revision,
        savedInput,
      );
      await cart.refresh();
      return result;
    } on AppError catch (e) {
      error = e.message;
      await cart.refresh();
      return null;
    } on FormatException {
      error = 'm3InvalidPayment';
      return null;
    } on Object {
      error = 'm3OperationFailed';
      return null;
    } finally {
      cart.endCheckout();
      submitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    name.removeListener(_customerEdited);
    phone.removeListener(_customerEdited);
    address.removeListener(_customerEdited);
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }
}
