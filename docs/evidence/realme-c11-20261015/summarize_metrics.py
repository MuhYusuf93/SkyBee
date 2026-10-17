"""Summarize saved samples only; never substitutes absence for a passing run."""
import json
import re
import statistics
from pathlib import Path

folder = Path(__file__).resolve().parent
result = {}

def samples(values):
    return {'samples': values, 'median': statistics.median(values),
            'min': min(values), 'max': max(values), 'n': len(values)}

for name in ['runtime-profile-before-pin-opt', 'runtime-profile', 'runtime-release']:
    path = folder / (name+'.json')
    if not path.exists():
        continue
    raw = json.loads(path.read_text(encoding='utf-8-sig'))
    row = {'runtime_assertions_passed': raw.get('runtime_assertions_passed'),
           'failures': raw.get('failures'), 'groups': {}}
    for kind in ['cold', 'warm']:
        runs = [r for r in raw['launches'] if r['actual_kind'] == kind and
                r['stage']['stage'] == 'committed_recovered']
        # Before has three committed cold runs; current has initial + three.
        # Compare the last three consistently, and retain every raw sample.
        compared = runs[-3:] if kind == 'cold' else runs
        if compared:
            row['groups'][kind] = {
                'stage_ready_seconds': samples([r['stage_ready_seconds'] for r in compared]),
                'activity_total_ms': samples([int(re.search(r'TotalTime: (\d+)',r['am_start'])[1]) for r in compared]),
                'all_pids': [r['pid'] for r in runs],
                'all_stage_ready_seconds': [r['stage_ready_seconds'] for r in runs],
            }
    last = raw['launches'][-1]['stage']
    for field in ['search_5_samples_us', 'report_5_samples_us']:
        if field in last:
            row[field] = samples(last[field])
    pin = [r['stage']['pin_verification_us'] for r in raw['launches']
           if r['actual_kind'] == 'cold' and 'pin_verification_us' in r['stage']]
    if pin:
        row['pin_us'] = samples(pin)
    if 'debounced_search' in raw:
        row['debounced_search_us'] = samples(raw['debounced_search']['debounced_search_5_samples_us'])
    result[name] = row

for mode in ['profile','release']:
    path = folder / f'actual-{mode}.json'
    if not path.exists():
        continue
    raw = json.loads(path.read_text(encoding='utf-8-sig'))
    row = {k:raw.get(k) for k in ['completed','failures','memory','details','android_home_relock_observed']}
    for kind in ['cold','warm']:
        runs = [r for r in raw['launches'] if r['actual_kind'] == kind]
        if runs:
            row[kind] = {
                'activity_total_ms': samples([int(re.search(r'TotalTime: (\d+)',r['am_start'])[1]) for r in runs]),
                'ui_observation_bound_seconds': samples([r['ui_observation_bound_seconds'] for r in runs])}
    result[f'actual-{mode}'] = row
(folder/'metrics-summary.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,indent=2))
