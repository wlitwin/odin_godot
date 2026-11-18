"""Exercise the actual packaged SDK's Box3D setup and ordinary editor builds."""
from pathlib import Path
import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--sdk', type=Path, required=True, help='Nix output containing addons/')
parser.add_argument('--out', type=Path)
args = parser.parse_args()
work = (args.out or Path(tempfile.mkdtemp(prefix='odin-box3d-setup-'))).resolve()
if args.out:
    work.mkdir(parents=True, exist_ok=False)
project = work / 'project'
shutil.copytree(Path(__file__).with_name('project'), project)
shutil.copytree(args.sdk / 'addons', project / 'addons', dirs_exist_ok=True)
for path in project.rglob('*'):
    path.chmod(path.stat().st_mode | 0o200)
engine = work / 'engine'
engine.mkdir()
original = Path(os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot')).resolve()
if original.parent.name == 'MacOS' and original.parent.parent.name == 'Contents':
    subprocess.run(['/bin/cp', '-c', '-R', str(original.parents[2]), str(engine / 'Godot.app')], check=True)
    godot = engine / 'Godot.app/Contents/MacOS' / original.name
else:
    godot = engine / original.name
    shutil.copy2(original, godot)
(engine / '_sc_').touch()
env = {key: value for key, value in os.environ.items() if not key.startswith('BOX3D_') and key not in ('ODIN_GODOT_ROOT', 'ODIN_SCRIPTS_DLL')}
env['GODOT'] = str(godot)
# The ordinary SDK still enforces domain admission. Pure authoring must never
# link the absent archive, proving it no longer imports native registration.
env['SCRIPT_BUILD_FLAGS'] = '-define:BOX3D_LIBRARY=/nonexistent/box3d-editor-native.a'
rows = []
print('Box3D setup evidence:', work, flush=True)
for name, check, marker in [('import', '0', None), ('editor', '1', 'BOX3D_SETUP_EDITOR_OK')]:
    log = work / (name + '.log')
    with log.open('w') as stream:
        result = subprocess.run([str(godot), '--headless', '--editor', '--path', str(project), '--quit-after', '120' if name == 'import' else '20000'], cwd=work, env=dict(env, BOX3D_SETUP_CHECK=check), stdout=stream, stderr=subprocess.STDOUT, timeout=420)
    text = log.read_text(errors='replace')
    negative = re.findall(r"BOX3D_EXPECT_FAILURE_BEGIN [01]\n(.*?)BOX3D_EXPECT_FAILURE_END [01]", text, re.S)
    checked = re.sub(r"BOX3D_EXPECT_FAILURE_BEGIN [01]\n.*?BOX3D_EXPECT_FAILURE_END [01]", lambda match: re.sub(r"^ERROR: odin_godot: scripts build FAILED — your change is NOT live \(compiler errors above\).$", "EXPECTED_BUILD_FAILURE", match[0], flags=re.M), text, flags=re.S)
    expected_failures = name != 'editor' or (len(negative) == 2 and all('scripts build FAILED' in block and 'no Odin scripts found' in block for block in negative))
    admission = re.findall(r"BOX3D_EXPECT_ADMISSION_BEGIN\n(.*?)BOX3D_EXPECT_ADMISSION_END", text, re.S)
    if name == 'editor':
        expected_failures = expected_failures and len(admission) == 1 and 'module global-class collision' in admission[0] and 'your change is live' not in admission[0]
    checked = re.sub(r"BOX3D_EXPECT_ADMISSION_BEGIN\n.*?BOX3D_EXPECT_ADMISSION_END", lambda match: re.sub(r"^ERROR: odin_godot: (compiled scripts could not be loaded\..*|reload rejected — explicit //gd:class 'AuthoringTools'.*collides with.*)$", "EXPECTED_ADMISSION_FAILURE", match[0], flags=re.M), checked, flags=re.S)
    unavailable = re.findall(r"BOX3D_EXPECT_UNAVAILABLE_BEGIN\n(.*?)BOX3D_EXPECT_UNAVAILABLE_END", text, re.S)
    if name == 'editor':
        expected_failures = expected_failures and len(unavailable) == 1 and 'build the authoring tools' in unavailable[0] and 'Error importing' in unavailable[0]
    checked = re.sub(r"BOX3D_EXPECT_UNAVAILABLE_BEGIN\n.*?BOX3D_EXPECT_UNAVAILABLE_END", lambda match: re.sub(r"^ERROR: Error importing 'res://setup-world\.b3authoring'\.$", "EXPECTED_UNAVAILABLE_IMPORT", match[0], flags=re.M), checked, flags=re.S)
    passed = expected_failures and result.returncode == 0 and (marker is None or marker in text) and not any(value in checked for value in ('SCRIPT ERROR', '\nERROR:', 'leaked at exit', 'resources still in use', 'ODIN_SCRIPT_PANIC'))
    rows.append(dict(step=name, exit=result.returncode, passed=passed, log=str(log)))
    (work / 'report.json').write_text(json.dumps(rows, indent=2) + '\n')
    print(name, 'PASS' if passed else 'FAIL', flush=True)
    if not passed:
        print(text[-10000:])
        raise SystemExit(1)
print('BOX3D_SETUP_OK', work)
