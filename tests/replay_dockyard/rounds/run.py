#!/usr/bin/env python3
"""Extract the actual authored scene and exercise its current reducer/Native world."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('round_commands', ROOT / 'tests/box3d_web/integration/run.py')
shared = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shared)


def sources():
    paths = [ROOT / 'replay/physics/commands.odin']
    for folder in [ROOT / 'examples/replay_dockyard', HERE]:
        paths += [p for p in folder.rglob('*') if p.is_file() and p.suffix in {'.odin', '.gd', '.tscn', '.tres', '.py'}
                  and not p.name.endswith('.gen.odin') and not any(x in p.parts for x in ['bin', '.godot', '__pycache__'])]
    return {str(p.relative_to(ROOT)): shared.sha(p) for p in sorted(set(paths))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--build-record', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--native-library', type=Path, required=True)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--odin', required=True)
    args = parser.parse_args()
    output = args.out.resolve()
    if output.is_relative_to(ROOT):
        parser.error('new output outside the repository required')
    output.mkdir(parents=True, exist_ok=False)
    build = json.loads(args.build_record.read_text())
    if build['result'] != 'PASS' or Path(build['project']).resolve() != args.project.resolve():
        parser.error('successful ordinary SDK build bound to this project required')
    before = sources()
    native_before = shared.sha(args.native_library)
    report = dict(result='FAIL', steps=[], sources=before, build_record_sha256=shared.sha(args.build_record),
                  native_sha256=native_before, scope='Actual authored extraction plus standalone Native complete Timeline/reducer tests; not multiplayer or SDK quota qualification')
    env = os.environ.copy()
    env.update(ODIN_GODOT_ROOT=str(ROOT), BOX3D_NATIVE_LIBRARY=str(args.native_library.resolve()))
    try:
        shared.command(output, 'prepare-import', ['python3', str(ROOT / 'build/box3d_profile.py'), '--prepare-import', str(args.project.resolve())], env, report, 120)
        shared.command(output, 'import', [args.godot, '--headless', '--editor', '--path', str(args.project.resolve()), '--quit-after', '120'], env, report, 180)
        definition = output / 'definition.json'
        shared.command(output, 'extract', [args.godot, '--headless', '--path', str(args.project.resolve()),
                       '--script', str(HERE / 'extract.gd'), '--', str(definition)], env, report, 120)
        if not definition.is_file() or not 0 < definition.stat().st_size <= 2*1024*1024:
            raise RuntimeError('actual exported definition missing or outside bound')
        argv = [args.odin, 'test', str(HERE), '-collection:godot=' + str(ROOT),
                '-define:BOX3D_LIBRARY=' + str(args.native_library.resolve()),
                '-define:DOCKYARD_DEFINITION=' + str(definition), '-define:ODIN_TEST_THREADS=1',
                '-o:speed', '-debug', '-keep-executable', '-out:' + str(output / 'round-tests')]
        argv += ['-custom-attribute:' + name for name in ('gd_method', 'gd_connect', 'gd_rpc', 'gd_command', 'gd_tick', 'gd_input', 'gd_sample', 'gd_step', 'gd_event', 'gd_half', 'gd_message')]
        # The selected shared backend has its normal relocatable install name.
        # Stage those exact bytes beside the standalone test executable.
        shutil.copyfile(args.native_library, output / args.native_library.name)
        if shared.sha(output / args.native_library.name) != native_before:
            raise RuntimeError('staged Native bytes differ')
        shared.command(output, 'round-tests', argv, env, report, 600)
        report.update(result='PASS', definition_sha256=shared.sha(definition), binary_sha256=shared.sha(output / 'round-tests'))
    except Exception as error:
        report['error'] = repr(error)
    finally:
        report['source_fence'] = before == sources()
        report['native_fence'] = native_before == shared.sha(args.native_library)
        if not report['source_fence'] or not report['native_fence']:
            report['result'] = 'FAIL'
        (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(dict(result=report['result'], report=str(output / 'report.json'), error=report.get('error'))))
    return 0 if report['result'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
