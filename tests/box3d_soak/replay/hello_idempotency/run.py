#!/usr/bin/env python3
"""One post-ACK Hello test; source preparation is not a compile/run grant."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

repo = Path(__file__).resolve().parents[4]
assert (repo / 'flake.nix').is_file()
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=False)

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

native = Path('/tmp/odin-box3d-goal-t4jbbj4v/box3d-native-zero42-v1/off-cache/build/Release/libogb3.a')
assert sha(native) == '2be61c6e0344c3449ba97d5ef2078dfbd6fb4772167d00695b12ac44a141f432'

def sources():
    roots = ('box3d', 'replay', 'runtime', 'godot', 'gdext',
             'tests/replay_physics_net/fixture', 'tests/box3d_soak/replay/action_retire',
             'tests/box3d_soak/replay/action_scope_case_a', 'tests/box3d_soak/replay/hello_idempotency')
    return dict(sorted((str(p.relative_to(repo)), sha(p)) for root in roots
                       for p in (repo / root).rglob('*') if p.is_file()
                       and p.suffix in ('.odin', '.py') and '__pycache__' not in p.parts))

before = sources()
assert before and 'replay/net/server.odin' in before and 'replay/net/physics_packets.odin' in before
(out / 'sources-before.json').write_text(json.dumps(before, sort_keys=True) + '\n')
argv = ['nix', 'develop', str(repo), '--command', 'odin', 'test',
        str(repo / 'tests/box3d_soak/replay/hello_idempotency'), '-collection:godot=' + str(repo),
        '-define:ODIN_TEST_THREADS=1', '-define:BOX3D_LIBRARY=' + str(native),
        '-o:speed', '-debug', '-extra-linker-flags:-lc++', '-keep-executable',
        '-out:' + str(out / 'hello-idempotency')]
with (out / 'test.log').open('x') as log:
    run = subprocess.run(argv, cwd=out, stdout=log, stderr=subprocess.STDOUT)
after = sources()
(out / 'sources-after.json').write_text(json.dumps(after, sort_keys=True) + '\n')
observation = json.loads((out / 'observation.json').read_text()) if (out / 'observation.json').exists() else None
report = dict(schema=1, scope='ONE_post_ACK_public_generic4_Link_Memory_static_OFFddff_nilOwner_NOT_ENet_or_live_cause',
              argv=argv, actual_exit=run.returncode, source_fence_unchanged=before == after,
              native_archive=str(native), native_archive_sha256=sha(native), observation=observation,
              artifacts={str(p.relative_to(out)): sha(p) for p in sorted(out.iterdir()) if p.is_file()},
              expected_criterion='post-ACK exact-Hello retry preserves admitted generation/serial/baseline/view_reset',
              excluded_coverage=['active-transfer retransmission', 'fresh-incarnation rejoin', 'explicit Resync', 'ENet'])
if observation:
    checks = ('initial_ack_complete', 'first_hello_observed', 'retry_sent', 'retry_delivered',
              'same_connection_token_incarnation', 'hello_bytes_unchanged', 'post_ack_complete',
              'full5_before', 'full5_after', 'cleanup_observed')
    report['all_other_recorded_controls'] = observation['setup_complete'] and all(observation[k] for k in checks)
    report['expected_RED_reached'] = observation['criterion_reached'] and not observation['idempotent']
(out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(dict(actual_exit=run.returncode, report=str(out / 'report.json'), report_sha256=sha(out / 'report.json'))))
sys.exit(run.returncode)
