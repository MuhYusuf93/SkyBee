"""Read-only source/license checksum verification of the vendored PIN KDF."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
vendor = root / "android/app/src/main/cpp/third_party/mbedtls"
provenance = json.loads((vendor / "PROVENANCE.json").read_text(encoding="utf-8"))
assert provenance["version"] == "3.6.7"
assert provenance["archive_sha256"] == "a7e8bcbec0e6f761b4af24f25677626b35f762f68eef79c08677a363212d11f6"
for name, digest in provenance["files_sha256"].items():
    source = (vendor / name).resolve()
    assert source.is_relative_to(vendor.resolve())
    assert hashlib.sha256(source.read_bytes()).hexdigest() == digest, name
assert (root / "android/app/src/main/assets/third_party/mbedtls-LICENSE.txt").read_bytes() == (vendor / "LICENSE").read_bytes()
print(f"PASS: {len(provenance['files_sha256'])} unchanged upstream files; APK license identical; Mbed TLS {provenance['version']} archive pinned.")
