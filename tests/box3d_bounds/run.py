#!/usr/bin/env python3
"""Focused public bounds suites; the default only records a plan."""
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
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def sources(suites):
    # An explicit source-root fence, not an exact compiler import trace.
    folders = ('box3d', 'kit', 'replay',
               'tests/kit_world_protocol', 'tests/replay_physics_net',
               'tests/box3d_soak/replay', 'tests/box3d_slices/common', 'examples/replay_box3d/shared',
               'examples/box3d_common', 'examples/kit_box3d/scripts')
    folders += tuple('tests/box3d_bounds/' + suite for suite in suites)
    if suites == ('native',): folders = ('box3d/native', 'tests/box3d_bounds/native')
    return {str(path.relative_to(ROOT)): sha(path)
            for folder in folders if (ROOT / folder).is_dir()
            for path in sorted((ROOT / folder).rglob('*'))
            if path.is_file() and path.suffix in {'.odin', '.c', '.h', '.py', '.json'}
            and '__pycache__' not in path.parts and not path.name.endswith('.gen.odin')}


def save(path, value):
    with path.open('x') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n'); stream.flush(); os.fsync(stream.fileno())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', choices=('native', 'common', 'kit', 'replay', 'all'), default='all')
    parser.add_argument('--odin', type=Path, required=True)
    parser.add_argument('--cc', type=Path, help='explicit target C compiler for the Native suite')
    parser.add_argument('--native-library', type=Path, required=True)
    parser.add_argument('--native-sha256', required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    for path in (args.odin, args.native_library, args.out):
        if not path.is_absolute(): parser.error('tool, Native and output paths must be absolute')
    out = args.out.resolve()
    if out == ROOT or ROOT in out.parents: parser.error('output must be new and outside the repository')
    out.mkdir(parents=True, exist_ok=False)
    suites = ('native', 'common', 'kit', 'replay') if args.suite == 'all' else (args.suite,)
    if args.cc is not None and not args.cc.is_absolute(): parser.error('C compiler must be absolute')
    if args.execute and 'native' in suites and args.cc is None: parser.error('Native execution requires --cc')
    argv = {suite: [str(args.odin), 'test', str(HERE / suite),
             '-collection:godot=' + str(ROOT), '-define:BOX3D_LIBRARY=' + str(args.native_library),
             '-define:ODIN_TEST_THREADS=1', '-out:' + str(out / ('bounds-' + suite))]
             + ['-custom-attribute:' + item for item in ATTRIBUTES] for suite in suites if suite != 'native'}
    if 'native' in suites:
        argv['native-build'] = [str(args.cc) if args.cc else '<absolute target C compiler>',
            '-std=c11', '-UNDEBUG', '-fno-fast-math', '-ffp-contract=off',
            '-I' + str(ROOT / 'box3d/native'), str(HERE / 'native/profile_edges.c'),
            str(args.native_library), '-lm', '-lpthread', '-o', str(out / 'bounds-native')]
        argv['native'] = [str(out / 'bounds-native')]
    plan = {'result': 'STAGED_ONLY', 'jobs_started': 0, 'argv': argv,
            'native_library': str(args.native_library), 'native_sha256': args.native_sha256}
    save(out / 'plan.json', plan)
    if not args.execute:
        print(json.dumps({'result': 'STAGED_ONLY', 'plan': str(out / 'plan.json')})); return 0
    before = sources(suites)
    helper_before = sha(Path(__file__))
    native_before, compiler_before = sha(args.native_library), sha(args.odin)
    cc_before = sha(args.cc) if args.cc else None
    if native_before != args.native_sha256: raise ValueError('actual Native SHA differs')
    manifest = args.native_library.with_name('build-manifest.json')
    report = {'result': 'FAIL', 'steps': [], 'source_before': before,
              'native_library': str(args.native_library), 'native_sha256': native_before,
              'compiler': str(args.odin), 'compiler_sha256': compiler_before,
              'c_compiler': str(args.cc) if args.cc else None, 'c_compiler_sha256': cc_before,
              'native_manifest': str(manifest) if manifest.is_file() else None,
              'native_manifest_sha256': sha(manifest) if manifest.is_file() else None,
              'scope': 'public standalone Native/Kit/Replay bounds; static/nil-owner fixtures, not SDK Host quota or hardware/performance proof'}
    try:
        stages = [stage for suite in suites for stage in (('native-build', 'native') if suite == 'native' else (suite,))]
        binaries = {}
        for suite in stages:
            if suite == 'native-build':
                if not (HERE / 'native/profile_edges.c').is_file(): raise ValueError('missing actual Native C tests')
            elif suite != 'native' and not list((HERE / suite).glob('*_test.odin')):
                raise ValueError('missing actual test suite ' + suite)
            if suite == 'native': binaries['native_before_execution'] = sha(out / 'bounds-native')
            log = out / (suite + '.log')
            with log.open('xb') as stream:
                process = subprocess.Popen(argv[suite], cwd=out, stdout=stream,
                                           stderr=subprocess.STDOUT, start_new_session=True)
                try: code = process.wait(timeout=180)
                except BaseException:
                    try: os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError: pass
                    process.wait(timeout=10); raise
                finally: stream.flush(); os.fsync(stream.fileno())
            report['steps'].append({'suite': suite, 'argv': argv[suite], 'pid': process.pid,
                                    'actual_exit': code, 'log': str(log), 'log_sha256': sha(log)})
            if code != 0: raise RuntimeError('actual bounds suite failed: ' + suite)
            if suite == 'native':
                binaries['native_after_execution'] = sha(out / 'bounds-native')
                if binaries['native_before_execution'] != binaries['native_after_execution']:
                    raise ValueError('Native test executable changed during execution')
        report['test_binary_hashes'] = binaries
        report['result'] = 'PASS'
    except Exception as exc: report['error'] = repr(exc)
    finally:
        report['source_fence_unchanged'] = before == sources(suites) and helper_before == sha(Path(__file__))
        report['native_fence_unchanged'] = sha(args.native_library) == native_before
        report['compiler_fence_unchanged'] = sha(args.odin) == compiler_before
        report['c_compiler_fence_unchanged'] = args.cc is None or sha(args.cc) == cc_before
        if not all(report[key] for key in ('source_fence_unchanged', 'native_fence_unchanged', 'compiler_fence_unchanged', 'c_compiler_fence_unchanged')):
            report['result'] = 'FAIL'
        save(out / 'report.json', report)
    print(json.dumps({'result': report['result'], 'report': str(out / 'report.json'), 'error': report.get('error')}))
    return 0 if report['result'] == 'PASS' else 1


if __name__ == '__main__': raise SystemExit(main())
