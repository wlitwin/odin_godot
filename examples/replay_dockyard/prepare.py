#!/usr/bin/env python3
"""Stage Dockyard Duo with the standard SDK/addon; optionally perform its normal build."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_map():
    result = {}
    for folder in [SOURCE, ROOT / 'addons/box3d_authoring']:
        for path in folder.rglob('*'):
            if (path.is_file() and not any(n in path.parts for n in ['bin', '.godot', '__pycache__', 'out'])
                    and not path.name.endswith(('.gen.odin', '.uid'))):
                result[str(path.relative_to(ROOT))] = sha(path)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--native-library', type=Path, required=True)
    parser.add_argument('--native-sha256')
    parser.add_argument('--sqlite-library', type=Path, default=os.environ.get('REPLAY_SQLITE_LIBRARY'),
                        help='Explicit static SQLite archive for strict Native SDK dependency admission')
    parser.add_argument('--odin', default=os.environ.get('ODIN', 'odin'))
    parser.add_argument('--godot', default=os.environ.get('GODOT', ''))
    parser.add_argument('--build', action='store_true')
    args = parser.parse_args()
    output, native = args.out.resolve(), args.native_library.resolve(strict=True)
    if output.is_relative_to(ROOT):
        parser.error('choose a NEW output outside the repository')
    native_before = sha(native)
    sqlite = args.sqlite_library.resolve(strict=True) if args.sqlite_library else None
    if sqlite is not None and (sqlite.suffix != '.a' or any(c.isspace() for c in str(sqlite))):
        parser.error('SQLite input must be a static .a archive at a path without whitespace')
    sqlite_before = sha(sqlite) if sqlite else None
    if args.native_sha256 and native_before != args.native_sha256:
        parser.error('explicit Native library SHA differs')
    output.mkdir(parents=True, exist_ok=False)
    before = source_map()
    project = output / 'project'
    shutil.copytree(SOURCE, project, ignore=shutil.ignore_patterns('bin', '.godot', '__pycache__', 'out', '*.gen.odin', '*.uid'))
    addon = project / 'addons/box3d_authoring'
    shutil.copytree(ROOT / 'addons/box3d_authoring', addon)
    shutil.copytree(addon / 'tool_module', project / 'modules/box3d_authoring_tools')
    content = {str(p.relative_to(SOURCE / 'content')): sha(p)
               for p in (SOURCE / 'content').rglob('*') if p.is_file()}
    copied = {str(p.relative_to(project / 'content')): sha(p)
              for p in (project / 'content').rglob('*') if p.is_file()}
    env = os.environ.copy()
    env.update(ROOT=str(ROOT), ODIN_GODOT_ROOT=str(ROOT), ODIN=args.odin,
               BOX3D_NATIVE_LIBRARY=str(native), SCRIPT_BUILD_FLAGS='-o:speed')
    if sqlite:
        env['SCRIPT_BUILD_FLAGS'] += ' -define:REPLAY_SQLITE_LIBRARY=' + str(sqlite)
    if args.godot:
        env['GODOT'] = args.godot
    argv = ['bash', str(ROOT / 'build/build_scripts.sh'), str(project)]
    code, error = None, None
    if args.build:
        try:
            with (output / 'build.log').open('xb') as stream:
                code = subprocess.run(argv, cwd=ROOT, env=env, stdout=stream,
                                      stderr=subprocess.STDOUT, timeout=600).returncode
            if code:
                raise RuntimeError('ordinary SDK build failed')
        except Exception as exc:
            error = repr(exc)
    source_ok, native_ok = before == source_map(), native_before == sha(native)
    result = 'STAGED_ONLY' if not args.build else ('PASS' if code == 0 and error is None else 'FAIL')
    sqlite_ok = sqlite is None or sha(sqlite) == sqlite_before
    if not source_ok or not native_ok or not sqlite_ok or content != copied:
        result = 'FAIL'
    report = dict(result=result, error=error, framework='replay', project=str(project),
        build_requested=args.build, actual_build_exit=code, build_argv=argv,
        source_before=before, source_fence_unchanged=source_ok,
        native_library=str(native), native_sha256=native_before, native_fence_unchanged=native_ok,
        sqlite_library=str(sqlite) if sqlite else None, sqlite_sha256=sqlite_before, sqlite_fence_unchanged=sqlite_ok,
        copied_content_byteexact=content == copied, content_files_sha256=content,
        actual_binaries_sha256={str(p.relative_to(project)): sha(p)
            for p in (project / 'bin').glob('*') if p.is_file()},
        runtime_jobs_started=0, scope='Standard SDK build/staging; runtime acceptance separate')
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(dict(result=result, project=str(project), report=str(output / 'report.json'), error=error)))
    return 1 if result == 'FAIL' else 0


if __name__ == '__main__':
    raise SystemExit(main())
