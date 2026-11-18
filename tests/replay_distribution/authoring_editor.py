from pathlib import Path
import os
import re
import shutil
import subprocess
import sys
import time

root, project, work = map(lambda s: Path(s).resolve(), sys.argv[1:4])
work.mkdir(parents=True)
addon = project / 'addons/authoring_acceptance'
addon.mkdir(parents=True, exist_ok=True)
shutil.copy2(root / 'tests/replay_distribution/authoring_editor.gd', addon / 'plugin.gd')
(addon / 'plugin.cfg').write_text('[plugin]\nname="Starter authoring acceptance"\nscript="plugin.gd"\n')
settings = project / 'project.godot'
original = settings.read_text()
needle = '"res://addons/replay_authoring/plugin.cfg")'
assert needle in original
settings.write_text(original.replace(needle, '"res://addons/replay_authoring/plugin.cfg", "res://addons/authoring_acceptance/plugin.cfg")'))
env = {**os.environ, 'STARTER_AUTHORING_EDITOR': '1'}
env.pop('ODIN_SCRIPTS_DLL', None)
log = work / 'editor.log'
try:
    with log.open('w') as output:
        process = subprocess.Popen([os.environ['GODOT'], '--headless', '--editor', '--path', str(project)], env=env, stdout=output, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 240
            while process.poll() is None:
                if re.search(r'SCRIPT ERROR|\nERROR:', log.read_text(errors='replace')):
                    raise RuntimeError('Editor assertion/error: ' + str(log))
                if time.monotonic() > deadline:
                    raise TimeoutError('Starter authoring editor deadline: ' + str(log))
                time.sleep(.1)
            assert process.returncode == 0, log
        finally:
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
    text = log.read_text()
    assert 'REPLAY_STARTER_EDITOR_OK' in text and not re.search(r'SCRIPT ERROR|\nERROR:|leaked at exit|resources still in use', text), text[-6000:]
finally:
    settings.write_text(original)
print('REPLAY_STARTER_EDITOR_OK')
