"""Independent CSV/SpreadsheetML checks for the public M5.2 export fixture."""
import csv
import json
import pathlib
import zipfile
import xml.etree.ElementTree as ET

root = pathlib.Path(__file__).resolve().parents[1] / 'build/m52-report-reader'
with (root / 'report.csv').open(encoding='utf-8-sig', newline='') as stream:
    csv_rows = list(csv.DictReader(stream))
ns = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
xlsx_rows = []
with zipfile.ZipFile(root / 'report.xlsx') as book:
    for name in sorted(book.namelist()):
        if name.startswith('xl/worksheets/sheet') and name.endswith('.xml'):
            rows = []
            for row in ET.fromstring(book.read(name)).findall('s:sheetData/s:row', ns):
                rows.append([''.join(cell.itertext()) for cell in row])
            xlsx_rows.extend(dict(zip(rows[0], row)) for row in rows[1:])
for rows in (csv_rows, xlsx_rows):
    fake_item = next(row for row in rows if row['section'] == 'items' and row['name'] == 'PUBLIC export untracked')
    assert fake_item['quantity'] == '3'
    assert fake_item['stock_tracking'] == 'untracked'
    assert fake_item['cost_basis'] == 'reference_purchase_per_unit'
    assert fake_item['gross_minor'] == '30000'
    assert fake_item['discount_minor'] == '3750'
    assert fake_item['amount_minor'] == '26250'
    assert fake_item['cost_micros'] == '21000000000'
    assert json.loads(fake_item['promo_snapshot'])['name'] == 'PUBLIC export promo'
    fake = next(row for row in rows if row['section'] == 'current_inventory' and row['name'] == 'PUBLIC export untracked')
    real = next(row for row in rows if row['section'] == 'current_inventory' and row['name'] == 'PUBLIC export tracked')
    assert fake['stock_pcs'] == '999 — Stok fiktif (tidak dilacak)' and fake['cost_micros'] == '—'
    assert real['stock_pcs'] == '998' and real['stock_tracking'] == 'tracked'
assert len(csv_rows) == len(xlsx_rows)
print(json.dumps({'status': 'PASS', 'formats': ['CSV', 'XLSX'], 'rowsPerFormat': len(csv_rows)}))
