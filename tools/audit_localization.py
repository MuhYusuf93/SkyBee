"""Read-only ARB/message-contract audit. Run after flutter gen-l10n."""
from pathlib import Path
import json
import re

root = Path(__file__).resolve().parent.parent
catalogs = [json.loads((root / f"lib/l10n/app_{lang}.arb").read_text(encoding="utf8")) for lang in ("id", "en")]
keys = [{key for key in catalog if not key.startswith("@")} for catalog in catalogs]
assert keys[0] == keys[1], "Untranslated or missing ARB keys"
for key in keys[0]:
    assert re.fullmatch(r"[a-z][A-Za-z0-9]*", key), key
    for catalog in catalogs:
        assert catalog.get("@" + key, {}).get("description"), key
    assert catalogs[0]["@" + key].get("placeholders", {}) == catalogs[1]["@" + key].get("placeholders", {}), key
references = set()
for source in (root / "lib").rglob("*.dart"):
    if source.name.startswith("app_localizations"):
        continue
    text = source.read_text(encoding="utf8")
    references.update(re.findall(r"tr\(\s*context,\s*'([^']+)'", text))
    references.update(re.findall(r"AppError\(\s*'([^']+)'", text))
assert references <= keys[0], f"Unknown semantic keys: {references - keys[0]}"
requirements = (root / "docs/REQUIREMENTS.md").read_text(encoding="utf8")
ids = re.findall(r"^\| (R\d+-\d+) \|", requirements, re.M)
assert len(ids) == len(set(ids)) == 244, "Original requirement IDs changed"
print(f"OK: {len(keys[0])} bilingual semantic keys, matching metadata/placeholders; {len(references)} static message references; 244 original requirement IDs.")
