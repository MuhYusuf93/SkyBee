# Local PIN KDF backend

`kasir_pin_kdf` runs PBKDF2-HMAC-SHA256 (600,000–2,000,000 iterations,
32-byte output) on Flutter's serial background task queue. Android's UI thread
does not execute the KDF. It consumes the exact Dart UTF-8 bytes and existing
salt; credential format, random source, domain separation, lockout, session,
compare-and-swap and constant-length verifier comparison remain unchanged.

Only Mbed TLS `md.c`, `sha256.c`, `pkcs5.c`, `platform_util.c` are compiled.
The minimal config enables MD/SHA256/PKCS5; no TLS, network or PSA service is
enabled. Transitive public headers are retained verbatim. JNI validates bounds,
uses explicit heap copies, checks errors and clears password/output buffers.
Unavailable native embedding falls back to the original Dart KDF on an isolate
with the same parameters. Calculation errors do not return a dummy verifier.

The official **Mbed TLS 3.6.7** release is pinned and its Apache-2.0 license is
selected under the upstream dual license. See `third_party/mbedtls/PROVENANCE.json`
for release URL, verified archive SHA256 and every unchanged source digest;
`LICENSE` contains the full license texts and accompanies the source; the same
text is packaged in APK assets at `third_party/mbedtls-LICENSE.txt`. Reproduce with
`tools/vendor_pin_crypto.py` from the project root. This is a development-time
download only. Review upstream security releases before shipping or upgrading;
3.6 LTS support is currently stated through at least March 2027.

No private platform symbols, system configuration changes, fixed ABI restriction
or minimum SDK changes. CMake build ABIs follow Flutter's requested target list
(all original three for universal builds); this avoids advertising a KDF-only
ABI without a matching Flutter engine/app in a single-target APK.
`-O2` also applies to debug so native KDF timing is useful;
it does not reduce the iteration count. 16-KiB linker alignment is requested.
The JNI export follows the Kotlin declaring class, not the applicationId. If
that class/package is renamed later, update the export and rerun release
linkage/vector checks; an applicationId-only change does not rename the class.
Validate all packaged ABIs and release JNI linkage, plus independent Python
hashlib vectors (ASCII, recovery domain, UTF-8, empty/long input, salt lengths,
non-default rounds), legacy Dart parity and existing-verifier unlock without
rewriting the salt/verifier. Use the safe Android test runner.

Sources: [upstream release](https://github.com/Mbed-TLS/mbedtls/releases/tag/mbedtls-3.6.7),
[Flutter background task queues](https://api.flutter.dev/javadoc/io/flutter/plugin/common/BinaryMessenger.html),
[PBKDF2 standard](https://www.rfc-editor.org/rfc/rfc8018#section-5.2).
