"""Bounded framework smoke: no game matrix, network listener or external account."""
from pathlib import Path
import json
import os
import signal
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[2]
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=True)
if (out / 'summary.json').exists(): raise SystemExit('Use a fresh output directory.')
gates = [
    ('replay_packages', 'REPLAY_PACKAGES_OK'),
    ('replay_recipes', 'REPLAY_RECIPES_OK'),
    ('replay', 'REPLAY_OK'),
    ('replay_schema', 'REPLAY_SCHEMA_OK'),
    ('replay_view', 'REPLAY_VIEW_OK'),
    ('replay_net', 'REPLAY_NET_OK'),
    ('replay_interest', 'REPLAY_INTEREST_OK'),
    ('replay_owned', 'REPLAY_OWNED_OK'),
    ('replay_authority', 'REPLAY_AUTHORITY_OK'),
    ('replay_recovery', 'REPLAY_RECOVERY_OK'),
    ('replay_p2p', 'REPLAY_P2P_OK'),
    ('replay_p2p_link', 'REPLAY_P2P_LINK_OK'),
    ('replay_p2p_provision', 'REPLAY_P2P_PROVISION_OK'),
    ('replay_provision_godot_core', 'REPLAY_PROVISION_GODOT_CORE_OK'),
]
summary = {'pass': False, 'profile': 'framework-core', 'gates': []}
started = time.monotonic()
for name, marker in gates:
    began = time.monotonic()
    with (out / f'{name}.log').open('w') as log:
        proc = subprocess.Popen(['bash', str(root / 'tests' / name / 'run.sh')], cwd=root, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        timed_out = False
        try:
            code = proc.wait(timeout=min(300, max(1, 900 - (time.monotonic() - started))))
        except (subprocess.TimeoutExpired, KeyboardInterrupt):
            timed_out = True
            os.killpg(proc.pid, signal.SIGTERM)
            try: proc.wait(timeout=5)
            except subprocess.TimeoutExpired: os.killpg(proc.pid, signal.SIGKILL); proc.wait()
            code = 124
    passed = code == 0 and marker in (out / f'{name}.log').read_text()
    summary['gates'].append({'name': name, 'pass': passed, 'exit': code, 'timed_out': timed_out, 'seconds': round(time.monotonic() - began, 3)})
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(f'{name}: {"pass" if passed else "FAIL"}', flush=True)
    if not passed: raise SystemExit(f'Framework gate failed; inspect {out / (name + ".log")}')
summary['pass'] = True
summary['seconds'] = round(time.monotonic() - started, 3)
(out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print('REPLAY_FRAMEWORK_OK', out)
