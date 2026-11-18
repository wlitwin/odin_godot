"""Bad scene roots must refuse without leaking nodes when assertions are off."""
from pathlib import Path
import json
import os
import re
import shutil
import socket
import subprocess
import sys

root, work = map(Path, sys.argv[1:3])
project = work / 'project'
shutil.copytree(root / 'examples/hello_sim', project,
                ignore=shutil.ignore_patterns('bin', '.godot', '*.gen.odin', '*.dSYM', '.runlogs'))
game = project / 'scripts/hello.odin'
source = game.read_text()
source, count = re.subn(r'^([ \t]*player_scene:[^\n]*\n)', lambda match: match[1] + '    bad_scene: gd.Packed_Scene `gd:"entity=actors.Player:1,variant=Invalid"`,\n', source, flags=re.M)
assert count == 1
game.write_text(source)
(project / 'bad.tscn').write_text('[gd_scene format=3]\n[node name="WrongScript" type="Node2D"]\n')
scene = project / 'hello.tscn'
source = scene.read_text().replace('load_steps=4', 'load_steps=5')
source = source.replace('[node name="HelloNet"', '[ext_resource type="PackedScene" path="res://bad.tscn" id="4_bad"]\n\n[node name="HelloNet"')
scene.write_text(source.replace('player_scene = ExtResource("2_player")', 'player_scene = ExtResource("2_player")\nbad_scene = ExtResource("4_bad")'))
(project / 'scripts/invalid_probe.odin').write_text('''package hello_sim
import gd "godot:godot"
import kboot "godot:kit/boot"
import ksess "godot:kit/session"
@(gd_method)
hello_sim_test_invalid_variants :: proc(self:^HelloSim) -> bool {
    before := len(self.boot.ent_nodes)
    children := gd.node_get_child_count(self.boot.world, false)
    registered := len(self.ses.types)
    entity,id := player_spawn(&self.boot,variant=.Invalid)
    if entity!=nil || id!=0 {return false}
    was_host := self.ses.is_host
    self.ses.is_host = false
    defer self.ses.is_host = was_host
    raw,predicted := kboot.boot_spawn_predicted(&self.boot,PLAYER_TYPE,self.ses.me,ksess.Scene_Variant(Player_Variant.Invalid))
    return raw==nil && predicted==0 && len(self.boot.ent_nodes)==before &&
        len(self.ses.types)==registered && gd.node_get_child_count(self.boot.world, false)==children
}
''')
(project / 'invalid.gd').write_text('''extends SceneTree
func _initialize():
    call_deferred("run")
func run():
    var game = load("res://hello.tscn").instantiate()
    root.add_child(game)
    for _frame in range(120):
        if game.probe_player_count() > 0: break
        await process_frame
    var before = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
    var passed = game.probe_player_count() > 0 and game.test_invalid_variants()
    passed = passed and Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) == before
    game.queue_free()
    await process_frame
    await process_frame
    if passed: print("KIT_VARIANT_INVALID_SCENE_OK")
    quit(0 if passed else 1)
''')
with socket.socket() as sock:
    sock.bind(('127.0.0.1', 0))
    port = sock.getsockname()[1]
env = {**os.environ, 'ODIN_GODOT_ROOT': str(root), 'SCRIPT_BUILD_FLAGS': '-disable-assert',
       'HELLO_ROLE': 'host', 'HELLO_PORT': str(port)}
env.pop('ODIN_SCRIPTS_DLL', None)
godot = env.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot')


def run(name, command):
    log = work / (name + '.log')
    with log.open('w') as output:
        result = subprocess.run(list(map(str, command)), env=env, stdout=output, stderr=subprocess.STDOUT, timeout=180)
    text = log.read_text()
    assert result.returncode == 0 and not re.search(r'SCRIPT ERROR|ERROR:|leaked at exit|resources still in use', text), text[-5000:]
    return text


run('build', ['bash', root/'build/build_scripts.sh', project])
run('editor', [godot, '--headless', '--editor', '--path', project, '--quit-after', '120'])
run('wait', [sys.executable, root/'tests/replay_comparison/wait_builds.py', project, work/'wait.json'])
run('final-build', ['bash', root/'build/build_scripts.sh', project])
assert 'KIT_VARIANT_INVALID_SCENE_OK' in run('runtime', [godot, '--headless', '--path', project, '--script', 'invalid.gd'])
(work/'report.json').write_text(json.dumps({'assertions_disabled': True, 'authority_refuses': True,
    'prediction_refuses': True, 'no_published_entity': True, 'no_orphan_nodes': True}, indent=2)+'\n')
print('KIT_VARIANT_INVALID_SCENE_OK')
