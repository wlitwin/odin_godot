#!/usr/bin/env python3
"""Run the independent strict Replay ownership/physics contract fixture.

The existing fixture assumes malloc does not reuse a retired model-alias address
while its meter context remains live. The meter deliberately rejects that reuse.
This command retains a nonzero result on failure; it does not retry or bypass
the lifetime rule, and is not part of the default capacity gate.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'build'))
import box3d_profile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    native = args.native.resolve()
    info = box3d_profile.native_input(native, ROOT, box3d_profile.current_target())
    if not info['shared_metadata_executed']:
        raise ValueError('strict runner requires a shared library for this host architecture')
    (out / 'native-input.json').write_text(json.dumps(info, indent=2) + '\n')
    env = os.environ.copy()
    variable = 'DYLD_LIBRARY_PATH' if sys.platform == 'darwin' else 'PATH' if os.name == 'nt' else 'LD_LIBRARY_PATH'
    env[variable] = str(native.parent) + (os.pathsep + env[variable] if env.get(variable) else '')
    executable = out / ('runner.exe' if os.name == 'nt' else 'runner')
    command = [os.environ.get('ODIN', 'odin'), 'test', str(Path(__file__).parent),
               '-collection:godot=' + str(ROOT), '-keep-executable',
               '-define:ODIN_TEST_THREADS=1', '-define:BOX3D_REQUIRE_DOMAIN=true',
               '-define:BOX3D_LIBRARY=' + str(native),
               '-define:BOX3D_EXPECTED_BUILD=sha256:' + info['domain']['build'],
               '-define:BOX3D_EXPECTED_TARGET=sha256:' + info['domain']['target'],
               *info['odin_capacity_flags'], '-out:' + str(executable)]
    if sys.platform == 'darwin':
        # Odin's automatic test launch goes through a system shell that strips
        # DYLD variables. Embed the same verified lookup path for that launch.
        command.append('-extra-linker-flags:-Wl,-rpath,' + str(native.parent))
    report = {
        'status': 'running',
        'scope': 'real native backend with fake Core protection hooks; not Godot module unloading',
        'known_fixture_assumption': 'The live meter rejects reuse of retired alias addresses; the fixture currently assumes malloc will not reuse one for its later resumed Server.',
        'commands': [],
    }
    try:
        for name, argv in [('build-and-test', command), ('execute', [str(executable)])]:
            row = {'name': name, 'command': argv, 'log': name + '.log'}
            report['commands'].append(row)
            try:
                with (out / row['log']).open('w') as log:
                    completed = subprocess.run(argv, cwd=ROOT, env=env, stdout=log,
                                               stderr=subprocess.STDOUT, timeout=600)
                row['exit_code'] = completed.returncode
                if completed.returncode:
                    raise RuntimeError(f'{name} failed; inspect {out / row["log"]}')
            except (OSError, subprocess.TimeoutExpired) as error:
                row['error'] = str(error)
                raise
        report['status'] = 'passed'
    finally:
        if report['status'] != 'passed':
            report['status'] = 'failed'
        (out / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print('BOX3D_STRICT_REPLAY_RUNNER_OK', flush=True)


if __name__ == '__main__':
    main()
