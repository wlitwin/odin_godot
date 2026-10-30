"""Run both isolated games sequentially, retaining failures and exact build inputs."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time
import re
import shutil
import uuid

out = Path(sys.argv[1]).resolve()
ext = sys.argv[2]
label = sys.argv[3] if len(sys.argv) > 3 else 'run'
assert re.fullmatch(r'[a-z0-9-]+', label), 'invalid run label'
root = Path(__file__).resolve().parents[2]
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
for name, digest in json.loads((out / 'prepared.json').read_text()).items():
    assert sha(out / name) == digest, name
for name, digest in json.loads((out / 'framework.json').read_text()).items():
    assert sha(root / name) == digest, name
manifest = {'odin': subprocess.check_output(['odin', 'version'], text=True).strip(),
            'godot': subprocess.check_output([os.environ['GODOT'], '--version'], text=True).strip(),
            'flags': ['-debug', '-o:speed'], 'binaries': {}}
for impl in ('kit', 'replay'):
    for p in (out / impl / 'project/bin').glob('*.' + ext):
        manifest['binaries'][str(p.relative_to(out))] = sha(p)
(out / 'build-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
exits = {}
token = 'solo-' + uuid.uuid4().hex
order = ('replay', 'kit') if os.environ.get('REPLAY_SOLO_REVERSE') == '1' else ('kit', 'replay')
(out / (label + '-run-plan.json')).write_text(json.dumps({'order': order, 'fresh_profile_token': token,'finale_mode':os.environ.get('REPLAY_SOLO_FINALE','navigate'),'forced_obstruction':os.environ.get('REPLAY_SOLO_OBSTRUCTED')=='1'}) + '\n')
for impl in order:
    project = out / impl / 'project'
    folder = out / impl / label
    folder.mkdir(exist_ok=False)
    # GDScript-only driver revisions need no native rebuild. Keep the original
    # prepared inputs immutable, and retain the exact executed revision per run.
    script = 'solo_compare_' + label + '.gd'
    navigation='solo_navigation_'+label+'.gd'
    shutil.copy2(root/'tests/replay_solo_comparison/navigation.gd',project/navigation)
    shutil.copy2(project/navigation,folder/'navigation.gd')
    text=(root/'tests/replay_solo_comparison/driver.gd').read_text().replace('res://solo_navigation.gd','res://'+navigation)
    (project/script).write_text(text)
    shutil.copy2(project / script, folder / 'driver.gd')
    (folder / 'driver-sha256.json').write_text(json.dumps({'script': script, 'sha256': sha(project / script),'navigation':navigation,'navigation_sha256':sha(project/navigation)}) + '\n')
    env = os.environ.copy()
    env.update(COMPARE_IMPL=impl, COMPARE_DIR=str(folder), ODIN_SCRIPTS_DLL=str(project / ('bin/libodinscripts.' + ext)),
               SY_ROLE='', SY_NAME='Solo', SY_TOKEN=token, SY_FRESH='1', SY_SEED='1337', SY_HZ='60',
               SY_MOBS='4', SY_WAVES='3', SY_BARRELS='0', SY_MAG='255', SY_NOJAM='1',
               SY_LATENCY='0', SY_JITTER='0', SY_LOSS='0', SY_BURST='0', SY_BANDWIDTH='0',
               SY_MODS_DIR=str(out / 'no-mods'), SY_SPRAY=str(out / 'no-spray.png'),
               RSY_ROLE='solo', RSY_NAME='Solo', RSY_TOKEN=token, RSY_PERSIST='0', RSY_DEV='1',
               RSY_SEED='1337', RSY_RUN='1', RSY_WAVE_BASE='4', RSY_WAVE_GROWTH='4', RSY_WAVES='3', RSY_REST='300',
               RSY_BARRELS='0', RSY_MOBS='0', RSY_REQUIRE_STOCK='0', RSY_RESUME='0', RSY_AUDIO='0',
               RSY_LATENCY='0', RSY_JITTER='0', RSY_LOSS='0', RSY_DUPLICATE='0',
               RSY_MODS_DIR=str(out / 'no-mods'), RSY_SPRAY=str(out / 'no-spray.png'))
    config = {k: v for k, v in env.items() if k.startswith(('SY_', 'RSY_', 'COMPARE_', 'REPLAY_SOLO_'))}
    (folder / 'environment.json').write_text(json.dumps(config, indent=2) + '\n')
    with (folder / 'game.log').open('w') as log:
        child = subprocess.Popen([env['GODOT'], '--headless', '--max-fps', '60', '--path', str(project), '--script', script], env=env, stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 240
            while child.poll() is None:
                if time.monotonic() >= deadline or re.search(r'SCRIPT ERROR|ERROR:', (folder / 'game.log').read_text()):
                    raise subprocess.TimeoutExpired(child.args, 240)
                time.sleep(.1)
            code = child.returncode
        except subprocess.TimeoutExpired:
            child.terminate()
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                child.kill(); child.wait()
            code = 'timeout-or-runtime-error'
        finally:
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    child.kill(); child.wait()
        exits[impl] = code
    print(impl, code, flush=True)
(out / (label + '-exit-codes.json')).write_text(json.dumps(exits, indent=2) + '\n')
if any(code != 0 for code in exits.values()):
    sys.exit(1)
