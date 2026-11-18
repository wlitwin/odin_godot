"""Run both Web memory modes through the real export plugin and Chrome."""
from pathlib import Path
import argparse
import json
import os
import shutil
import socket
import subprocess
import sys
import time
import urllib.request

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('out', type=Path)
parser.add_argument('--modes', nargs='+', choices=['single', 'threads'], default=['single', 'threads'])
parser.add_argument('--engine-exit', action='store_true', help='Strict engine shutdown diagnostic; currently unqualified on Godot4.7.1 single-threaded Web')
args = parser.parse_args()
work = args.out.resolve()
work.mkdir(parents=True, exist_ok=False)
project = work / 'project'
shutil.copytree(root / 'build/template/replay', project)
shutil.copy2(root / 'examples/replay_scrapyard/odin_godot.gdextension', project / 'odin_godot.gdextension')
for name in ['browser_probe.gd', 'browser_test.tscn']:
    shutil.copy2(root / 'tests/replay_distribution' / name, project / name)
if args.engine_exit:
    with (project / 'browser_test.tscn').open('a') as scene: scene.write('exit_after_success = true\n')
shutil.copy2(root / 'tests/replay_distribution/effect_probe.odin.txt', project / 'scripts/effect_probe.odin')
settings = project / 'project.godot'
settings.write_text(settings.read_text().replace('res://main.tscn', 'res://browser_test.tscn'))
presets = []
for index, mode in enumerate(['single', 'threads']):
    presets.append(f'''[preset.{index}]
name="Web {mode}"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="*.odin"
exclude_filter="out/**"
export_path="out/{mode}/index.html"
script_export_mode=2
[preset.{index}.options]
variant/extensions_support=true
variant/thread_support={str(mode == 'threads').lower()}
''')
(project / 'export_presets.cfg').write_text('\n'.join(presets))
env = {key: value for key, value in os.environ.items()
       if key not in ['ODIN_SCRIPTS_DLL', 'ODIN_WEB_THREADS'] and not key.startswith('BOX3D_')}
env['ODIN_GODOT_ROOT'] = str(root)
if args.engine_exit: env['REPLAY_PACKAGE_EXPECT_EXIT'] = '1'
else: env.pop('REPLAY_PACKAGE_EXPECT_EXIT', None)
def run(name, command, timeout=240):
    with (work / (name + '.log')).open('w') as log:
        subprocess.run([str(x) for x in command], env=env, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=timeout)
    return (work / (name + '.log')).read_text()
run('build', ['bash', root / 'build/build_scripts.sh', project])
run('import-command', ['bash', root / 'build/import_project.sh', project, work / 'import.log'])
run('wait', [sys.executable, root / 'tests/replay_comparison/wait_builds.py', project, work / 'wait.json'])
(project / 'out').mkdir()
(project / 'out/.gdignore').touch()
results = []
for mode in args.modes:
    index = int(mode == 'threads')
    export = project / 'out' / mode
    export.mkdir()
    text = run(mode + '-export', [env['GODOT'], '--headless', '--path', project, '--export-release', 'Web ' + mode, export / 'index.html'])
    assert f'thread support={index}' in text, text[-6000:]
    assert not any(marker in text for marker in ['SCRIPT ERROR', '\nERROR:', 'leaked at exit', 'resources still in use']), text[-6000:]
    html = export / 'index.html'
    text = html.read_text()
    assert text.count('engine.startGame({') == 1
    html.write_text(text.replace('engine.startGame({', "engine.startGame({\n'onExit': function(code) { window.__replay_package_exit = code; },"))
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    with (work / (mode + '-http.log')).open('w') as log:
        server = subprocess.Popen(['bash', str(root / 'build/serve.sh'), str(export), str(port)], env=env, stdout=log, stderr=subprocess.STDOUT)
        try:
            url = f'http://127.0.0.1:{port}/index.html'
            deadline = time.monotonic() + 10
            while True:
                try:
                    with urllib.request.urlopen(url, timeout=1): break
                except OSError:
                    assert server.poll() is None and time.monotonic() < deadline
                    time.sleep(.1)
            output = work / mode
            output.mkdir()
            run(mode + '-browser', ['node', root / 'tests/replay_distribution/drive.mjs', url, output], timeout=90)
        finally:
            server.terminate()
            server.wait(timeout=5)
    results.append({'mode': mode, 'threaded': bool(index), 'export': True, 'browser_pickup_effect_and_audio': True, 'engine_exit': 0 if args.engine_exit else None})
    (work / 'result.json').write_text(json.dumps(results, indent=2) + '\n')
    print('WEB_MEMORY_OK', mode, flush=True)
