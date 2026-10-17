import 'package:flutter/material.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../application/cart_service.dart';
import '../application/checkout_service.dart';
import '../domain/cashier_models.dart';
import 'cart_provider.dart';

/// Owns payment form only. Basket stays in CartProvider; SQL/math stays service.
final class CheckoutProvider extends ChangeNotifier {
  CheckoutProvider(this.cart, this.drafts, this.service) {
    final input = cart.snapshot!.input;
    mode = input.mode;
    selected = input.customer.id;
    name.text = input.customer.name;
    phone.text = input.customer.phone;
  }
  final CartProvider cart;
  final CartService drafts;
  final CheckoutService service;
  final paid = MoneyEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  late PaymentMode mode;
  EntityId? selected;
  bool submitting = false;
  bool _disposed = false;
  String? error;
  void selectMode(PaymentMode value) {
    mode = value;
    error = null;
    notifyListeners();
  }

  void customer(CustomerRecord value) {
    selected = value.id;
    name.text = value.name;
    phone.text = value.phone ?? '';
    notifyListeners();
  }

  void newCustomer() {
    selected = null;
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
      final input = CheckoutInput(
        mode: mode,
        paid: mode == PaymentMode.partial
            ? paid.parseMoney(finish: true)
            : null,
        customer: CustomerChoice(
          id: selected,
          name: name.text,
          phone: phone.text,
        ),
      );
      await drafts.saveInput(snapshot.id, snapshot.revision, input);
      if (generation != service.database.generation) {
        throw const AppError('m3OperationFailed');
      }
      final result = await service.submit(
        snapshot.id,
        snapshot.revision,
        input,
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
    paid.dispose();
    name.dispose();
    phone.dispose();
    super.dispose();
  }
}
