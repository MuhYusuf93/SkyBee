import '../../../core/domain/contact_validation.dart';
import '../../members/application/member_rules.dart';
import '../../members/domain/member_models.dart';
import '../domain/cash_tender.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../inventory/domain/stock_rules.dart';
import '../domain/cashier_models.dart';
import 'cashier_store.dart';
import '../../printer/application/receipt_snapshots.dart';

/// A checkout is one local SQL transaction. Draft identity is the durable
/// checkout key; retry reads immutable result before looking at current stock.
final class CheckoutService {
  CheckoutService(this.database, this.store, {this.testStage});
  final DatabaseCoordinator database;
  final CashierStore store;

  /// Deterministic fault injection for isolated SQL tests, never device work.
  final Future<void> Function(String stage)? testStage;
  Future<void> _stage(String name) async {
    await testStage?.call(name);
  }

  Future<SaleReceipt> receipt(EntityId id) =>
      database.read((db) => store.receipt(db, id));

  Future<String> _hash(EntityId draftId, int revision, CheckoutInput input) =>
      store.fingerprint([
        if (input.memberIntent) ...[
          'member-v1',
          input.customer.id?.value,
          input.customer.name.trim(),
          input.customer.phone.trim(),
          input.customer.address.trim(),
        ],
        if (input.tenderDetails != null) ...[
          'tender-composition-v1',
          input.tenderDetails!.financialValues,
        ],
        if (input.cash) ...[
          'cash-v1',
          input.tender?.amountMinor,
          input.tender?.currencyCode,
          input.tender?.scale,
          input.customer.id?.value,
          input.customer.name.trim(),
          input.customer.phone.trim(),
        ],
        draftId.value,
        revision,
        input.mode.name,
        input.mode == PaymentMode.partial ? input.paid?.amountMinor : null,
        input.mode == PaymentMode.partial ? input.paid?.currencyCode : null,
        input.mode == PaymentMode.partial ? input.paid?.scale : null,
        input.mode == PaymentMode.paid ? null : input.customer.id?.value,
        input.mode == PaymentMode.paid ? '' : input.customer.name.trim(),
        input.mode == PaymentMode.paid ? '' : input.customer.phone.trim(),
      ]);

  /// FEFO allocation streams bounded batches. Dated batches precede undated;
  /// expiry day is excluded in the shop timezone. Disabled expiry uses FIFO.
  Future<void> _batches(
    Transaction dbTxn,
    Map<String, Object?> product,
    int quantity,
    EntityId itemId,
  ) async {
    final expiry = product['expiry_enabled'] == 1;
    final today = store.clock
        .today((await store.settings(dbTxn))['time_zone'] as String)
        .iso;
    final sort = expiry
        ? "COALESCE(expiry_date,'9999-99-99'),received_at,id"
        : 'received_at,id';
    List<Object?>? cursor;
    var needed = quantity;
    while (needed > 0) {
      final rows = await dbTxn.rawQuery(
        '''SELECT * FROM stock_batches WHERE product_id=? AND remaining_quantity>0
        ${expiry ? 'AND (expiry_date IS NULL OR expiry_date>?)' : ''}
        ${cursor == null ? '' : 'AND ($sort)>(${List.filled(cursor.length, '?').join(',')})'}
        ORDER BY $sort LIMIT 100''',
        [product['id'], if (expiry) today, ...?cursor],
      );
      if (rows.isEmpty) throw const AppError('insufficientSaleableStock');
      for (final batch in rows) {
        final remaining = batch['remaining_quantity'] as int;
        final take = needed < remaining ? needed : remaining;
        final changed = await dbTxn.update(
          'stock_batches',
          {'remaining_quantity': remaining - take},
          where: 'id=? AND remaining_quantity=?',
          whereArgs: [batch['id'], remaining],
        );
        if (changed != 1) throw const AppError('m3StockChanged');
        await dbTxn.insert('sale_batch_allocations', {
          'id': CashierStore.ids.next().value,
          'sale_transaction_item_id': itemId.value,
          'stock_batch_id': batch['id'],
          'quantity': take,
        });
        needed -= take;
        if (needed == 0) break;
      }
      final last = rows.last;
      cursor = [
        if (expiry) last['expiry_date'] ?? '9999-99-99',
        last['received_at'],
        last['id'],
      ];
    }
  }

  /// Validates price acceptance/revision, currency, stock and payment choice;
  /// SQL failures rollback headers/details/batches/ledger/payment/draft/audit.
  Future<SaleReceipt> submit(
    EntityId draftId,
    int revision,
    CheckoutInput input,
  ) async {
    final generation = database.generation;
    final hash = await _hash(draftId, revision, input);
    return store.write(
      database,
      (dbTxn) async {
        final existing = await dbTxn.query(
          'sale_transactions',
          where: 'checkout_key=?',
          whereArgs: [draftId.value],
        );
        if (existing.isNotEmpty) {
          if (existing.single['draft_id'] != draftId.value ||
              existing.single['payload_hash'] != hash) {
            throw const AppError('m3AttemptChanged');
          }
          return store.receipt(
            dbTxn,
            EntityId(existing.single['id'] as String),
          );
        }
        final draft = await store.draft(dbTxn, draftId);
        if (draft['revision'] != revision) {
          throw const AppError('m3DraftChanged');
        }
        final cart = await store.cart(dbTxn, draftId);
        if (cart.lines.isEmpty) throw const AppError('m3EmptyCart');
        final currency = cart.currency;
        if (input.tenderDetails != null &&
            (!input.cash ||
                input.tenderDetails!.currency.code != currency.code ||
                input.tenderDetails!.currency.scale != currency.scale ||
                input.tenderDetails!.money?.amountMinor !=
                    input.tender?.amountMinor ||
                input.tenderDetails!.raw != input.tenderRaw)) {
          throw const AppError('m3InvalidPayment');
        }

        final current = store.policy(await store.settings(dbTxn));
        if (current.code != currency.code || current.scale != currency.scale) {
          throw const AppError('currencyMismatch');
        }
        if (cart.missingWholesale) {
          throw const AppError('m31WholesaleUnavailable');
        }
        if (cart.priceChanged) throw const AppError('m3PricesChanged');
        if (cart.unavailable) throw const AppError('insufficientSaleableStock');
        final total = cart.total;
        var paid = total;
        CashTender? cash;
        if (input.cash) {
          if (database.schemaVersion < 12 || input.tender == null) {
            throw const AppError('m51TenderRequired');
          }
          if (input.tender!.currencyCode != currency.code ||
              input.tender!.scale != currency.scale) {
            throw const AppError('currencyMismatch');
          }
          cash = CashTender(total, input.tender!);
          if (input.mode == PaymentMode.debt &&
              input.tender!.amountMinor != 0) {
            throw const AppError('m3InvalidPayment');
          }
          paid = cash.applied;
        } else if (input.mode != PaymentMode.paid) {
          if (total.amountMinor == 0) throw const AppError('m3InvalidPayment');
          paid = input.mode == PaymentMode.debt
              ? Money(0, currency.code, currency.scale)
              : input.paid ?? (throw const AppError('m3InvalidPayment'));
          if (paid.currencyCode != currency.code ||
              paid.scale != currency.scale) {
            throw const AppError('currencyMismatch');
          }
          if (input.mode == PaymentMode.partial &&
              (paid.amountMinor <= 0 ||
                  paid.amountMinor >= total.amountMinor)) {
            throw const AppError('m3InvalidPayment');
          }
        }
        final products = <Map<String, Object?>>[];
        final costs = <int>[];
        var totalCost = BigInt.zero;
        for (final line in cart.lines) {
          final product = (await dbTxn.query(
            'products',
            where: 'id=?',
            whereArgs: [line.product.id.value],
          )).single;
          if (product['currency_code'] != currency.code ||
              product['currency_scale'] != currency.scale) {
            throw const AppError('currencyMismatch');
          }
          final cost = product['stock_tracking_enabled'] == 0
              ? checkedNonNegative(
                  BigInt.from(
                        product['reference_cost_micros'] as int? ??
                            (product['cost_complete'] == 0
                                ? 0
                                : throw const AppError(
                                    'm52ReferenceCostRequired',
                                  )),
                      ) *
                      BigInt.from(line.quantity),
                )
              : product['cost_complete'] == 0
              ? (line.quantity == product['stock_quantity']
                    ? product['inventory_value_micros'] as int
                    : 0)
              : removalCost(
                  quantity: product['stock_quantity'] as int,
                  valueMicros: product['inventory_value_micros'] as int,
                  remove: line.quantity,
                );
          totalCost += BigInt.from(cost);
          products.add(product);
          costs.add(cost);
        }
        final cost = checkedNonNegative(totalCost);
        await _stage('validated');
        EntityId? customerId;
        String? customerName, customerPhone;
        if (database.schemaVersion >= 22 &&
            (paid.amountMinor < total.amountMinor || input.memberIntent)) {
          final choice = input.customer;
          final member = choice.id != null
              ? await MemberRules.existingOn(
                  dbTxn,
                  choice.id!,
                  requireComplete: paid.amountMinor < total.amountMinor,
                )
              : await MemberRules.createOn(
                  dbTxn,
                  CashierStore.ids.next(),
                  MemberInput(
                    name: choice.name,
                    phone: choice.phone,
                    address: choice.address,
                  ),
                  (await store.settings(dbTxn))['phone_region'] as String,
                  store.clock.milliseconds,
                );
          customerId = member.id;
          customerName = member.name;
          customerPhone = member.phone;
        } else if (paid.amountMinor < total.amountMinor) {
          customerId = input.customer.id;
          if (customerId != null) {
            final records = await dbTxn.query(
              'customers',
              where: 'id=? AND is_deleted=0',
              whereArgs: [customerId.value],
            );
            if (records.isEmpty) throw const AppError('m3CustomerUnavailable');
            customerName = records.single['name'] as String;
            customerPhone = records.single['phone_number'] as String?;
          } else {
            customerName = input.customer.name.trim();
            customerPhone = ContactValidation.phone(
              input.customer.phone,
              region:
                  (await store.settings(dbTxn))['phone_region'] as String? ??
                  'ID',
            );
            if (customerName.isEmpty) {
              throw const AppError('m3CustomerRequired');
            }
            customerId = CashierStore.ids.next();
            await dbTxn.insert('customers', {
              'id': customerId.value,
              'name': customerName,
              'normalized_name': normalizeName(customerName),
              'phone_number': customerPhone,
              'created_at': store.clock.milliseconds,
            });
          }
        }
        await _stage('customer');
        final saleId = CashierStore.ids.next();
        final now = store.clock.milliseconds;
        await dbTxn.insert('sale_transactions', {
          'id': saleId.value,
          'checkout_key': draftId.value,
          'draft_id': draftId.value,
          'customer_id': customerId?.value,
          'customer_name_snapshot': customerName,
          'customer_phone_snapshot': customerPhone,
          'created_at': now,
          'total_rupiah': total.amountMinor,
          'cost_micros': cost,
          if (database.schemaVersion >= 17)
            'cost_complete': products.every((p) => p['cost_complete'] != 0)
                ? 1
                : 0,
          'payload_hash': hash,
          ...store.metadata(currency),
        });
        if (cash != null) {
          await dbTxn.insert('checkout_tenders', {
            'sale_transaction_id': saleId.value,
            'received_minor': cash.received.amountMinor,
            'applied_minor': cash.applied.amountMinor,
            'change_minor': cash.change.amountMinor,
            'debt_minor': cash.debt.amountMinor,
            if (database.schemaVersion >= 21)
              'details_json': input.tenderDetails?.encode(),
          });
        }
        await _stage('sale');
        for (var index = 0; index < cart.lines.length; index++) {
          final line = cart.lines[index], product = products[index];
          if (product['stock_tracking_enabled'] != 0) {
            final quantity = product['stock_quantity'] as int;
            final value = product['inventory_value_micros'] as int;
            final changed = await dbTxn.update(
              'products',
              {
                'stock_quantity': quantity - line.quantity,
                'inventory_value_micros': value - costs[index],
                if (database.schemaVersion >= 17)
                  'cost_complete':
                      quantity == line.quantity || product['cost_complete'] != 0
                      ? 1
                      : 0,
                'stock_revision': (product['stock_revision'] as int) + 1,
                'updated_at': now,
              },
              where: 'id=? AND stock_revision=? AND stock_quantity>=?',
              whereArgs: [
                product['id'],
                product['stock_revision'],
                line.quantity,
              ],
            );
            if (changed != 1) throw const AppError('m3StockChanged');
          }
          await _stage('stock');
          final itemId = CashierStore.ids.next();
          await dbTxn.insert('sale_transaction_items', {
            'id': itemId.value,
            'sale_transaction_id': saleId.value,
            'product_id': product['id'],
            'product_name_snapshot': product['name'],
            'sku_snapshot': product['sku'],
            'barcode_snapshot': product['barcode'],
            if (database.schemaVersion >= 9)
              ...line.product.attributes.toRow(suffix: '_snapshot'),
            'quantity': line.quantity,
            'unit_price_rupiah': line.acceptedPrice.amountMinor,
            'pricing_mode': line.pricingMode.name,
            'total_rupiah': line.total.amountMinor,
            'cost_micros': costs[index],
            if (database.schemaVersion >= 17)
              'cost_complete': product['cost_complete'],
            if (database.schemaVersion >= 14) ...{
              'promo_snapshot_json': line.acceptedPromoJson,
              'gross_minor': line.gross.amountMinor,
              'discount_minor': line.discountMinor,
              'stock_tracking_snapshot': line.product.stockTracked ? 1 : 0,
              'reference_cost_micros_snapshot':
                  product['reference_cost_micros'],
            },
          });
          await _stage('items');
          if (product['stock_tracking_enabled'] != 0) {
            await _batches(dbTxn, product, line.quantity, itemId);
            await _stage('batches');
            await dbTxn.insert('stock_history', {
              'id': CashierStore.ids.next().value,
              'product_id': product['id'],
              'sale_transaction_id': saleId.value,
              'kind': 'sale',
              'quantity_delta': -line.quantity,
              'value_delta_micros': -costs[index],
              if (database.schemaVersion >= 17)
                'cost_complete': product['cost_complete'],
              'created_at': now,
              'reason': 'sale',
              'reason_key': 'm3SaleMovement',
              ...store.metadata(currency),
            });
          }
          await _stage('history');
        }
        if (paid.amountMinor > 0) {
          final paymentId = CashierStore.ids.next();
          await dbTxn.insert('payments', {
            'id': paymentId.value,
            'operation_key': 'checkout:${draftId.value}',
            'customer_id': customerId?.value,
            'kind': 'receipt',
            'amount_rupiah': paid.amountMinor,
            'created_at': now,
            'payload_hash': hash,
            ...store.metadata(currency),
          });
          await dbTxn.insert('payment_allocations', {
            'id': CashierStore.ids.next().value,
            'payment_id': paymentId.value,
            'sale_transaction_id': saleId.value,
            'amount_rupiah': paid.amountMinor,
          });
          await dbTxn.insert('checkout_payment_links', {
            'payment_id': paymentId.value,
            'sale_transaction_id': saleId.value,
          });
        }
        await _stage('payment');
        final completed = await dbTxn.update(
          'cart_drafts',
          {
            'state': 'completed',
            'completed_sale_transaction_id': saleId.value,
            'updated_at': now,
            if (database.schemaVersion >= 21)
              'tender_details_json': input.tenderDetails?.encode(),
            if (database.schemaVersion >= 22) ...{
              'member_intent': input.memberIntent ? 1 : 0,
              'member_opt_in': (input.memberOptIn ?? input.memberIntent)
                  ? 1
                  : 0,
              'customer_address': input.customer.address.trim(),
            },
            if (database.schemaVersion >= 12) ...{
              'cash_input': input.cash ? 1 : 0,
              'tender_minor': input.tender?.amountMinor,
              'tender_raw':
                  input.tenderDetails?.raw ??
                  (input.tender == null
                      ? ''
                      : (TenderDigits(currency)..amount(input.tender!)).raw),
              'tender_input_mode': input.quickMode ? 'quick' : 'numpad',
            },
            'payment_mode': input.mode.name,
            'paid_minor': input.paid?.amountMinor,
            'customer_id': input.customer.id?.value,
            'customer_name': input.customer.name.trim(),
            'customer_phone': input.customer.phone.trim(),
          },
          where: "id=? AND state='active' AND revision=?",
          whereArgs: [draftId.value, revision],
        );
        if (completed != 1) throw const AppError('m3DraftChanged');
        await _stage('draft');
        await store.audit(dbTxn, 'checkout_completed', saleId.value);
        await _stage('audit');
        final receipt = await store.receipt(dbTxn, saleId);
        if (database.schemaVersion >= 8) {
          await ReceiptSnapshots.record(dbTxn, receipt);
        }
        return receipt;
      },
      inventoryChanged: true,
      expectedGeneration: generation,
    );
  }
}
