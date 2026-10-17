"""Read-only APK identity, native ABI/JNI/alignment and license verification."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--apk', type=Path, required=True)
parser.add_argument('--kind', choices=['ordinary', 'fixture'], required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--arm32-only', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
sdk = Path(r'C:\Users\ACER\AppData\Local\Android\sdk')
aapt = sdk / 'build-tools/36.0.0/aapt.exe'
readelf = sdk / 'ndk/28.2.13676358/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-readelf.exe'
expected = 'com.example.kasir_app' + ('.integration' if args.kind == 'fixture' else '')
def run(*cmd):
    return subprocess.check_output([str(c) for c in cmd], text=True, encoding='utf-8', errors='replace')
badging = run(aapt, 'dump', 'badging', args.apk)
assert f"package: name='{expected}' " in badging
assert "sdkVersion:'24'" in badging
launcher = 'IntegrationActivity' if args.kind == 'fixture' else 'MainActivity'
assert f"name='com.example.kasir_app.{launcher}'" in badging
permissions = run(aapt, 'dump', 'permissions', args.apk)
run(sdk / 'build-tools/36.0.0/zipalign.exe', '-c', '-P', '16', '4', args.apk)
result = {'apk': str(args.apk), 'sha256': hashlib.sha256(args.apk.read_bytes()).hexdigest(),
          'bytes': args.apk.stat().st_size, 'package': expected, 'min_sdk': 24,
          'metadata': [s for s in badging.splitlines() if s.startswith(('package:', 'application-label:', 'native-code:', 'launchable-activity:'))],
          'permissions': permissions.splitlines(), 'native': [], 'installed_by_this_check': False}
result['zipalign_16k_pass'] = True
with zipfile.ZipFile(args.apk) as archive:
    dex = [n for n in archive.namelist() if re.fullmatch(r'classes\d*\.dex', n)]
    assert dex
    if args.kind == 'ordinary':
        assert all(b'Lcom/example/kasir_app/IntegrationActivity;' not in archive.read(n) for n in dex)
        assert "application-label:'kasir_app'" in badging
    result['dex_checked'] = dex
    license_bytes = archive.read('assets/third_party/mbedtls-LICENSE.txt')
    assert license_bytes == (root / 'android/app/src/main/cpp/third_party/mbedtls/LICENSE').read_bytes()
    result['license_packaged_unchanged'] = True
    libraries = [n for n in archive.namelist() if re.fullmatch(r'lib/[^/]+/libkasir_pin_kdf\.so', n)]
    abis = {Path(n).parts[1] for n in libraries}
    assert abis == ({'armeabi-v7a'} if args.arm32_only else {'armeabi-v7a', 'arm64-v8a', 'x86_64'}), abis
    for name in libraries:
        abi = Path(name).parts[1]
        target = root / 'build/realme-c11-20261015/verified-native' / args.kind / abi / 'libkasir_pin_kdf.so'
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(archive.read(name))
        elf = run(readelf, '--file-header', target)
        elf_class = re.search(r'Class:\s*(\S+)', elf)[1]
        machine = re.search(r'Machine:\s*([^\r\n]+)', elf)[1].strip()
        assert elf_class == ('ELF32' if abi == 'armeabi-v7a' else 'ELF64')
        assert {'armeabi-v7a':'ARM', 'arm64-v8a':'AArch64', 'x86_64':'Advanced Micro Devices X86-64'}[abi] == machine
        symbols = run(readelf, '--dyn-syms', '--wide', target)
        assert 'Java_com_example_kasir_1app_MainActivity_nativeDerive' in symbols
        headers = run(readelf, '--program-headers', '--wide', target)
        loads = [s for s in headers.splitlines() if s.lstrip().startswith('LOAD')]
        assert loads and all(int(s.split()[-1], 16) >= 16384 for s in loads)
        dynamic = run(readelf, '--dynamic', '--wide', target)
        needed = re.findall(r'Shared library: \[([^\]]+)\]', dynamic)
        assert not any('crypto' in n.lower() or 'ssl' in n.lower() for n in needed), needed
        result['native'].append({'abi': abi, 'bytes': target.stat().st_size,
            'elf_class': elf_class, 'machine': machine,
            'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
            'jni_export_present': True, 'load_alignment_at_least_16k': True, 'needed': needed})
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
print(f'PASS {expected}: minSdk24, {sorted(abis)}, JNI exports, 16KiB ELF alignment, license, DEX/launcher identity; no install.')
