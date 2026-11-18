"""A second game uses only declared actions and the framework scene worker."""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
work = Path(os.environ.get('REPLAY_GENERIC_OUT') or tempfile.mkdtemp(prefix='replay-generic-editor-')).resolve()
project = work / 'project'
(project / 'scripts').mkdir(parents=True)
(project / 'scripts/orbit.odin').write_text('''//gd:extends Resource
//gd:class OrbitDef
package orbit_tools
import gd "godot:godot"
OrbitDef :: struct {owner:gd.Resource,radius:gd.Int `gd:"export"`}
''')
(project / 'orbit.tres').write_text('''[gd_resource type="Resource" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/orbit.odin" id="1"]
[resource]
script=ExtResource("1")
radius=5
''')
(project / 'preview.tscn').write_text('[gd_scene format=3]\n[node name="OrbitPreview" type="Node2D"]\n')
(project / 'validate.tscn').write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://validate.gd" id="1"]
[node name="ValidateOrbit" type="Node"]
script=ExtResource("1")
''')
(project / 'validate.gd').write_text('''extends Node
func _ready():
    var resource = load("res://orbit.tres")
    var good = resource != null and resource.radius > 0 and resource.radius <= 20
    var report = {"ok":good,"message":"Orbit validated" if good else "Invalid orbit radius","issues":[]}
    if not good: report.issues.append({"source":"res://orbit.tres","path":"radius","message":"Radius must be 1–20."})
    var file = FileAccess.open(OS.get_environment("REPLAY_AUTHORING_REPORT"),FileAccess.WRITE)
    file.store_string(JSON.stringify(report));file.close()
    resource = null
    await get_tree().process_frame
    get_tree().quit(0 if good else 1)
''')
(project / 'replay_authoring.json').write_text(json.dumps({'version': 1, 'title': 'Orbit tools', 'actions': [
    {'id': 'check-orbit', 'label': 'Validate orbit', 'kind': 'run_scene', 'scene': 'res://validate.tscn'},
    {'id': 'preview-orbit', 'label': 'Open orbit preview', 'kind': 'open_scene', 'scene': 'res://preview.tscn'}]}, indent=2))
(project / 'project.godot').write_text('''config_version=5
[application]
config/name="Orbit authoring"
[rendering]
renderer/rendering_method="gl_compatibility"
[editor_plugins]
enabled=PackedStringArray("res://addons/replay_authoring/plugin.cfg", "res://addons/acceptance/plugin.cfg")
''')
shutil.copy2(ROOT / 'tests/kit_ui_bindings/odin_godot.gdextension', project / 'odin_godot.gdextension')
addon = project / 'addons/acceptance'
addon.mkdir(parents=True)
shutil.copy2(Path(__file__).with_name('generic_editor.gd'), addon / 'plugin.gd')
(addon / 'plugin.cfg').write_text('[plugin]\nname="Generic authoring acceptance"\nscript="plugin.gd"\n')
godot = os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot')
env = {**os.environ, 'ODIN_GODOT_ROOT': str(ROOT)}
env.pop('ODIN_SCRIPTS_DLL', None)
print('Generic authoring evidence:', work, flush=True)


def run(name, command, environment):
    with (work / (name + '.log')).open('w') as output:
        result = subprocess.run(list(map(str, command)), env=environment, stdout=output, stderr=subprocess.STDOUT, timeout=300)
    text = (work / (name + '.log')).read_text()
    assert result.returncode == 0 and not re.search(r'SCRIPT ERROR|\nERROR:|leaked at exit|resources still in use', text), text[-7000:]
    return text


run('build', ['bash', ROOT / 'build/build_scripts.sh', project], env)
run('import', [godot, '--headless', '--editor', '--path', project, '--quit-after', '120'], env)
run('wait', [sys.executable, ROOT / 'tests/replay_comparison/wait_builds.py', project, work / 'wait.json'], env)
# A GUI launch need not inherit the development shell. The worker must use
# the saved compiler selection rather than introducing its own Nix fallback.
gui_env = {k: v for k, v in env.items() if k not in ['ODIN', 'OLS', 'ODINFMT', 'EMCC', 'SGEN_BIN']}
gui_env.update({'PATH': '/usr/bin:/bin:/usr/sbin:/sbin', 'GENERIC_AUTHORING_CHECK': '1'})
assert shutil.which('odin', path=gui_env['PATH']) is None
text = run('editor', [godot, '--headless', '--editor', '--path', project], gui_env)
assert 'REPLAY_GENERIC_AUTHORING_OK' in text
(work / 'report.json').write_text(json.dumps({'declared_actions_only': True, 'no_status_poll': True,
    'default_scene_worker': True, 'saved_toolchain': True, 'clickable_issue': True,
    'validation_without_baked_status': True, 'preview_without_worker': True,
    'unsaved_tracking': True}, indent=2) + '\n')
print('REPLAY_GENERIC_AUTHORING_OK')
