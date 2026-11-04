#!/usr/bin/env python3
"""Run exactly the explicit Root-supplied plain Odin baseline command, when granted."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[4]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--native-library', type=Path, required=True)
    p.add_argument('--native-sha256', required=True)
    p.add_argument('command', nargs=argparse.REMAINDER)
    a = p.parse_args()
    command = a.command[1:] if a.command[:1] == ['--'] else a.command
    if not command or not any(str(a.native_library.resolve()) in x for x in command):
        p.error('exact Root compiler/test argv must explicitly bind the declared static Native library')
    if sha(a.native_library) != a.native_sha256:
        p.error('declared Native SHA differs')
    out = a.out.resolve(); out.mkdir(parents=True, exist_ok=False)
    names = ['tests/box3d_soak/replay/fact_batching/fact_batching_test.odin',
             'tests/box3d_soak/replay/fact_batching/run.py',
             'tests/box3d_soak/replay/action_scope_case_a/case_a_test.odin',
             'tests/box3d_soak/replay/action_retire/action_retire_test.odin',
             'tests/box3d_soak/replay/facts_recovery/facts_recovery_test.odin',
             'tests/replay_physics_net/fixture/fixture.odin',
             'replay/net/physics_client.odin', 'replay/net/client.odin']
    before = {name:sha(ROOT/name) for name in names}
    with (out/'test.log').open('w') as log:
        try:
            code = subprocess.run(command, cwd=out, stdout=log, stderr=subprocess.STDOUT, timeout=90).returncode
        except subprocess.TimeoutExpired:
            code = None
    after = {name:sha(ROOT/name) for name in names}
    native_after = sha(a.native_library)
    observation = out/'fact-batching-observation.json'
    result = dict(scope='one synthetic generic4/staticOFFddff/nilOwner prospective work-count baseline; no live/CPU claim',
                  command=command, cwd=str(out), actual_exit=code, source_before=before, source_after=after,
                  source_fence_unchanged=before==after, source_scope='named source anchors, not exact compiler import trace',
                  native_library=str(a.native_library.resolve()), native_sha256_before=a.native_sha256,
                  native_sha256_after=native_after, native_fence_unchanged=native_after==a.native_sha256,
                  observation=json.loads(observation.read_text()) if observation.exists() else None,
                  raw_test_log_sha256=sha(out/'test.log'), sample_count=0, timing_status='NOT_MEASURED')
    result['result'] = 'PASS' if code==0 and before==after and native_after==a.native_sha256 and observation.exists() else 'FAIL'
    (out/'report.json').write_text(json.dumps(result, indent=2)+'\n')
    return 0 if result['result']=='PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
