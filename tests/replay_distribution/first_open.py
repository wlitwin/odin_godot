"""Open a copied installed starter before compiling, then reopen with GUI PATH."""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import sys
import time

root, project, work = map(lambda s: Path(s).resolve(), sys.argv[1:4])
work.mkdir(parents=True, exist_ok=False)
assert not (project / 'bin/libodinscripts.dylib').exists()
assert not (project / '.godot').exists()
addon = project / 'addons/odin_godot'
for name in ['plugin.cfg', 'plugin.gd', 'preview_controls.gd', 'saved_data.gd']:
    assert (project / 'addons/replay_authoring' / name).read_bytes() == (addon / 'replay/editor' / name).read_bytes()
probe = project / 'addons/first_open_acceptance'
probe.mkdir()
shutil.copy2(root / 'tests/replay_distribution/first_open.gd', probe / 'plugin.gd')
(probe / 'plugin.cfg').write_text('[plugin]\nname="First-open acceptance"\nscript="plugin.gd"\n')
settings = project / 'project.godot'
original = settings.read_text()
needle = '"res://addons/replay_authoring/plugin.cfg")'
assert needle in original
settings.write_text(original.replace(needle, '"res://addons/replay_authoring/plugin.cfg", "res://addons/first_open_acceptance/plugin.cfg")'))
engine = work / 'engine'
engine.mkdir()
original_engine = Path(os.environ['GODOT']).resolve()
if original_engine.parent.name == 'MacOS' and original_engine.parent.parent.name == 'Contents':
    subprocess.run(['/bin/cp', '-c', '-R', str(original_engine.parents[2]), str(engine / 'Godot.app')], check=True)
    godot = engine / 'Godot.app/Contents/MacOS' / original_engine.name
else:
    godot = engine / original_engine.name
    shutil.copy2(original_engine, godot)
(engine / '_sc_').touch()
clean = {key: value for key, value in os.environ.items()
         if key not in ['ODIN', 'ODIN_GODOT_ROOT', 'ODIN_SCRIPTS_DLL', 'EMCC', 'DEVELOPER_DIR', 'SDKROOT']
         and not key.startswith('BOX3D_')}
clean['PATH'] = '/usr/bin:/bin:/usr/sbin:/sbin'
log_path = work / 'first-open.log'
process = None
try:
    with log_path.open('w') as log:
        process = subprocess.Popen([str(godot), '--headless', '--editor', '--path', str(project)],
                                   env=clean, stdout=log, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 45
        while not (project / '.godot/first-open-ready').exists():
            assert process.poll() is None, log_path
            assert time.monotonic() < deadline, 'first-open marker deadline'
            assert not re.search(r'SCRIPT ERROR|\nERROR:', log_path.read_text()), log_path
            time.sleep(.1)
        build_env = {**os.environ, 'ODIN_GODOT_ROOT': str(addon), 'SKIP_CORE': '1'}
        build_env.pop('ODIN_SCRIPTS_DLL', None)
        with (work / 'first-build.log').open('w') as output:
            subprocess.run(['bash', str(addon / 'build/build_scripts.sh'), str(project)], env=build_env,
                           stdout=output, stderr=subprocess.STDOUT, check=True, timeout=180)
        deadline = time.monotonic() + 90
        while process.poll() is None:
            assert not re.search(r'SCRIPT ERROR|\nERROR:', log_path.read_text()), log_path
            assert time.monotonic() < deadline, 'first-build setup recovery deadline'
            time.sleep(.1)
        assert process.returncode == 0, log_path
    text = log_path.read_text()
    assert 'REPLAY_FIRST_OPEN_OK' in text, text[-5000:]
    assert not re.search(r'SCRIPT ERROR|\nERROR:|failed to load scripts dll|failed to load\. No directory|leaked at exit|resources still in use', text), text[-5000:]
finally:
    if process is not None and process.poll() is None:
        process.terminate()
        try: process.wait(timeout=5)
        except subprocess.TimeoutExpired: process.kill(); process.wait()
    settings.write_text(original)
    shutil.rmtree(probe)

# The next editor has neither compiler/backend env nor an SDK-root override.
# Native authoring validation must resolve remembered local tool paths.
reopen_env = {**clean, 'GODOT': str(godot)}
subprocess.run([sys.executable, str(root / 'tests/replay_distribution/authoring_editor.py'),
                str(root), str(project), str(work / 'reopen')], env=reopen_env, check=True, timeout=270)
(work / 'result.json').write_text(json.dumps({'first_open_before_build': True, 'dock_available': True,
    'first_build_detected_live': True, 'reopened_with_minimal_path': True,
    'validation_preview_recovery': True, 'godot': str(godot)}, indent=2) + '\n')
print('REPLAY_FIRST_OPEN_OK')
