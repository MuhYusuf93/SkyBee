/// Expression order exactly matches report_group + binary ID keysets. These
/// additive indexes prevent sorting the full source again for every100-row
/// grouped report page; no business rows or historical values are rewritten.
const operationalReportSchema = <String>[
  "CREATE INDEX products_report_category ON products((COALESCE(category_id,'')||':'||currency_code||':'||currency_scale) COLLATE BINARY,id COLLATE BINARY)",
  "CREATE INDEX products_report_supplier ON products((COALESCE(master_supplier_id,'')||':'||currency_code||':'||currency_scale) COLLATE BINARY,id COLLATE BINARY)",
  "CREATE INDEX products_report_store ON products((currency_code||':'||currency_scale) COLLATE BINARY,id COLLATE BINARY)",
  "CREATE INDEX supplier_invoice_report ON supplier_invoices((supplier_id||':'||currency_code||':'||currency_scale) COLLATE BINARY,id COLLATE BINARY) WHERE status='posted'",
  'CREATE INDEX supplier_return_item_report ON supplier_return_items(return_id COLLATE BINARY,id COLLATE BINARY)',
];
