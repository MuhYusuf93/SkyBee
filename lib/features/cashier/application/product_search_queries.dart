import '../../../core/domain/value_types.dart';
import '../../../data/repositories/keyset_queries.dart';
import '../domain/product_search_page.dart';
import '../../../core/domain/product_label_code.dart';

/// Query matching and ordering precede LIMIT. Exact codes may remain first even
/// when unavailable; ordinary candidates always rank eligible stock first.
SqlQuery pagedProductSearchQuery(
  String text,
  String today,
  ProductSearchOrder order,
  ProductSearchCursor? after,
  int pageSize,
) {
  final raw = text.trim(),
      q = normalizeName(text),
      end = prefixEnd(normalizeName(text));
  final frequent = order == ProductSearchOrder.frequent;
  final labelId = ProductLabelCode.productId(raw);
  final tuple =
      '''code_tier,eligibility,${frequent ? '-receipts,-net_quantity,' : ''}
    relevance,normalized_name COLLATE BINARY,id COLLATE BINARY''';
  return SqlQuery(
    '''WITH candidates AS (
    SELECT id AS product_id,0 AS priority FROM products WHERE is_deleted=0 AND barcode=?
    UNION ALL SELECT id,0 FROM products WHERE is_deleted=0 AND sku=?
    ${labelId == null ? '' : 'UNION ALL SELECT id,0 FROM products WHERE is_deleted=0 AND id=?'}
    UNION ALL SELECT id,1 FROM products WHERE is_deleted=0 AND normalized_name=?
    UNION ALL SELECT product_id,priority FROM cashier_search_terms
      WHERE term COLLATE BINARY>=? ${end == null ? '' : 'AND term COLLATE BINARY<?'}),
    matched AS(SELECT product_id,MIN(priority) AS relevance FROM candidates GROUP BY product_id),
    scored AS(SELECT p.id,p.normalized_name,m.relevance,
      CASE WHEN p.barcode=? OR p.sku=? ${labelId == null ? '' : 'OR p.id=?'} THEN 0 ELSE 1 END AS code_tier,
      CASE WHEN p.stock_tracking_enabled=0 THEN
        CASE WHEN p.expiry_enabled=1 AND p.reference_expiry_date<=? THEN 1 ELSE 0 END
      ELSE CASE WHEN (CASE WHEN p.expiry_enabled=1 THEN
        MIN(p.stock_quantity,COALESCE((SELECT SUM(b.remaining_quantity) FROM stock_batches b
          WHERE b.product_id=p.id AND (b.expiry_date IS NULL OR b.expiry_date>?)),0))
        ELSE p.stock_quantity END)>0 THEN 0 ELSE 1 END END AS eligibility,
      COALESCE(stats.receipts,0) AS receipts,COALESCE(stats.net_quantity,0) AS net_quantity
      FROM matched m JOIN products p ON p.id=m.product_id
      LEFT JOIN cashier_product_popularity stats ON stats.product_id=p.id WHERE p.is_deleted=0)
    SELECT * FROM scored ${after == null ? '' : 'WHERE ($tuple)>(${List.filled(frequent ? 7 : 5, '?').join(',')})'}
    ORDER BY code_tier,eligibility,${frequent ? 'receipts DESC,net_quantity DESC,' : ''}
      relevance,normalized_name COLLATE BINARY,id COLLATE BINARY LIMIT ?''',
    [
      raw,
      raw,
      if (labelId != null) labelId.value,
      q,
      q,
      ?end,
      raw,
      raw,
      if (labelId != null) labelId.value,
      today,
      today,
      if (after != null) ...[
        after.codeTier,
        after.eligibility,
        if (frequent) ...[-after.receipts, -after.quantity],
        after.relevance,
        after.name,
        after.id.value,
      ],
      pageSize + 1,
    ],
  );
}
