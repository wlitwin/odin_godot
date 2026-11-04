#!/usr/bin/env python3
"""Ordinary SDK/import/export path for the one-domain Web backend fixture."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess

ROOT = Path(__file__).resolve().parents[3]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def command(output, name, argv, environment, report, timeout=600):
    log = output / (name + '.log')
    with log.open('xb') as stream:
        child = subprocess.Popen(argv, env=environment, cwd=output,
            stdout=stream, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, start_new_session=True)
        try:
            code = child.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait()
            code = 124
    row = dict(name=name, argv=argv, actual_pid=child.pid, actual_exit=code,
               log=str(log), log_sha256=sha(log))
    report['steps'].append(row)
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    text = log.read_text(errors='replace')
    if code or any(token in text for token in ['SCRIPT ERROR', 'ERROR:', 'ODIN_SCRIPT_PANIC',
            'instances were leaked', 'resources still in use', 'SHUTDOWN_NOT_EMPTY']):
        raise RuntimeError(name + ' failed; original log retained')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--native-library', type=Path, required=True)
    parser.add_argument('--web-archive', type=Path, required=True)
    parser.add_argument('--odin', required=True)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--emcc', required=True)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    output = args.out.resolve()
    if output.is_relative_to(ROOT):
        parser.error('choose a NEW output outside the repository')
    output.mkdir(parents=True, exist_ok=False)
    if not args.execute:
        (output / 'plan.json').write_text(json.dumps(dict(result='STAGED_ONLY',
            steps=['ordinary-native-SDK', 'ordinary-import', 'ordinary-Web-export'], runtime_jobs_started=0), indent=2) + '\n')
        return 0
    source = Path(__file__).with_name('project')
    project = output / 'project'
    shutil.copytree(source, project)
    shutil.copytree(ROOT / 'addons/box3d_authoring', project / 'addons/box3d_authoring',
                    ignore=shutil.ignore_patterns('__pycache__', '.godot', '*.uid'))
    env = os.environ.copy()
    env.update(ROOT=str(ROOT), ODIN_GODOT_ROOT=str(ROOT), ODIN=args.odin,
               GODOT=args.godot, EMCC=args.emcc, BOX3D_NATIVE_LIBRARY=str(args.native_library.resolve()),
               BOX3D_WEB_ARCHIVE=str(args.web_archive.resolve()))
    env.pop('SCRIPT_BUILD_FLAGS', None)
    report = dict(result='FAIL', steps=[], project=str(project), native_library_sha256=sha(args.native_library),
                  web_archive_sha256=sha(args.web_archive), source_fixture={str(p.relative_to(source)):sha(p)
                    for p in source.rglob('*') if p.is_file()},
                  scope='Ordinary SDK/import/export only; actual browser driver acceptance is separate')
    try:
        command(output, 'native-sdk', ['bash', str(ROOT / 'build/build_scripts.sh'), str(project)], env, report)
        command(output, 'prepare-import', ['python3', str(ROOT / 'build/box3d_profile.py'), '--prepare-import', str(project)], env, report)
        command(output, 'import', [args.godot, '--headless', '--editor', '--path', str(project), '--quit-after', '120'], env, report, 180)
        export = output / 'export'
        export.mkdir()
        command(output, 'export', [args.godot, '--headless', '--path', str(project), '--export-release', 'Web', str(export / 'index.html')], env, report)
        report['export_files'] = {str(p.relative_to(export)):sha(p) for p in export.rglob('*') if p.is_file()}
        if not (export / 'index.html').is_file() or not any(p.suffix == '.wasm' for p in export.rglob('*')):
            raise RuntimeError('normal export did not publish actual Web artifacts')
        report['result'] = 'EXPORTED_BROWSER_PENDING'
    except Exception as exc:
        report['error'] = repr(exc)
    finally:
        report['fixture_source_unchanged'] = report['source_fixture'] == {
            str(p.relative_to(source)):sha(p) for p in source.rglob('*') if p.is_file()}
        report['native_library_unchanged'] = report['native_library_sha256'] == sha(args.native_library)
        report['web_archive_unchanged'] = report['web_archive_sha256'] == sha(args.web_archive)
        if not all(report[k] for k in ['fixture_source_unchanged', 'native_library_unchanged', 'web_archive_unchanged']):
            report['result'] = 'FAIL'
        (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(dict(result=report['result'], report=str(output / 'report.json'), error=report.get('error'))))
    return 0 if report['result'] == 'EXPORTED_BROWSER_PENDING' else 1


if __name__ == '__main__':
    raise SystemExit(main())
