"""Freeze/verify maintained M5.4 test inputs without copying private artifacts."""
import argparse
import hashlib
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXTENSIONS = {'.dart', '.arb', '.yaml', '.json', '.java', '.kt', '.kts', '.xml',
              '.c', '.cpp', '.h', '.cmake', '.gradle', '.py', '.ps1', '.txt', '.png'}
SKIP_DIRS = {'build', '.gradle', '.cxx', '.dart_tool', '__pycache__'}


def excluded(name):
    return name.lower().startswith(('gemini_', 'gemini2_'))


def capture():
    files = {ROOT / name for name in ('pubspec.yaml', 'pubspec.lock', '.gitignore')}
    for folder in ('lib', 'test', 'integration_test', 'android', 'packages', 'assets', 'tools'):
        for directory, children, names in os.walk(ROOT / folder):
            children[:] = [name for name in children if name not in SKIP_DIRS and not excluded(name)]
            for name in names:
                path = Path(directory) / name
                if excluded(name) or name == 'GeneratedPluginRegistrant.java':
                    continue
                if path.suffix in EXTENSIONS:
                    files.add(path)
    return {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(files) if path.is_file()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    # Manifests contain only relative source paths and digests. Do not write
    # inside any operational sandbox or over a source file on a typo.
    destination = args.manifest.resolve()
    if not destination.is_relative_to(ROOT / 'build') or destination.suffix != '.json':
        raise SystemExit('Manifest must be a JSON file under workspace build/')
    current = capture()
    if args.verify:
        expected = json.loads(destination.read_text(encoding='utf-8'))
        if expected != current:
            changed = [name for name in expected.keys() | current.keys()
                       if expected.get(name) != current.get(name)]
            raise SystemExit('Frozen source changed: ' + ', '.join(sorted(changed)))
    else:
        if destination.exists():
            raise SystemExit('Preserve the original manifest; choose a new run filename')
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(current, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'sourceFiles': len(current), 'verified': args.verify,
                      'manifestSha256': hashlib.sha256(destination.read_bytes()).hexdigest()}))


if __name__ == '__main__':
    main()
