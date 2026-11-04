#!/usr/bin/env python3
"""Current public recovery suites. Default: record a plan and start no jobs."""
from pathlib import Path
import argparse, hashlib, json, os, signal, subprocess, sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
ATTRIBUTES = ('gd_method', 'gd_connect', 'gd_rpc', 'gd_command', 'gd_tick',
              'gd_input', 'gd_sample', 'gd_step', 'gd_event', 'gd_half', 'gd_message')


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''): digest.update(block)
    return digest.hexdigest()


def source_map(suites):
    folders = ['box3d', 'kit', 'replay', 'examples/box3d_common',
               'examples/replay_box3d/shared', 'tests/kit_box3d_net',
               'tests/kit_world_protocol', 'tests/replay_physics_net',
               'tests/box3d_bounds', 'tests/box3d_soak/replay']
    folders += ['tests/box3d_recovery_flows/' + name for name in suites if name != 'legacy-kit']
    return {str(p.relative_to(ROOT)): sha(p) for name in folders if (ROOT / name).is_dir()
            for p in sorted((ROOT / name).rglob('*')) if p.is_file()
            and p.suffix in {'.odin', '.c', '.h', '.py', '.json'}
            and '__pycache__' not in p.parts and not p.name.endswith('.gen.odin')}


def save(path, value):
    with path.open('x') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n'); stream.flush(); os.fsync(stream.fileno())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', choices=('kit', 'replay', 'legacy-kit', 'all'), default='all')
    parser.add_argument('--odin', type=Path, required=True)
    parser.add_argument('--native-library', type=Path, required=True)
    parser.add_argument('--native-sha256', required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    if not all(p.is_absolute() for p in (args.odin, args.native_library, args.out)):
        parser.error('tool, Native and output paths must be absolute')
    out = args.out.resolve()
    if out == ROOT or ROOT in out.parents: parser.error('output must be new and outside the repository')
    out.mkdir(parents=True, exist_ok=False)
    suites = ('legacy-kit', 'kit', 'replay') if args.suite == 'all' else (args.suite,)
    packages = {name: ROOT / 'tests/kit_box3d_net' if name == 'legacy-kit' else HERE / name for name in suites}
    argv = {name: [str(args.odin), 'test', str(path), '-collection:godot=' + str(ROOT),
             '-define:BOX3D_LIBRARY=' + str(args.native_library), '-define:ODIN_TEST_THREADS=1',
             '-out:' + str(out / ('recovery-' + name))]
             + ['-custom-attribute:' + item for item in ATTRIBUTES] for name, path in packages.items()}
    save(out / 'plan.json', {'result': 'STAGED_ONLY', 'jobs_started': 0, 'argv': argv,
                             'native_library': str(args.native_library), 'native_sha256': args.native_sha256})
    if not args.execute:
        print(json.dumps({'result': 'STAGED_ONLY', 'plan': str(out / 'plan.json')})); return 0
    sources = source_map(suites); helper = sha(Path(__file__))
    native, compiler = sha(args.native_library), sha(args.odin)
    if native != args.native_sha256: raise ValueError('actual Native SHA differs')
    report = {'result': 'FAIL', 'steps': [], 'source_before': sources,
              'native_library': str(args.native_library), 'native_sha256': native,
              'compiler': str(args.odin), 'compiler_sha256': compiler,
              'scope': 'public standalone recovery and migrated current Kit tests; static/nil-owner, no SDK/hardware/performance claim'}
    try:
        for name, path in packages.items():
            if not list(path.glob('*_test.odin')): raise ValueError('missing actual suite ' + name)
            log = out / (name + '.log')
            with log.open('xb') as stream:
                child = subprocess.Popen(argv[name], cwd=out, stdout=stream,
                                         stderr=subprocess.STDOUT, start_new_session=True)
                try: code = child.wait(timeout=180)
                except BaseException:
                    try: os.killpg(child.pid, signal.SIGKILL)
                    except ProcessLookupError: pass
                    child.wait(timeout=10); raise
                finally: stream.flush(); os.fsync(stream.fileno())
            report['steps'].append({'suite': name, 'argv': argv[name], 'pid': child.pid,
                                    'actual_exit': code, 'log': str(log), 'log_sha256': sha(log)})
            if code: raise RuntimeError('actual recovery suite failed: ' + name)
        report['result'] = 'PASS'
    except Exception as exc: report['error'] = repr(exc)
    finally:
        report['source_fence_unchanged'] = sources == source_map(suites) and helper == sha(Path(__file__))
        report['native_fence_unchanged'] = native == sha(args.native_library)
        report['compiler_fence_unchanged'] = compiler == sha(args.odin)
        if not all(report[k] for k in ('source_fence_unchanged', 'native_fence_unchanged', 'compiler_fence_unchanged')):
            report['result'] = 'FAIL'
        save(out / 'report.json', report)
    print(json.dumps({'result': report['result'], 'report': str(out / 'report.json'), 'error': report.get('error')}))
    return 0 if report['result'] == 'PASS' else 1


if __name__ == '__main__': raise SystemExit(main())
