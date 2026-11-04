#!/usr/bin/env python3
"""Minimal real Kit provider/World2 compatibility over the shared Web backend."""
import argparse
from functools import partial
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import threading

ROOT = Path(__file__).resolve().parents[3]


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def main(source=None, marker='KIT_WEB_PASS', mode='kit', scope='Kit local provider/World2/complete codec/source-free ownership; no Kit browser network/game claim'):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--native-library', type=Path, required=True)
    parser.add_argument('--web-archive', type=Path, required=True)
    parser.add_argument('--odin', required=True)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--emcc', required=True)
    parser.add_argument('--web-template-record', type=Path,
                        help='Explicit verified derived Godot Web template')
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    output = args.out.resolve()
    if output.is_relative_to(ROOT):
        parser.error('new output outside the repository required')
    output.mkdir(parents=True, exist_ok=False)
    if not args.execute:
        (output / 'plan.json').write_text(json.dumps(dict(result='STAGED_ONLY', runtime_jobs_started=0)) + '\n')
        return 0
    shared = module('kit_export_shared', ROOT / 'tests/box3d_web/integration/run.py')
    browser = module('kit_browser_shared', ROOT / 'tests/box3d_web/integration/browser.py')
    source = source or Path(__file__).with_name('project')
    project = output / 'project'
    shutil.copytree(source, project)
    env = os.environ.copy()
    env.update(ROOT=str(ROOT), ODIN_GODOT_ROOT=str(ROOT), ODIN=args.odin, GODOT=args.godot,
               EMCC=args.emcc, BOX3D_NATIVE_LIBRARY=str(args.native_library.resolve()),
               BOX3D_WEB_ARCHIVE=str(args.web_archive.resolve()))
    env.pop('SCRIPT_BUILD_FLAGS', None)
    before = {str(p.relative_to(source)): shared.sha(p) for p in source.rglob('*') if p.is_file()}
    report = dict(result='FAIL', steps=[], source_fixture=before, scope=scope)
    try:
        shared.command(output, 'sdk', ['bash', str(ROOT / 'build/build_scripts.sh'), str(project)], env, report)
        if args.web_template_record:
            selection = output / 'template-selection.json'
            shared.command(output, 'select-web-template', ['python3', '-B',
                str(ROOT / 'build/web_rtc_template.py'), 'select',
                '--record', str(args.web_template_record.resolve(strict=True)),
                '--project', str(project), '--out', str(selection)], env, report)
            report['custom_web_template'] = dict(
                record_sha256=shared.sha(args.web_template_record),
                selection=json.loads(selection.read_text()))
        shared.command(output, 'prepare-import', ['python3', str(ROOT / 'build/box3d_profile.py'), '--prepare-import', str(project)], env, report)
        shared.command(output, 'import', [args.godot, '--headless', '--editor', '--path', str(project), '--quit-after', '120'], env, report)
        export = output / 'export'
        export.mkdir()
        shared.command(output, 'export', [args.godot, '--headless', '--path', str(project), '--export-release', 'Web', str(export / 'index.html')], env, report)
        files = {str(p.relative_to(export)): shared.sha(p) for p in export.rglob('*') if p.is_file()}
        server = browser.ThreadingHTTPServer(('127.0.0.1', 0), partial(browser.Handler, directory=str(export)))
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            shared.command(output, 'browser', ['node', str(Path(__file__).with_name('drive.mjs')),
                           f'http://127.0.0.1:{server.server_port}/index.html', str(output), marker, mode], env, report, 150)
        finally:
            server.shutdown()
            server.server_close()
        report['export_unchanged'] = files == {str(p.relative_to(export)): shared.sha(p) for p in export.rglob('*') if p.is_file()}
        report['browser'] = json.loads((output / 'browser-report.json').read_text())
        if report['browser']['result'] != 'PASS' or not report['export_unchanged']:
            raise RuntimeError('actual browser or immutable export check failed')
        report.update(result='PASS', export_files=files)
    except Exception as error:
        report['error'] = repr(error)
    finally:
        report['source_fence'] = before == {str(p.relative_to(source)): shared.sha(p) for p in source.rglob('*') if p.is_file()}
        if not report['source_fence']:
            report['result'] = 'FAIL'
        (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(dict(result=report['result'], report=str(output / 'report.json'), error=report.get('error'))))
    return 0 if report['result'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
