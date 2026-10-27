import '../domain/cash_tender.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../domain/cashier_models.dart';
import 'cashier_store.dart';

/// Durable cart mutations; no stock is reserved or removed by a draft.
final class CartService {
  CartService(this.database, this.store);
  final DatabaseCoordinator database;
  final CashierStore store;
  Future<EntityId> _create(DatabaseExecutor db) async {
    final id = CashierStore.ids.next();
    await db.insert('cart_drafts', {
      'id': id.value,
      'created_at': store.clock.milliseconds,
      'updated_at': store.clock.milliseconds,
      ...store.metadata(store.policy(await store.settings(db))),
    });
    await db.update('cashier_state', {'draft_id': id.value}, where: 'id=1');
    return id;
  }

  /// Recovery follows the pointer even when its draft is completed. UI must
  /// acknowledge the stored receipt before starting another basket.
  Future<CartSnapshot> open() => database.transaction((dbTxn) async {
    final pointer =
        (await dbTxn.query('cashier_state')).single['draft_id'] as String?;
    EntityId? id = pointer == null ? null : EntityId(pointer);
    if (id == null) {
      final old = await dbTxn.query(
        'cart_drafts',
        where: "state='active'",
        orderBy: 'updated_at DESC,id COLLATE BINARY DESC',
        limit: 1,
      );
      id = old.isEmpty
          ? await _create(dbTxn)
          : EntityId(old.single['id'] as String);
      await dbTxn.update('cashier_state', {
        'draft_id': id.value,
      }, where: 'id=1');
    }
    return store.cart(dbTxn, id);
  });
  Future<CartSnapshot> read(EntityId id) =>
      database.read((db) => store.cart(db, id));

  /// Intended after acknowledgement only. Do not silently replace a live draft.
  Future<CartSnapshot> next(EntityId completedId) => store.write(database, (
    dbTxn,
  ) async {
    final pointer = (await dbTxn.query('cashier_state')).single['draft_id'];
    if (pointer != completedId.value) throw const AppError('m3DraftChanged');
    final old = await store.draft(dbTxn, completedId, active: false);
    if (old['state'] != 'completed') throw const AppError('m3DraftUnavailable');
    return store.cart(dbTxn, await _create(dbTxn));
  });
  Future<void> _changed(DatabaseExecutor db, EntityId id, int revision) async {
    await db.update(
      'cart_drafts',
      {
        'revision': revision + 1,
        'updated_at': store.clock.milliseconds,
        // Keep persisted payment intent during corrections. A changed total
        // is revalidated; never silently turn a debt basket into paid in full.
      },
      where: 'id=?',
      whereArgs: [id.value],
    );
  }

  Future<CartSnapshot> add(EntityId draftId, EntityId productId) =>
      store.write(database, (dbTxn) async {
        final draft = await store.draft(dbTxn, draftId);
        final product = await store.product(dbTxn, productId);
        if (product.archived) {
          throw const AppError('productIsArchivedRestoreItFirst');
        }
        final rows = await dbTxn.query(
          'cart_draft_items',
          where: 'draft_id=? AND product_id=?',
          whereArgs: [draftId.value, productId.value],
        );
        final quantity = (rows.firstOrNull?['quantity'] as int? ?? 0) + 1;
        if (product.referenceExpired ||
            (product.stockTracked && quantity > product.saleable)) {
          throw const AppError('insufficientSaleableStock');
        }
        if (rows.isEmpty) {
          await dbTxn.insert('cart_draft_items', {
            'draft_id': draftId.value,
            'product_id': productId.value,
            'quantity': quantity,
            'accepted_price_rupiah': product.price.amountMinor,
            'product_revision': product.revision,
          });
        } else {
          await dbTxn.update(
            'cart_draft_items',
            {'quantity': quantity},
            where: 'draft_id=? AND product_id=?',
            whereArgs: [draftId.value, productId.value],
          );
        }
        await store.acceptLinePromo(dbTxn, draftId, productId);
        await _changed(dbTxn, draftId, draft['revision'] as int);
        final result = await store.cart(dbTxn, draftId);
        result.total; // Validate cap/metadata before committing the mutation.
        return result;
      });
  Future<CartSnapshot> quantity(
    EntityId draftId,
    EntityId productId,
    int quantity,
  ) => store.write(database, (dbTxn) async {
    Quantity.positive(quantity);
    final draft = await store.draft(dbTxn, draftId);
    final product = await store.product(dbTxn, productId);
    if (product.archived ||
        product.referenceExpired ||
        (product.stockTracked && quantity > product.saleable)) {
      throw const AppError('insufficientSaleableStock');
    }
    final changed = await dbTxn.update(
      'cart_draft_items',
      {'quantity': quantity},
      where: 'draft_id=? AND product_id=?',
      whereArgs: [draftId.value, productId.value],
    );
    if (changed != 1) throw const AppError('m3DraftChanged');
    await store.acceptLinePromo(dbTxn, draftId, productId);
    await _changed(dbTxn, draftId, draft['revision'] as int);
    final result = await store.cart(dbTxn, draftId);
    result.total;
    return result;
  });

  /// Explicit manual mode selection applies to the whole product line. Never
  /// fall back from a removed wholesale price; cashier must choose retail/remove.
  Future<CartSnapshot> pricing(
    EntityId draftId,
    EntityId productId,
    PricingMode mode,
  ) => store.write(database, (dbTxn) async {
    final draft = await store.draft(dbTxn, draftId);
    final product = await store.product(dbTxn, productId);
    final price = mode == PricingMode.wholesale
        ? product.wholesalePrice
        : product.price;
    if (price == null) throw const AppError('m31WholesaleUnavailable');
    final changed = await dbTxn.update(
      'cart_draft_items',
      {
        'pricing_mode': mode.name,
        'accepted_price_rupiah': price.amountMinor,
        'product_revision': product.revision,
      },
      where: 'draft_id=? AND product_id=?',
      whereArgs: [draftId.value, productId.value],
    );
    if (changed != 1) throw const AppError('m3DraftChanged');
    await store.acceptLinePromo(dbTxn, draftId, productId);
    await _changed(dbTxn, draftId, draft['revision'] as int);
    final result = await store.cart(dbTxn, draftId);
    result.total;
    return result;
  });

  Future<(CartSnapshot, CartUndo)> remove(
    EntityId draftId, {
    EntityId? productId,
  }) => store.write(database, (dbTxn) async {
    final draft = await store.draft(dbTxn, draftId);
    final rows = await dbTxn.query(
      'cart_draft_items',
      where: 'draft_id=?',
      whereArgs: [draftId.value],
    );
    await dbTxn.delete(
      'cart_draft_items',
      where: productId == null ? 'draft_id=?' : 'draft_id=? AND product_id=?',
      whereArgs: [draftId.value, if (productId != null) productId.value],
    );
    final revision = draft['revision'] as int;
    await _changed(dbTxn, draftId, revision);
    return (
      await store.cart(dbTxn, draftId),
      CartUndo(
        draftId,
        revision + 1,
        store.clock.elapsedMilliseconds + 5000,
        List.unmodifiable(rows.map(Map<String, Object?>.unmodifiable)),
      ),
    );
  });
  Future<CartSnapshot> undo(CartUndo token) =>
      store.write(database, (dbTxn) async {
        final draft = await store.draft(dbTxn, token.draftId);
        if (draft['revision'] != token.expectedRevision ||
            store.clock.elapsedMilliseconds > token.expiresAt) {
          throw const AppError('m3UndoExpired');
        }
        await dbTxn.delete(
          'cart_draft_items',
          where: 'draft_id=?',
          whereArgs: [token.draftId.value],
        );
        for (final row in token.lines) {
          await dbTxn.insert('cart_draft_items', row);
        }
        await _changed(dbTxn, token.draftId, token.expectedRevision);
        // Restored accepted prices stay unchanged; current stock/price warnings
        // accompany the draft, and checkout always revalidates independently.
        return store.cart(dbTxn, token.draftId);
      });
  Future<CartSnapshot> acceptPrices(EntityId id, int expectedRevision) =>
      store.write(database, (dbTxn) async {
        final draft = await store.draft(dbTxn, id);
        if (draft['revision'] != expectedRevision) {
          throw const AppError('m3DraftChanged');
        }
        final current = await store.cart(dbTxn, id);
        for (final line in current.lines) {
          if (line.product.archived) {
            throw const AppError('productIsArchivedRestoreItFirst');
          }
          await dbTxn.update(
            'cart_draft_items',
            {
              'accepted_price_rupiah':
                  (line.currentPrice ??
                          (throw const AppError('m31WholesaleUnavailable')))
                      .amountMinor,
              'product_revision': line.product.revision,
            },
            where: 'draft_id=? AND product_id=?',
            whereArgs: [id.value, line.product.id.value],
          );
          await store.acceptLinePromo(dbTxn, id, line.product.id);
        }
        await _changed(dbTxn, id, expectedRevision);
        final result = await store.cart(dbTxn, id);
        result.total;
        return result;
      });

  /// Persist canonical payment input BEFORE checkout. Invalid text remains in
  /// the form controller; a failed SQL checkout cannot discard its valid input.
  Future<void> saveInput(
    EntityId id,
    int revision,
    CheckoutInput input,
  ) => store.write(database, (dbTxn) async {
    final draft = await store.draft(dbTxn, id, active: false);
    if (draft['revision'] != revision) throw const AppError('m3DraftChanged');
    if (draft['state'] == 'completed') return;
    if (draft['state'] != 'active') throw const AppError('m3DraftUnavailable');
    final policy = store.policy(draft);
    if (input.paid != null &&
        (input.paid!.currencyCode != policy.code ||
            input.paid!.scale != policy.scale)) {
      throw const AppError('currencyMismatch');
    }
    if (input.cash) {
      final digits = TenderDigits(policy, input.tenderRaw);
      if (input.tender != null &&
          (input.tender!.currencyCode != policy.code ||
              input.tender!.scale != policy.scale ||
              digits.money?.amountMinor != input.tender!.amountMinor)) {
        throw const AppError('m3InvalidPayment');
      }
    }
    if (input.tenderDetails != null) {
      final details = input.tenderDetails!;
      if (!input.cash ||
          details.currency.code != policy.code ||
          details.currency.scale != policy.scale ||
          details.raw != input.tenderRaw ||
          details.money?.amountMinor != input.tender?.amountMinor) {
        throw const AppError('m3InvalidPayment');
      }
    }
    await dbTxn.update(
      'cart_drafts',
      {
        if (database.schemaVersion >= 21)
          'tender_details_json': input.tenderDetails?.encode(),
        if (database.schemaVersion >= 12) ...{
          'cash_input': input.cash ? 1 : 0,
          'tender_minor': input.tender?.amountMinor,
          'tender_raw': input.tenderRaw,
          'tender_input_mode': input.quickMode ? 'quick' : 'numpad',
        },
        'payment_mode': input.mode.name,
        'paid_minor': input.paid?.amountMinor,
        'customer_id': input.customer.id?.value,
        'customer_name': input.customer.name.trim(),
        'customer_phone': input.customer.phone.trim(),
      },
      where: 'id=?',
      whereArgs: [id.value],
    );
  });
}
