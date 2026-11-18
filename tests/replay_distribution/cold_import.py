"""Qualify one checked cold import of installed native-free Replay and Slopball."""
from pathlib import Path
import argparse
import json
import os
import shutil
import stat
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--sdk', type=Path, required=True, help='odin_godot addon directory')
parser.add_argument('--out', type=Path, required=True)
args = parser.parse_args()
out = args.out.resolve()
out.mkdir(parents=True, exist_ok=False)
rows = []
for name in ['replay', 'slopball']:
    work = out / name
    project = work / 'project'
    source = args.sdk / 'template/replay' if name == 'replay' else root / 'examples/slopball'
    shutil.copytree(source, project, ignore=shutil.ignore_patterns('.godot', 'bin', 'out', '*.gen.odin', '*.gdextension', '*.import', '*.uid'))
    for path in [project, *project.rglob('*')]:
        if not path.is_symlink(): path.chmod(path.stat().st_mode | stat.S_IWUSR)
    addon = project / 'addons/odin_godot'
    shutil.copytree(args.sdk, addon)
    for path in [project, *project.rglob('*')]:
        if not path.is_symlink(): path.chmod(path.stat().st_mode | stat.S_IWUSR)
    env = {key: value for key, value in os.environ.items()
           if key not in ['ODIN_GODOT_ROOT', 'ODIN_SCRIPTS_DLL'] and not key.startswith('BOX3D_')}
    env.update(ODIN_GODOT_ROOT=str(addon), SKIP_CORE='1')
    with (work / 'build.log').open('w') as log:
        subprocess.run(['bash', str(addon / 'build/build_scripts.sh'), str(project)], env=env,
                       stdout=log, stderr=subprocess.STDOUT, timeout=180, check=True)
    entries = (project / '.godot/extension_list.cfg').read_text().splitlines()
    assert entries == ['res://addons/odin_godot/odin_godot.gdextension'], entries
    # Exercise the explicit cold-import helper independently of build preparation.
    shutil.rmtree(project / '.godot')
    with (work / 'import-command.log').open('w') as log:
        subprocess.run(['bash', str(root / 'build/import_project.sh'), str(project), str(work / 'import.log')],
                       env=env, stdout=log, stderr=subprocess.STDOUT, timeout=60, check=True)
    subprocess.run([sys.executable, str(root / 'tests/replay_comparison/wait_builds.py'),
                    str(project), str(work / 'wait.json')], check=True, timeout=180)
    rows.append({'project': name, 'build_prepared_native_free_import': True, 'cold_import_attempts': 1,
                 'cold_import_exit': 0, 'log': str(work / 'import.log')})
    (out / 'result.json').write_text(json.dumps(rows, indent=2) + '\n')
    print('COLD_IMPORT_OK', name, flush=True)
