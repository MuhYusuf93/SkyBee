"""Count crash markers for known probe PIDs without saving log payloads.

Google SDK logs may contain account details. The subprocess output is kept only
in memory; the report deliberately contains counts and scope, never raw lines.
"""
import argparse
import json
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--evidence', type=Path, required=True)
parser.add_argument('--adb', type=Path, required=True)
parser.add_argument('--device', choices=['7f0edea0'], required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
evidence = args.evidence.resolve()
if not evidence.is_relative_to(root / 'docs' / 'evidence' / 'm5-20261018'):
    raise SystemExit('Expected this campaign evidence directory')
pids = set()
for name in ('setup', 'result', 'failure'):
    path = evidence / f'{name}.json'
    if path.exists():
        data = json.loads(path.read_text(encoding='utf-8-sig'))
        for key in ('setupPid', 'workerPid'):
            if isinstance(data.get(key), int) and data[key] > 0:
                pids.add(data[key])
reports = []
for pid in sorted(pids):
    result = subprocess.run(
        [str(args.adb), '-s', args.device, 'logcat', '-d', f'--pid={pid}', '-v', 'brief'],
        capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=30,
    )
    reports.append({
        'pid': pid, 'readExit': result.returncode,
        'lineCount': len(result.stdout.splitlines()),
        'fatalMarkers': len(re.findall(r'FATAL EXCEPTION|Fatal signal', result.stdout)),
        'flutterUnhandledMarkers': len(re.findall(r'Unhandled Exception|EXCEPTION CAUGHT BY', result.stdout)),
        'anrMarkers': len(re.findall(r'\bANR in\b', result.stdout)),
    })
report = {
    'scope': 'Available logcat buffer restricted to setup/worker PIDs; no raw logs retained. Zero markers is not proof of all runtime behavior.',
    'pids': reports,
}
(evidence / 'log-marker-counts.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report))
