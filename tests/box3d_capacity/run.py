#!/usr/bin/env python3
"""Build or select a coherent backend and exercise larger authored worlds."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'build'))
import box3d_capacity as capacity


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--native', type=Path)
    parser.add_argument('--profile', type=Path)
    parser.add_argument('--godot', type=Path)
    args = parser.parse_args()
    work = args.out.resolve()
    work.mkdir(parents=True, exist_ok=False)

    def run(name, command, env=None, timeout=600, marker=None):
        logfile = work / (name + '.log')
        with logfile.open('w') as log:
            result = subprocess.run(command, cwd=REPO, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
        text = logfile.read_text()
        errors = ('SCRIPT ERROR', 'ERROR:', 'ODIN_SCRIPT_PANIC',
                  'instances were leaked', 'resources still in use', 'SHUTDOWN_NOT_EMPTY')
        if result.returncode or (marker and marker not in text) or any(token in text for token in errors):
            raise RuntimeError(name + ' failed: ' + text[-12000:])
        print(name + ' PASS', flush=True)

    run('profile', [sys.executable, str(REPO / 'tests/box3d_capacity/test_profile.py')])
    if args.native:
        native = args.native.resolve(strict=True)
    else:
        cache = work / 'native'
        env = os.environ.copy()
        if args.profile:
            env['BOX3D_CAPACITY_PROFILE'] = str(args.profile.resolve(strict=True))
        run('native-build', ['bash', 'build/build_box3d.sh', 'Release', str(cache)], env)
        native = cache / 'build/Release/libogb3.a'
    manifest = json.loads((native.parent / 'build-manifest.json').read_text())
    profile = capacity.validate(manifest['capacity_profile'])
    if profile['max_bodies'] < 1000 or profile['max_joints'] < 100:
        raise ValueError('the larger-scene suite requires a profile admitting 1000 bodies and 100 joints')
    flags = capacity.odin_flags(profile)
    run('matching-profile', ['odin', 'run', 'tests/box3d_capacity/probe', '-collection:godot=.',
        '-define:BOX3D_LIBRARY=' + str(native), '-out:' + str(work / 'matching-probe'), *flags], marker='CAPACITY_MATCH_OK')
    mismatch = profile.copy()
    mismatch['max_bodies'] += 1
    run('mismatched-profile', ['odin', 'run', 'tests/box3d_capacity/probe', '-collection:godot=.',
        '-define:EXPECTED_CAPACITY_MATCH=false', '-define:BOX3D_LIBRARY=' + str(native),
        '-out:' + str(work / 'mismatch-probe'), *capacity.odin_flags(mismatch)], marker='CAPACITY_MISMATCH_REJECTED')
    run('large-worlds', ['odin', 'test', 'tests/box3d_capacity/odin', '-collection:godot=.',
        '-define:ODIN_TEST_THREADS=1', '-define:BOX3D_LIBRARY=' + str(native),
        '-out:' + str(work / 'large-tests'), *flags], marker='CAPACITY_REPLAY_NETWORK_OK')
    run('presentation', ['odin', 'test', 'tests/box3d_presentation/pure', '-collection:godot=.',
        '-define:ODIN_TEST_THREADS=1', '-out:' + str(work / 'presentation-tests'), *flags])
    if args.godot:
        project = work / 'godot-project'
        shutil.copytree(REPO / 'tests/box3d_authoring/godot/project', project)
        shutil.copytree(REPO / 'addons/box3d_authoring', project / 'addons/box3d_authoring')
        shutil.copy2(REPO / 'tests/box3d_capacity/godot/capacity.gd', project)
        suffix = 'dylib' if sys.platform == 'darwin' else 'so'
        library = native.parent / ('libogb3.' + suffix)
        env = os.environ.copy()
        env.update(BOX3D_NATIVE_LIBRARY=str(library), GODOT=str(args.godot.resolve()),
                   SCRIPT_BUILD_FLAGS='-o:speed')
        run('sdk-build', ['bash', 'build/build_scripts.sh', str(project)], env)
        run('godot-import', [str(args.godot), '--headless', '--editor', '--path', str(project), '--import'], env)
        run('godot-capacity', [str(args.godot), '--headless', '--path', str(project), '--script', 'capacity.gd'],
            env, marker='CAPACITY_GODOT_OK')
    (work / 'capacity-profile.json').write_text(json.dumps(profile, indent=2) + '\n')
    print('BOX3D_CAPACITY_OK bodies=1000 joints=100', flush=True)


if __name__ == '__main__':
    main()
