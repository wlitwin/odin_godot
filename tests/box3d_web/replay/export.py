#!/usr/bin/env python3
"""Normal SDK/import/Web export of the current Dockyard game."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('boxweb_integration', ROOT / 'tests/box3d_web/integration/run.py')
shared = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shared)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--native-library', type=Path, required=True)
    parser.add_argument('--web-archive', type=Path, required=True)
    parser.add_argument('--odin', required=True)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--emcc', required=True)
    parser.add_argument('--web-template-record', type=Path,
                        help='Explicit verified derived Godot template; selected before ordinary export')
    args = parser.parse_args()
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    env.update(ODIN_GODOT_ROOT=str(ROOT), ODIN=args.odin, GODOT=args.godot, EMCC=args.emcc,
               BOX3D_NATIVE_LIBRARY=str(args.native_library.resolve()),
               BOX3D_WEB_ARCHIVE=str(args.web_archive.resolve()), BOX3D_WEB_DEBUG_NAMES='1')
    env.pop('SCRIPT_BUILD_FLAGS', None)
    report = dict(result='FAIL', steps=[], framework='replay',
                  scope='Ordinary current Dockyard SDK/import/export; runtime pair acceptance separate')
    try:
        shared.command(output, 'sdk', ['python3', '-B', str(ROOT / 'examples/replay_dockyard/prepare.py'),
            '--out', str(output / 'sdk'), '--native-library', str(args.native_library.resolve()),
            '--odin', args.odin, '--godot', args.godot, '--build'], env, report)
        project = output / 'sdk/project'
        if args.web_template_record:
            selection = output / 'template-selection.json'
            shared.command(output, 'select-web-template', ['python3', '-B',
                str(ROOT / 'build/web_rtc_template.py'), 'select',
                '--record', str(args.web_template_record.resolve(strict=True)),
                '--project', str(project), '--out', str(selection)], env, report)
            report['custom_web_template'] = dict(
                record=str(args.web_template_record.resolve()),
                record_sha256=shared.sha(args.web_template_record),
                selection=json.loads(selection.read_text()))
        shared.command(output, 'prepare-import', ['python3', str(ROOT / 'build/box3d_profile.py'),
                        '--prepare-import', str(project)], env, report)
        shared.command(output, 'import', [args.godot, '--headless', '--editor', '--path', str(project),
                        '--quit-after', '120'], env, report, 180)
        export = output / 'export'
        export.mkdir()
        shared.command(output, 'export', [args.godot, '--headless', '--path', str(project),
                        '--export-release', 'Web', str(export / 'index.html')], env, report)
        report.update(result='EXPORTED_BROWSER_PENDING', project=str(project),
                      export_files={str(p.relative_to(export)): shared.sha(p)
                                    for p in export.rglob('*') if p.is_file()},
                      native_sha256=shared.sha(args.native_library), web_archive_sha256=shared.sha(args.web_archive))
    except Exception as exc:
        report['error'] = repr(exc)
    finally:
        (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(dict(result=report['result'], report=str(output / 'report.json'), error=report.get('error'))))
    return 0 if report['result'] == 'EXPORTED_BROWSER_PENDING' else 1


if __name__ == '__main__':
    raise SystemExit(main())
