"""Fetch the pinned official Mbed TLS release and vendor a minimal KDF subset.

No runtime download; the compiled APK uses only SHA256/HMAC/PBKDF2. Source files
are byte-for-byte copies with license and reproducible digest manifest.
"""
import hashlib
import io
import json
from pathlib import Path
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
VERSION = "3.6.7"
EXPECTED = "a7e8bcbec0e6f761b4af24f25677626b35f762f68eef79c08677a363212d11f6"
URL = f"https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-{VERSION}/mbedtls-{VERSION}.tar.bz2"
TARGET = ROOT / "android/app/src/main/cpp/third_party/mbedtls"
archive = urllib.request.urlopen(URL, timeout=60).read()
assert hashlib.sha256(archive).hexdigest() == EXPECTED, "Release checksum mismatch"
manifest = {}
with tarfile.open(fileobj=io.BytesIO(archive), mode="r:bz2") as source:
    for member in source.getmembers():
        parts = Path(member.name).parts
        if len(parts) < 2 or parts[0] != f"mbedtls-{VERSION}" or not member.isfile():
            continue
        relative = Path(*parts[1:])
        # Headers include transitive configuration declarations, but only four
        # implementation units are compiled by our explicit CMake source list.
        wanted = str(relative).replace("\\", "/").startswith(("include/mbedtls/", "include/psa/")) or str(relative).replace("\\", "/") in {
            "LICENSE", "LICENSES/Apache-2.0.txt", "LICENSES/GPL-2.0-or-later.txt",
            "library/md.c", "library/sha256.c", "library/pkcs5.c",
            "library/platform_util.c", "library/common.h", "library/alignment.h",
            "library/md_wrap.h", "library/psa_util_internal.h",
        }
        if not wanted:
            continue
        destination = (TARGET / relative).resolve()
        assert destination.is_relative_to(TARGET.resolve()), "Unsafe archive member"
        data = source.extractfile(member).read()
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        manifest[relative.as_posix()] = hashlib.sha256(data).hexdigest()
TARGET.mkdir(parents=True, exist_ok=True)
(TARGET / "PROVENANCE.json").write_text(json.dumps({
    "version": VERSION, "release_url": URL, "archive_sha256": EXPECTED,
    "license_selected": "Apache-2.0", "files_sha256": manifest,
}, indent=2) + "\n", encoding="utf-8")
apk_license = ROOT / "android/app/src/main/assets/third_party/mbedtls-LICENSE.txt"
apk_license.parent.mkdir(parents=True, exist_ok=True)
apk_license.write_bytes((TARGET / "LICENSE").read_bytes())
print(f"Verified official archive; vendored {len(manifest)} unchanged files.")
