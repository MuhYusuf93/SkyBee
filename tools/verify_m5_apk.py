"""Read-only M5 APK package, complete ABI sets and 16 KiB ELF/ZIP verification."""
import argparse
import hashlib
import json
import re
import struct
import subprocess
import zipfile
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--apk', type=Path, required=True)
parser.add_argument('--kind', choices=['ordinary', 'fixture'], required=True)
parser.add_argument('--abis', default='armeabi-v7a,arm64-v8a,x86_64')
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
sdk = Path(r'C:\Users\ACER\AppData\Local\Android\sdk')
expected_abis = set(args.abis.split(','))
assert expected_abis <= {'armeabi-v7a', 'arm64-v8a', 'x86_64'}
package = 'com.example.kasir_app' + ('.integration' if args.kind == 'fixture' else '')
badging = subprocess.check_output([str(sdk/'build-tools/36.0.0/aapt.exe'),'dump','badging',str(args.apk)], text=True, encoding='utf-8')
assert f"package: name='{package}' " in badging
assert "sdkVersion:'24'" in badging
# FLN resolves the small icon by name: a successful release build can still
# strip it. Inspect the compiled resource table, not just source/ZIP filenames.
resources = subprocess.check_output([str(sdk/'build-tools/36.0.0/aapt.exe'),'dump','resources',str(args.apk)], text=True, encoding='utf-8')
assert re.search(r'\bdrawable/ic_stock_notification\b', resources), 'Required notification icon stripped/missing'
launcher = 'IntegrationActivity' if args.kind == 'fixture' else 'MainActivity'
assert f"name='com.example.kasir_app.{launcher}'" in badging
result = {'apk':str(args.apk),'sha256':hashlib.sha256(args.apk.read_bytes()).hexdigest(),'package':package,
          'min_sdk':24,'notification_icon_present':True,'native':{},'installed_by_this_check':False}

def loads(data):
    assert data[:4] == b'\x7fELF' and data[5] == 1
    elf64 = data[4] == 2
    if elf64:
        offset = struct.unpack_from('<Q',data,32)[0]
        entry_size, count = struct.unpack_from('<HH',data,54)
    else:
        offset = struct.unpack_from('<I',data,28)[0]
        entry_size, count = struct.unpack_from('<HH',data,42)
    values = []
    for index in range(count):
        base=offset+entry_size*index
        if struct.unpack_from('<I',data,base)[0] == 1:
            alignment=struct.unpack_from('<Q' if elf64 else '<I',data,base+(48 if elf64 else 28))[0]
            values.append(alignment)
    assert values
    return ('ELF64' if elf64 else 'ELF32'), values

with zipfile.ZipFile(args.apk) as archive:
    files = [n for n in archive.namelist() if re.fullmatch(r'lib/[^/]+/[^/]+\.so',n)]
    actual = {Path(n).parts[1] for n in files}
    assert actual == expected_abis, ('Unexpected advertised/native ABI set', actual, expected_abis)
    for abi in sorted(actual):
        names = {Path(n).name for n in files if Path(n).parts[1] == abi}
        assert {'libflutter.so','libkasir_pin_kdf.so','libsqlcipher.so'} <= names, (abi,names)
    for name in files:
        data=archive.read(name)
        elf_class, alignments=loads(data)
        assert all(n >= 16384 for n in alignments),(name,alignments)
        assert elf_class == ('ELF32' if Path(name).parts[1] == 'armeabi-v7a' else 'ELF64')
        result['native'][name]={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'class':elf_class,'load_alignments':alignments}
    if args.kind == 'ordinary':
        for name in archive.namelist():
            if re.fullmatch(r'classes\d*\.dex',name):
                assert b'Lcom/example/kasir_app/IntegrationActivity;' not in archive.read(name)
        assert "application-label:'kasir_app'" in badging
    assert archive.read('assets/third_party/mbedtls-LICENSE.txt') == (Path(__file__).resolve().parents[1]/'android/app/src/main/cpp/third_party/mbedtls/LICENSE').read_bytes()
    for license_file in (Path(__file__).resolve().parents[1]/'assets/third_party').glob('*LICENSE.txt'):
        assert archive.read('assets/flutter_assets/assets/third_party/'+license_file.name)==license_file.read_bytes(),license_file.name
subprocess.run([str(sdk/'build-tools/36.0.0/zipalign.exe'),'-c','-P','16','4',str(args.apk)],check=True,capture_output=True)
result['zipalign_16k_pass']=True
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'package':package,'abis':sorted(expected_abis),'libraries':len(result['native']),'zipalign_16k_pass':True}))
