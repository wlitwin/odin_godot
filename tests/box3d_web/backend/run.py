#!/usr/bin/env python3
"""Execute unchanged backend C guarantees as real wasm32 programs under Node."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'build'))
from build_box3d_web import build, sha, source_inputs

CASES = [
    ('api', 'box3d/native/api_smoke.c'),
    ('domain', 'tests/box3d_modules/native/domain_ledger_test.c'),
    ('upgrade', 'tests/box3d_upgrade/state_fields.c'),
    ('recovery', 'tests/box3d_recovery/native_test.c'),
    ('recovery_lifecycle', 'tests/box3d_recovery/lifecycle_test.c'),
    ('lifecycle', 'tests/box3d_native/lifecycle.c'),
    ('authoring', 'tests/box3d_authoring/native/authoring_test.c'),
    ('motion', 'tests/box3d_motion/native/motion_test.c'),
]


def run_step(output, name, argv, report):
    log = output / (name + '.log')
    with log.open('xb') as stream:
        child = subprocess.Popen([str(x) for x in argv], cwd=output,
                                 stdout=stream, stderr=subprocess.STDOUT,
                                 stdin=subprocess.DEVNULL, start_new_session=True)
        try:
            code = child.wait(timeout=180)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait()
            code = 124
    row = dict(name=name, argv=[str(x) for x in argv], pid=child.pid,
               actual_exit=code, log=str(log), log_sha256=sha(log))
    report['steps'].append(row)
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    if code:
        raise RuntimeError(name + ' failed; retained log: ' + str(log))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--variant', choices=['WebScalar', 'WebSIMD'], required=True)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=False)
    if not args.execute:
        (output / 'plan.json').write_text(json.dumps(dict(result='STAGED_ONLY',
            variant=args.variant, cases=CASES, runtime_jobs_started=0), indent=2) + '\n')
        return 0
    report = dict(result='FAIL', variant=args.variant, steps=[],
                  scope='Actual complete C backend Wasm/Node; no desktop DSO, Odin FFI, Godot or browser qualification')
    try:
        archive_dir = build(ROOT, args.cache.resolve(), args.variant, testing=True)
        manifest = archive_dir / 'build-manifest.json'
        info = json.loads(manifest.read_text())
        archive = archive_dir / 'libogb3.a'
        engine = args.cache.resolve() / ('box3d-' + info['dependency_manifest']['dependencies']['box3d']['commit'])
        before = source_inputs(ROOT, engine)
        tests_before = {path: sha(ROOT / path) for _, path in CASES}
        report.update(archive=str(archive), archive_sha256=sha(archive),
                      manifest=str(manifest), manifest_sha256=sha(manifest), test_sources=tests_before,
                      target_contract=info['target_contract'], actual_ctest_run_pass=False,
                      omitted_desktop_cases='shared-DSO and dlopen isolation require a different loader; one-domain AOT is tested at W2')
        flags = info['target_contract']['flags']
        include = ['-I' + str(ROOT / 'box3d/native'), '-I' + str(engine / 'include'), '-I' + str(engine / 'src')]
        runtime_flags = ['-sENVIRONMENT=node', '-sEXIT_RUNTIME=1', '-sASSERTIONS=2',
                         '-sALLOW_MEMORY_GROWTH=1', '-sMAXIMUM_MEMORY=536870912',
                         '-sSTACK_SIZE=2097152', '-sPTHREAD_POOL_SIZE=0', '-sNODERAWFS=1']
        for name, path in CASES:
            program = output / (name + '.cjs')
            run_step(output, name + '-compile', [info['compiler'], *flags, *include,
                str(ROOT / path), str(archive), *runtime_flags, '-o', str(program)], report)
            argv = ['node', str(program)]
            if name == 'recovery':
                argv += [str(output / 'recovery-fixture.bin')]
            run_step(output, name + '-runtime', argv, report)
        run_step(output, 'independent-reference', [sys.executable,
                 str(ROOT / 'tests/box3d_recovery/reference.py'),
                 str(output / 'recovery-fixture.bin')], report)
        report['source_fence_unchanged'] = before == source_inputs(ROOT, engine)
        report['test_fence_unchanged'] = tests_before == {path: sha(ROOT / path) for _, path in CASES}
        report['archive_fence_unchanged'] = report['archive_sha256'] == sha(archive)
        report['manifest_fence_unchanged'] = report['manifest_sha256'] == sha(manifest)
        if not all(report[key] for key in ['source_fence_unchanged', 'test_fence_unchanged',
                                           'archive_fence_unchanged', 'manifest_fence_unchanged']):
            raise RuntimeError('backend/test/artifact changed during runtime')
        report['result'] = 'PASS'
    except Exception as exc:
        report['error'] = repr(exc)
    finally:
        report['artifacts'] = {p.name: sha(p) for p in output.iterdir()
                               if p.is_file() and p.suffix in ['.wasm', '.cjs', '.bin']}
        (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(dict(result=report['result'], report=str(output / 'report.json'),
                          error=report.get('error'))))
    return 0 if report['result'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
