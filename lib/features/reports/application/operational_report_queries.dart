part of 'operational_reports_service.dart';

extension _OperationalQueries on OperationalReportsService {
  (String, List<Object?>) _query(OperationalScope s, _ReportContext c) {
    final where = <String>[], args = <Object?>[];
    void search(String text) {
      if (s.search.trim().isNotEmpty) {
        // Literal substring search: '%'/'_' never become wildcard operators.
        where.add('instr(lower($text),lower(?))>0');
        args.add(s.search.trim());
      }
    }

    void supplier(String column) {
      if (s.supplierId != null) {
        where.add('$column=?');
        args.add(s.supplierId!.value);
      }
    }

    void period(String column, {bool dateOnly = false}) {
      if (s.from == null || !s.usesPeriod) return;
      where.add('$column>=? AND $column${dateOnly ? '<=' : '<'}?');
      args.add(
        dateOnly
            ? s.from!.iso
            : access.clock.dayStart(s.from!, c.zone).milliseconds,
      );
      args.add(
        dateOnly
            ? s.through!.iso
            : access.clock
                  .dayStart(s.through!, c.zone, nextDay: true)
                  .milliseconds,
      );
    }

    String conditions() => where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    switch (s.section) {
      case OperationalSection.potential:
        supplier('p.master_supplier_id');
        if (s.categoryId != null) {
          where.add('p.category_id=?');
          args.add(s.categoryId!.value);
        }
        search(
          "p.name||' '||p.sku||' '||COALESCE(p.barcode,'')||' '||COALESCE(c.name,'')||' '||COALESCE(v.name,'')",
        );
        final key = switch (s.grouping) {
          PotentialGrouping.product => 'p.id',
          PotentialGrouping.category =>
            "COALESCE(p.category_id,'')||':'||p.currency_code||':'||p.currency_scale",
          PotentialGrouping.supplier =>
            "COALESCE(p.master_supplier_id,'')||':'||p.currency_code||':'||p.currency_scale",
          PotentialGrouping.store => "p.currency_code||':'||p.currency_scale",
        };
        final name = switch (s.grouping) {
          PotentialGrouping.product => 'p.name',
          PotentialGrouping.category => "COALESCE(c.name,'')",
          PotentialGrouping.supplier => "COALESCE(v.name,'')",
          PotentialGrouping.store => "''",
        };
        return (
          '''SELECT p.*,$key AS report_group,$name AS group_name,
          c.name AS category_name,v.name AS master_supplier_name
          FROM products p LEFT JOIN categories c ON c.id=p.category_id
          LEFT JOIN suppliers v ON v.id=p.master_supplier_id ${conditions()}''',
          args,
        );
      case OperationalSection.variance:
        where.add("d.status='posted'");
        period('d.posted_at');
        search("l.product_name||' '||d.reason||' '||d.id");
        return (
          '''SELECT l.*,l.id AS report_group,d.posted_at,d.reason,d.actor_role,
          d.currency_code,d.currency_scale,d.time_zone FROM stocktake_drafts d
          JOIN stocktake_lines l ON l.draft_id=d.id ${conditions()}''',
          args,
        );
      case OperationalSection.supplierInvoices:
        where.add("i.status='posted'");
        supplier('i.supplier_id');
        search(
          "COALESCE(v.name,i.supplier_name_snapshot)||' '||COALESCE(i.invoice_number,'')||' '||i.id",
        );
        final key = s.grouping == PotentialGrouping.supplier
            ? "i.supplier_id||':'||i.currency_code||':'||i.currency_scale"
            : 'i.id';
        final base =
            '''SELECT i.*,$key AS report_group,
          COALESCE(v.name,i.supplier_name_snapshot) AS group_name
          FROM (${SupplierService.invoiceProjectionSql}) i
          LEFT JOIN suppliers v ON v.id=i.supplier_id ${conditions()}''';
        final remaining = '(total_minor-paid_minor-credit_minor)';
        final filter = switch (s.balance) {
          InvoiceBalanceFilter.all => '1',
          InvoiceBalanceFilter.open => '$remaining>0',
          InvoiceBalanceFilter.paid => '$remaining=0',
          InvoiceBalanceFilter.noDue =>
            '$remaining>0 AND effective_due IS NULL',
          InvoiceBalanceFilter.future => '$remaining>0 AND effective_due>?',
          InvoiceBalanceFilter.today => '$remaining>0 AND effective_due=?',
          InvoiceBalanceFilter.overdue => '$remaining>0 AND effective_due<?',
        };
        if ([
          InvoiceBalanceFilter.future,
          InvoiceBalanceFilter.today,
          InvoiceBalanceFilter.overdue,
        ].contains(s.balance)) {
          args.add(c.day);
        }
        return ('SELECT * FROM ($base) WHERE $filter', args);
      case OperationalSection.supplierCredits:
        supplier('i.supplier_id');
        where.add('i.reversed=0');
        search("v.name||' '||i.id");
        return (
          '''SELECT i.*,i.id AS report_group,v.name AS name
          FROM (${SupplierService.creditProjectionSql}) i
          JOIN suppliers v ON v.id=i.supplier_id ${conditions()}''',
          args,
        );
      case OperationalSection.supplierPayments:
        supplier('i.supplier_id');
        // Original facts remain in their actual paid-date period even if a
        // reversal/void occurred later. Reversals have recorded-time semantics.
        search("v.name||' '||COALESCE(i.invoice_number,'')||' '||e.invoice_id");
        if (s.from != null) {
          where.add(
            '((e.kind=0 AND e.event_date>=? AND e.event_date<=?) OR '
            '(e.kind=1 AND e.created_at>=? AND e.created_at<?))',
          );
          args.addAll([
            s.from!.iso,
            s.through!.iso,
            access.clock.dayStart(s.from!, c.zone).milliseconds,
            access.clock
                .dayStart(s.through!, c.zone, nextDay: true)
                .milliseconds,
          ]);
        }
        return (
          '''SELECT e.*,v.name AS name,i.supplier_id,
          i.invoice_number FROM (
          SELECT p.id,p.invoice_id,p.amount_minor,p.currency_code,p.currency_scale,
            p.source,p.paid_date AS event_date,p.created_at,0 AS kind,NULL AS reason,'payment' AS report_group FROM supplier_payments p
          UNION ALL SELECT r.id,r.invoice_id,r.amount_minor,r.currency_code,r.currency_scale,
            p.source,NULL AS event_date,r.created_at,1 AS kind,r.reason,'reversal' AS report_group
            FROM supplier_payment_reversals r JOIN supplier_payments p ON p.id=r.payment_id
          ) e JOIN supplier_invoices i ON i.id=e.invoice_id
          JOIN suppliers v ON v.id=i.supplier_id ${conditions()}''',
          args,
        );
      case OperationalSection.supplierRefunds:
        supplier('i.supplier_id');
        search("v.name||' '||e.credit_id");
        period('e.event_date', dateOnly: true);
        return (
          '''SELECT e.*,v.name AS name,i.supplier_id FROM (
          SELECT f.id,f.credit_id,f.amount_minor,f.currency_code,f.currency_scale,
            f.destination AS source,f.event_date,f.created_at,0 AS kind,NULL AS reason,'refund' AS report_group FROM supplier_credit_refunds f
          UNION ALL SELECT r.id,r.credit_id,r.amount_minor,r.currency_code,r.currency_scale,
            f.destination AS source,r.event_date,r.created_at,1 AS kind,r.reason,'reversal' AS report_group
            FROM supplier_credit_refund_reversals r JOIN supplier_credit_refunds f ON f.id=r.refund_id
          ) e JOIN supplier_credits i ON i.id=e.credit_id
          JOIN suppliers v ON v.id=i.supplier_id ${conditions()}''',
          args,
        );
      case OperationalSection.unreconciled:
        supplier('r.supplier_id');
        search("COALESCE(v.name,'')||' '||r.id");
        where.addAll([
          "EXISTS(SELECT 1 FROM inventory_operations o WHERE o.stock_receipt_id=r.id AND o.kind='receipt')",
          'NOT EXISTS(SELECT 1 FROM stock_tracking_changes t WHERE t.stock_receipt_id=r.id)',
          "NOT EXISTS(SELECT 1 FROM supplier_invoices i WHERE i.receipt_id=r.id AND i.status='posted')",
          'NOT EXISTS(SELECT 1 FROM inventory_operations v JOIN inventory_operations o ON o.id=v.reverses_operation_id WHERE o.stock_receipt_id=r.id)',
        ]);
        return (
          '''SELECT r.*,r.id AS report_group,v.name AS name FROM stock_receipts r
          LEFT JOIN suppliers v ON v.id=r.supplier_id ${conditions()}''',
          args,
        );
      case OperationalSection.pendingReturns:
        supplier('r.supplier_id');
        search("r.supplier_name_snapshot||' '||r.id");
        where.addAll([
          'NOT EXISTS(SELECT 1 FROM supplier_return_reversals x WHERE x.return_id=r.id)',
          'NOT EXISTS(SELECT 1 FROM supplier_credits x WHERE x.return_id=r.id AND '
              'NOT EXISTS(SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=x.id))',
        ]);
        return (
          '''SELECT i.*,i.return_id AS report_group,r.currency_code,r.currency_scale,
          r.supplier_id,r.supplier_name_snapshot AS group_name FROM supplier_returns r
          JOIN supplier_return_items i ON i.return_id=r.id ${conditions()}''',
          args,
        );
    }
  }
}
