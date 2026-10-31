part of 'operational_reports_service.dart';

extension _OperationalValues on OperationalReportsService {
  OperationalRow _value(
    OperationalScope s,
    Map<String, Object?> r,
    _ReportContext c,
    InventoryProduct? stock,
  ) {
    final amounts = <String, BigInt>{};
    final details = <String, Object?>{};
    void add(String key, int value) {
      amounts[key] = BigInt.from(value);
    }

    final currency = r['currency_code'] as String,
        scale = r['currency_scale'] as int;
    switch (s.section) {
      case OperationalSection.potential:
        final product = stock!;
        details.addAll({
          'name': product.name,
          'group_name': r['group_name'],
          'product_id': product.id.value,
          'sku': product.sku,
          'barcode': product.barcode,
          'category': r['category_name'],
          'supplier': r['master_supplier_name'],
          'supplier_id': r['master_supplier_id'],
          'base_unit': product.baseUnit,
          'retail_price_minor': '${product.priceMinor}',
          'stock_tracking': product.stockTracked ? 'tracked' : 'untracked',
          'archived': product.isDeleted ? '1' : '0',
        });
        add('product_count', 1);
        if (!product.stockTracked) {
          add('untracked_product_count', 1);
          break;
        }
        final eligible = product.isDeleted ? 0 : product.saleable,
            excluded = product.quantity - eligible;
        add('tracked_product_count', 1);
        add('saleable_quantity', eligible);
        add('excluded_quantity', excluded);
        add('expired_quantity', product.expired);
        if (product.isDeleted) {
          add('archived_product_count', 1);
        }
        amounts['potential_minor'] =
            BigInt.from(eligible) * BigInt.from(product.priceMinor);
        if (product.costComplete) {
          final pool = product.valueMicros!,
              allocated = eligible == 0
                  ? 0
                  : removalCost(
                      quantity: product.quantity,
                      valueMicros: pool,
                      remove: eligible,
                    );
          add('known_cost_micros', allocated);
          add('known_excluded_cost_micros', pool - allocated);
          add('known_cost_quantity', eligible);
          amounts['known_gross_micros'] =
              amounts['potential_minor']! * BigInt.from(CostAmount.scale) -
              BigInt.from(allocated);
        } else {
          if (eligible > 0) {
            add('unknown_cost_product_count', 1);
          }
          add('unknown_cost_quantity', eligible);
          add('unknown_excluded_quantity', excluded);
        }
        break;
      case OperationalSection.variance:
        details.addAll({
          'name': r['product_name'],
          'product_id': r['product_id'],
          'stocktake_id': r['draft_id'],
          'operation_id': r['operation_id'],
          'posted_at': '${r['posted_at']}',
          'reason': r['reason'],
          'actor_role': r['actor_role'],
          'baseline_at': '${r['captured_at']}',
          'baseline_epoch': '${r['baseline_epoch']}',
          'base_unit': r['base_unit'],
          'baseline_quantity': '${r['baseline_quantity']}',
          'final_quantity': r['final_quantity']?.toString(),
          'snapshot_zone': r['time_zone'],
        });
        if (r['final_quantity'] == null) {
          add('uncounted_line_count', 1);
          break;
        }
        final baseline = r['baseline_quantity'] as int,
            finalQuantity = r['final_quantity'] as int,
            delta = finalQuantity - baseline;
        add('comparison_line_count', 1);
        add('baseline_quantity', baseline);
        add('physical_quantity', finalQuantity);
        add('delta_quantity', delta);
        add('shortage_quantity', delta < 0 ? -delta : 0);
        add('surplus_quantity', delta > 0 ? delta : 0);
        if (r['baseline_complete'] == 1 && r['final_complete'] == 1) {
          add(
            'known_delta_micros',
            (r['final_value_micros'] as int) -
                (r['baseline_value_micros'] as int),
          );
          add('known_baseline_micros', r['baseline_value_micros'] as int);
          add('known_final_micros', r['final_value_micros'] as int);
        } else {
          add('unknown_value_line_count', 1);
        }
        break;
      case OperationalSection.supplierInvoices:
        final invoice = SupplierInvoice(r);
        if (invoice.remaining < 0) throw const AppError('m4InconsistentData');
        final due = invoice.due?.iso;
        final today = DateTime.parse('${c.day}T00:00:00Z');
        final days = due == null
            ? 0
            : today.difference(DateTime.parse('${due}T00:00:00Z')).inDays;
        details.addAll({
          'name': r['invoice_number'] ?? invoice.id.value,
          'group_name': r['group_name'],
          'supplier': r['group_name'],
          'supplier_id': invoice.supplierId.value,
          'invoice_id': invoice.id.value,
          'invoice_date': r['invoice_date'],
          'due_date': due,
          'days_overdue': invoice.remaining > 0 && days > 0 ? '$days' : '0',
          'status': invoice.paymentStatus,
        });
        add('invoice_count', 1);
        add('purchase_minor', invoice.total);
        add('effective_payment_minor', invoice.paid);
        add('applied_credit_minor', invoice.credit);
        add('remaining_minor', invoice.remaining);
        if (invoice.remaining > 0) {
          add('open_invoice_count', 1);
          if (due == null) {
            add('no_due_minor', invoice.remaining);
          } else if (days == 0) {
            add('due_today_minor', invoice.remaining);
          } else if (days < 0) {
            add('future_minor', invoice.remaining);
          } else {
            add('overdue_minor', invoice.remaining);
            add(
              days <= 7
                  ? 'overdue_1_7_minor'
                  : days <= 30
                  ? 'overdue_8_30_minor'
                  : 'overdue_over_30_minor',
              invoice.remaining,
            );
          }
        } else {
          add('paid_invoice_count', 1);
        }
        break;
      case OperationalSection.supplierPayments:
      case OperationalSection.supplierRefunds:
        final refund = s.section == OperationalSection.supplierRefunds,
            reversed = r['kind'] == 1,
            value = r['amount_minor'] as int,
            source = r['source'] as String;
        details.addAll({
          'name': r['name'],
          'supplier_id': r['supplier_id'],
          'invoice_id': r['invoice_id'],
          'credit_id': r['credit_id'],
          'source': source,
          'kind': reversed ? 'reversal' : 'original',
          'event_date':
              r['event_date'] ??
              access.clock.dateAt(r['created_at'] as int, c.zone).iso,
          'recorded_at': '${r['created_at']}',
          'reason': r['reason'],
          'date_basis': !refund && reversed
              ? 'recorded_shop_date'
              : 'operator_event_date',
        });
        add(
          refund
              ? reversed
                    ? 'refund_reversal_minor'
                    : 'refund_minor'
              : reversed
              ? 'payment_reversal_minor'
              : 'payment_minor',
          value,
        );
        final signed = reversed ? -value : value;
        add(refund ? 'net_refund_minor' : 'net_payment_minor', signed);
        add('${refund ? 'refund' : 'payment'}_${source}_minor', signed);
        add('event_count', 1);
        break;
      case OperationalSection.supplierCredits:
        final credit = SupplierCredit(r);
        if (credit.available < 0 || r['ledger_available'] != credit.available) {
          throw const AppError('m4InconsistentData');
        }
        details.addAll({
          'name': r['name'],
          'supplier_id': r['supplier_id'],
          'return_id': r['return_id'],
          'approved_date': r['approved_date'],
        });
        add('credit_count', 1);
        add('approved_credit_minor', credit.total);
        add('allocated_credit_minor', credit.allocated);
        add('refunded_credit_minor', credit.refunded);
        add('available_credit_minor', credit.available);
        break;
      case OperationalSection.unreconciled:
        details.addAll({
          'name': r['name'],
          'supplier_id': r['supplier_id'],
          'receipt_id': r['id'],
          'recorded_at': '${r['created_at']}',
        });
        add('unreconciled_receipt_count', 1);
        break;
      case OperationalSection.pendingReturns:
        details.addAll({
          'name': r['product_name_snapshot'],
          'group_name': r['group_name'],
          'supplier_id': r['supplier_id'],
        });
        add('pending_return_line_count', 1);
        add('pending_return_quantity', r['quantity'] as int);
        if (r['tracked'] == 1 && r['before_complete'] == 1) {
          add(
            'known_pending_carrying_micros',
            r['removed_value_micros'] as int,
          );
        } else {
          add('unknown_pending_value_line_count', 1);
        }
        break;
    }
    return OperationalRow(
      id: r['id'] as String,
      group: r['report_group'] as String,
      currency: currency,
      scale: scale,
      details: details,
      amounts: amounts,
    );
  }
}
