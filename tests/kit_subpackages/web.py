"""Run the qualified event and backup adapters in an actual Godot Web export.

Usage: python3 web.py <kitentities-output-directory> <new-output-directory>
Run kitentities first to produce its checked fixtures. Requires the normal
Odin/Emscripten/Godot development environment and tests/web's puppeteer-core.
"""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import sys
import threading

ROOT = Path(os.environ.get('ODIN_GODOT_ROOT', Path(__file__).resolve().parents[2])).resolve()
fixtures, work = map(lambda s: Path(s).resolve(), sys.argv[1:3])
project = work / 'project'
shutil.copytree(fixtures / 'events/original/scripts', project / 'scripts',
                ignore=shutil.ignore_patterns('*.gen.odin', '*_test.odin'))
shutil.copytree(fixtures / 'backups/original/scripts/blocks', project / 'scripts/blocks',
                ignore=shutil.ignore_patterns('*.gen.odin'))
game = project / 'scripts/game.odin'
game.write_text(game.read_text().replace('owner:gd.Node,', 'owner:gd.Node,\n    state:blocks.State,') + '\nimport blocks "blocks"\n')


def assertions(source):
    source = source.replace('#+build !freestanding\n', '').replace('import "core:testing"\n', '')
    source = re.sub(r'testing\.expect_value\(t,(.*),(.*)\)', r'assert(\1 == \2)', source)
    return re.sub(r'testing\.expect\(t,(.*)\)', r'assert(\1)', source)


events = (fixtures / 'events/original/scripts/events_test.odin').read_text()
events = assertions(events).replace('@(test)\nqualified_events :: proc(t:^testing.T)', '@(gd_method)\ngame_verify_events :: proc(self:^Game)')
(project / 'scripts/check_events.odin').write_text(events)
(project / 'scripts/startup.odin').write_text('''package event_game
import "base:runtime"
import knet "godot:kit/net"
import actors "coop_a"
@(init)
check_startup :: proc "contextless" () {
    context = runtime.default_context()
    assert(knet.desc_data_size(&actors.actor_net_desc) > 0)
}
''')
backups = (fixtures / 'backups/original/scripts/backup_test.odin').read_text()
backups = assertions(backups).replace('package backup_game', 'package event_game').replace('import "core:os"\n', '')
backups = backups.replace('@(test)\nbackup_roundtrip :: proc(t:^testing.T)', '@(gd_method)\ngame_verify_backups :: proc(self:^Game)')
backups = '\n'.join(line for line in backups.splitlines() if not any(x in line for x in ['WRITE ::', 'READ ::', 'when WRITE', 'when READ'])) + '\n'
(project / 'scripts/check_backups.odin').write_text(backups)

shutil.copy2(ROOT / 'tests/kit_ui_bindings/odin_godot.gdextension', project / 'odin_godot.gdextension')
(project / 'project.godot').write_text('''config_version=5
[application]
config/name="Kit Subpackages Web"
run/main_scene="res://main.tscn"
[rendering]
renderer/rendering_method="gl_compatibility"
''')
(project / 'main.tscn').write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://driver.gd" id="1"]
[node name="Test" type="Node"]
script=ExtResource("1")
''')
(project / 'driver.gd').write_text('''extends Node
func _ready():
    var game = Node.new()
    game.set_script(load("res://scripts/game.odin"))
    add_child(game)
    game.verify_events()
    game.verify_backups()
    game.queue_free()
    await get_tree().process_frame
    await get_tree().process_frame
    print("KIT_SUBPACKAGES_WEB_PASS")
    get_tree().quit(0)
''')
presets = (ROOT / 'tests/box3d_web/integration/project/export_presets.cfg').read_text().replace('variant/thread_support=true', 'variant/thread_support=false')
(project / 'export_presets.cfg').write_text(presets)
env = {k:v for k,v in os.environ.items() if k not in ['ODIN_SCRIPTS_DLL', 'SCRIPT_BUILD_FLAGS'] and not k.startswith('BOX3D_')}
godot = env.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot')


def run(name, args):
    log = work / (name + '.log')
    with log.open('w') as stream:
        result = subprocess.run([str(x) for x in args], cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=300)
    text = log.read_text(errors='replace')
    assert result.returncode == 0 and not re.search(r'SCRIPT ERROR|\nERROR:|ODIN_SCRIPT_PANIC|leaked at exit|resources still in use', text), str(log) + '\n' + text[-5000:]
    print(name, 'PASS', flush=True)


run('build', ['bash', ROOT / 'build/build_scripts.sh', project])
run('import', [godot, '--headless', '--editor', '--path', project, '--quit-after', '120'])
run('wait', [sys.executable, ROOT / 'tests/replay_comparison/wait_builds.py', project, work / 'wait.json'])
export = work / 'export'
export.mkdir()
run('export', [godot, '--headless', '--path', project, '--export-release', 'Web', export / 'index.html'])
html = export / 'index.html'
text = html.read_text()
assert text.count('engine.startGame({') == 1
html.write_text(text.replace('engine.startGame({', "engine.startGame({\n'args': ['--audio-driver', 'Dummy'],\n'onExit': function(code) { window.__kit_subpackages_exit = code; },"))
driver = (ROOT / 'tests/kit_ui_bindings/drive.mjs').read_text()
driver = driver.replace('../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js', (ROOT / 'tests/web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js').as_uri())
driver = driver.replace('KIT_UI_WEB_PASS', 'KIT_SUBPACKAGES_WEB_PASS').replace('__kit_ui_exit', '__kit_subpackages_exit')
driver = driver.replace('Actual exported Godot Web UI bindings, typed rejection, standard attach and cleanup', 'Actual exported Godot Web subpackage events and imported private backup types')
driver = driver.replace('const errors = [], lines = [];', 'const errors = [], lines = [], pending = [];')
driver = driver.replace('const text = msg.text();', '''const text = msg.text();
    if (msg.type()==='error') pending.push(Promise.all(msg.args().map(arg =>
      arg.evaluate(value => value && value.stack ? value.stack : String(value)).catch(() => '')
    )).then(details => errors.push(...details.filter(Boolean))));''')
driver = driver.replace('report.exit = await', 'await Promise.all(pending);\n  report.exit = await')
driver = driver.replace('browser UI check failed', 'browser subpackage check failed')
(work / 'drive.mjs').write_text(driver)


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        super().end_headers()

    def log_message(self, *args):
        pass


server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(export)))
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    run('browser', ['node', work / 'drive.mjs', f'http://127.0.0.1:{server.server_port}/index.html', work])
finally:
    server.shutdown()
    server.server_close()
assert json.loads((work / 'report.json').read_text())['result'] == 'PASS'
print('KIT_SUBPACKAGES_WEB_OK', work)
