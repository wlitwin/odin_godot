#!/usr/bin/env python3
"""Verify matched timing profiles through native Kit and Replay histories."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'build'))
import box3d_capacity as capacity


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--profile', type=Path)
    parser.add_argument('--native', type=Path)
    args = parser.parse_args()
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=False)

    def run(name, command, environment=None):
        log = output / (name + '.log')
        with log.open('w') as stream:
            result = subprocess.run(command, cwd=REPO, env=environment,
                stdout=stream, stderr=subprocess.STDOUT, timeout=600)
        text = log.read_text()
        if result.returncode:
            raise RuntimeError(name + ' failed:\n' + text[-12000:])
        print(name + ' PASS', flush=True)

    run('profile', [sys.executable, 'tests/box3d_capacity/test_profile.py'])
    if args.native:
        archive = args.native.resolve(strict=True)
    else:
        cache = output / 'native'
        environment = os.environ.copy()
        if args.profile:
            environment['BOX3D_CAPACITY_PROFILE'] = str(args.profile.resolve(strict=True))
        run('native-build', ['bash', 'build/build_box3d.sh', 'Release', str(cache)], environment)
        archive = cache / 'build/Release/libogb3.a'
    manifest = json.loads((archive.parent / 'build-manifest.json').read_text())
    profile = capacity.validate(manifest['capacity_profile'])
    flags = capacity.odin_flags(profile)
    for name in ('kit', 'replay'):
        run(name, ['odin', 'test', 'tests/box3d_timing/' + name, '-collection:godot=.',
            '-define:ODIN_TEST_THREADS=1', '-define:BOX3D_LIBRARY=' + str(archive),
            '-out:' + str(output / (name + '-tests')), *flags])
    run('framework-networking', ['odin', 'test', 'tests/box3d_authoring/frameworks',
        '-collection:godot=.', '-define:ODIN_TEST_THREADS=1',
        '-define:BOX3D_LIBRARY=' + str(archive), '-out:' + str(output / 'network-tests'), *flags])
    run('matched-profile', ['odin', 'run', 'tests/box3d_capacity/probe',
        '-collection:godot=.', '-define:BOX3D_LIBRARY=' + str(archive),
        '-out:' + str(output / 'match'), *flags])
    mismatched = profile.copy()
    mismatched['tick_hz'] = profile['tick_hz'] + 1 if profile['tick_hz'] < 240 else 239
    run('mismatched-timestep', ['odin', 'run', 'tests/box3d_capacity/probe',
        '-collection:godot=.', '-define:EXPECTED_CAPACITY_MATCH=false',
        '-define:BOX3D_LIBRARY=' + str(archive), '-out:' + str(output / 'mismatch'),
        *capacity.odin_flags(mismatched)])
    (output / 'profile.json').write_text(json.dumps(profile, indent=2) + '\n')
    print('BOX3D_TIMING_OK hz=%d substeps=%d history=%d kit=%d replay=%d' % (
        profile['tick_hz'], profile['substeps'], profile['history_frames'],
        profile['kit_repair_ticks'], profile['replay_window_ticks']), flush=True)


if __name__ == '__main__':
    main()
