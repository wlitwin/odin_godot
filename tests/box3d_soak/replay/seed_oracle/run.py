#!/usr/bin/env python3
"""One plain Odin descriptor build/run; no scriptgen, Godot or simulation."""
from pathlib import Path
import hashlib
import json
import struct
import subprocess
import sys

repo = Path(__file__).resolve().parents[4]
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=False)
native = Path('/tmp/odin-box3d-goal-t4jbbj4v/box3d-native-count-once-v1/cache/build/Release/libogb3.a')
expected_native = '6a6a19edc5f9c4023229155a4822630f3ea58e6363fd91be7100a10b00ef898f'
ready_log = Path('/tmp/odin-box3d-goal-t4jbbj4v/controller-live-replay32-clean-long-v1/host/godot.log')

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def sources():
    roots = ['box3d', 'replay', 'examples/box3d_common',
             'examples/replay_box3d/shared/adapter',
             'tests/box3d_soak/replay/seed_oracle']
    return dict(sorted((str(p.relative_to(repo)), sha(p))
                       for root in roots for p in (repo / root).rglob('*')
                       if p.is_file() and p.suffix in ('.odin', '.py')
                       and not any(part in ('bin', '__pycache__') for part in p.parts)))

assert sha(native) == expected_native
before = sources()
(out / 'sources-before.json').write_text(json.dumps(before, sort_keys=True) + '\n')
command = ['nix', 'develop', '--command', 'odin', 'build',
           str(repo / 'tests/box3d_soak/replay/seed_oracle'),
           '-collection:godot=' + str(repo), '-define:BOX3D_LIBRARY=' + str(native),
           '-o:speed', '-debug', '-extra-linker-flags:-lc++',
           '-out:' + str(out / 'seed-oracle')]
with (out / 'build.log').open('x') as log:
    build = subprocess.run(command, cwd=repo, stdout=log, stderr=subprocess.STDOUT)
after = sources()
(out / 'sources-after.json').write_text(json.dumps(after, sort_keys=True) + '\n')
binding = dict(schema=1, argv=command, build_exit=build.returncode,
               source_fence_unchanged=before == after,
               sources_before_sha256=sha(out / 'sources-before.json'),
               sources_after_sha256=sha(out / 'sources-after.json'),
               native_archive=str(native), native_archive_sha256=sha(native),
               native_manifest=str(native.with_name('build-manifest.json')),
               native_manifest_sha256=sha(native.with_name('build-manifest.json')))
if build.returncode == 0:
    binding['binary_sha256'] = sha(out / 'seed-oracle')
    with (out / 'stdout.json').open('x') as stdout, (out / 'stderr.log').open('x') as stderr:
        run = subprocess.run([str(out / 'seed-oracle')], cwd=out, stdout=stdout, stderr=stderr)
    binding['run_exit'] = run.returncode
    if run.returncode == 0:
        public = json.loads((out / 'stdout.json').read_text())
        app = (out / 'application_rules.bin').read_bytes()
        canonical = (out / 'provider_config.canonical.bin').read_bytes()
        values = (out / 'provider_config.values.bin').read_bytes()
        actual = (out / 'bound_game_rules.bin').read_bytes()
        domain = b'odin-godot.replay.physics-rules.v1'
        fields = [(b'application', app), (b'provider_schema', canonical), (b'provider_values', values)]
        descriptor = b'OGB3DESC1' + struct.pack('<Q', len(domain)) + domain + struct.pack('<I', len(fields))
        for tag, value in fields:
            descriptor += struct.pack('<I', len(tag)) + tag + struct.pack('<Q', len(value)) + value
        (out / 'network_bound_rules.descriptor.bin').write_bytes(descriptor)
        ready = next(json.loads(line[line.index('{'):]) for line in ready_log.read_text().splitlines()
                     if line.startswith('BOX3D_SLICE_READY '))
        report = dict(schema=1, scope=public['scope'], initial=32, seed=17,
                      application_rules_sha256=app.hex(), bound_game_rules_sha256=actual.hex(),
                      python_descriptor_sha256=hashlib.sha256(descriptor).hexdigest(),
                      ready=dict(path=str(ready_log), file_sha256=sha(ready_log),
                                 game_rules=ready['game_rules']), public=public,
                      bytes={name:dict(length=(out / name).stat().st_size, sha256=sha(out / name))
                             for name in ['application_rules.bin', 'provider_config.canonical.bin',
                                          'provider_config.values.bin', 'bound_game_rules.bin',
                                          'network_bound_rules.descriptor.bin']})
        report['ok'] = (public['ok'] and before == after and
                        actual.hex() == ready['game_rules'] == report['python_descriptor_sha256'])
        (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
(out / 'build-binding.json').write_text(json.dumps(binding, indent=2) + '\n')
print(json.dumps(binding, indent=2))
sys.exit(0 if (out / 'report.json').exists() and json.loads((out / 'report.json').read_text())['ok'] else 1)
