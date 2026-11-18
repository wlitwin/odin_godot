"""Declared event references retain their identity across package layouts."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys

root, work = map(Path, sys.argv[1:3])
sgen, odin = sys.argv[3:5]
project = work / 'original'


def write(name, source):
    path = project / 'scripts' / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(source)


write('game.odin', '''//gd:extends Node
package event_game
import gd "godot:godot"
import kboot "godot:kit/boot"
import ksess "godot:kit/session"
import ksim "godot:kit/sim"
import ca "coop_a"
import cb "coop_b"
import sa "sim_a"
import sb "sim_b"
Game :: struct {
    owner:gd.Node,
    boot:kboot.Boot,
    ses:ksess.Session,
    lane:ksim.Lane,
    first:gd.Packed_Scene `gd:"entity=ca.Actor:11"`,
    second:gd.Packed_Scene `gd:"entity=cb.Actor:22"`,
    third:gd.Packed_Scene `gd:"entity=sa.Actor:33"`,
    fourth:gd.Packed_Scene `gd:"entity=sb.Actor:44"`,
    coop_calls, sim_calls, manual_calls, static_calls:i32,
    result:i64,
    mine:bool,
}
@(gd_step)
game_step :: proc(self:^Game) {}
''')
write('controls/input.odin', 'package event_controls\nInput :: struct {move:i32}\n')
for package, scalar in [('coop_a', 'i32'), ('coop_b', 'i64'), ('sim_a', 'i32'), ('sim_b', 'i64')]:
    sim = package.startswith('sim')
    source = f'''//gd:extends Node
package event_{package}
import gd "godot:godot"
import knet "godot:kit/net"
Actor :: struct {{
    owner:gd.Node,
    net_id:knet.Net_Id,
    x:f32 `gd:"{'predict' if sim else 'owner'}"`,
    marker:{scalar} `gd:"replicate"`,
}}
'''
    if sim:
        source += '''import ctrl "../controls"
@(gd_tick)
actor_tick :: proc(self:^Actor, input:ctrl.Input) {self.x += f32(input.move)}
'''
    write(f'{package}/actor.odin', source)
write('manual/body.odin', '''//gd:extends Node
package event_manual
import gd "godot:godot"
import ctrl "../controls"
Manual :: struct {owner:gd.Node, x:f32 `gd:"predict"`}
@(gd_tick)
manual_tick :: proc(self:^Manual, input:ctrl.Input) {self.x += f32(input.move)}
''')
write('events.odin', '''package event_game
import loot "coop_a"
import gear "coop_b"
import walkers "sim_a"
import bots "sim_b"
import custom "manual"
@(gd_event="anchor=right")
coop_pair_fx :: proc(g:^Game,left:^loot.Actor,right:^gear.Actor,mine:bool,power:u8) {
    g.coop_calls += 1; g.result = i64(left.marker) + right.marker + i64(power); g.mine = mine
}
@(gd_event="anchor=none,timing=immediate")
coop_world_fx :: proc(g:^Game,left:^loot.Actor,right:^gear.Actor,mine:bool) {
    g.coop_calls += 1; g.result = i64(left.marker) + right.marker; g.mine = mine
}
@(gd_event="anchor=right")
sim_pair_fx :: proc(g:^Game,left:^walkers.Actor,right:^bots.Actor,mine:bool,power:u8) {
    g.sim_calls += 1; g.result = i64(left.marker) + right.marker + i64(power); g.mine = mine
}
@(gd_event="anchor=none")
sim_world_fx :: proc(g:^Game,left:^walkers.Actor,right:^bots.Actor,mine:bool) {
    g.sim_calls += 1; g.result = i64(left.marker) + right.marker; g.mine = mine
}
@(gd_event)
manual_ping_fx :: proc(g:^Game,body:^custom.Manual,mine:bool) {g.manual_calls += 1;g.mine=mine}
@(gd_event="anchor=none,timing=immediate")
static_ping_fx :: proc(g:^Game,mine:bool) {g.static_calls += 1;g.mine=mine}
''')
write('events_test.odin', (root / 'tests/kit_subpackages/events_test.odin.txt').read_text())
# A procedure in another package does not claim the owner's generated name.
write('coop_a/helper.odin', 'package event_coop_a\ngame_event_routes :: proc() {}\n')


def check(project, expected=None):
    result = subprocess.run([sgen, str(project / 'scripts'), f'-godot:{root}', f'-project:{project}'], capture_output=True, text=True)
    (project / 'generate.log').write_text(result.stdout + result.stderr)
    if expected:
        assert result.returncode != 0 and expected in result.stderr, result.stderr
        assert not list((project / 'scripts').rglob('*.gen.odin'))
        return
    assert result.returncode == 0, result.stderr
    flags = [f'-collection:godot={root}', '-custom-attribute:gd_event', '-custom-attribute:gd_tick', '-custom-attribute:gd_step']
    with (project / 'compile.log').open('w') as output:
        subprocess.run([odin, 'test', str(project / 'scripts'), *flags, f'-out:{project / "events.test"}'], stdout=output, stderr=subprocess.STDOUT, check=True)
        subprocess.run([odin, 'check', str(project / 'scripts'), *flags, '-no-entry-point', '-target:freestanding_wasm32'], stdout=output, stderr=subprocess.STDOUT, check=True)
    text = (project / 'scripts/odin_godot_guard.gen.odin').read_text()
    schema = re.search(r'NET_SCHEMA_CANONICAL :: `(.*?)`', text, re.S).group(1)
    assert 'schedule=session-anchored anchor=Actor#22' in schema
    assert 'schedule=watch anchor=Actor#44' in schema
    return re.findall(r'^NET_(?:ABI_)?FINGERPRINT :: .*$', text, re.M), schema


baseline = check(project)
for name in ['renamed', 'root_move']:
    dest = work / name
    shutil.copytree(project, dest, ignore=shutil.ignore_patterns('*.gen.odin', '*.log', '*.test'))
    if name == 'renamed':
        (dest / 'scripts/coop_a').rename(dest / 'scripts/loot')
        for path in (dest / 'scripts').glob('*.odin'):
            source = path.read_text().replace('"coop_a"', '"loot"')
            source = source.replace('import walkers "sim_a"', 'import moving "sim_a"').replace('walkers.Actor', 'moving.Actor')
            path.write_text(source)
    else:
        source = dest / 'scripts/sim_a/actor.odin'
        (dest / 'scripts/actor.odin').write_text(source.read_text().replace('package event_sim_a', 'package event_game').replace('"../controls"', '"controls"'))
        shutil.rmtree(source.parent)
        for path in (dest / 'scripts').glob('*.odin'):
            source = path.read_text()
            for alias in re.findall(r'^import (\w+) "sim_a"$', source, re.M):
                source = source.replace(f'import {alias} "sim_a"\n', '').replace(f'{alias}.', '')
            path.write_text(source)
    assert check(dest) == baseline, f'{name} changed the event wire contract'

collision = work / 'owner_collision'
shutil.copytree(project, collision, ignore=shutil.ignore_patterns('*.gen.odin', '*.log', '*.test'))
with (collision / 'scripts/events.odin').open('a') as source:
    source.write('\ngame_event_routes :: proc() {}\n')
check(collision, 'game_event_routes is generated by @(gd_event) declarations on Game')

(work / 'report.json').write_text(json.dumps({'native': True, 'wasm_check': True,
    'same_named_entities': True, 'handler_import_scope': True,
    'session_anchored_and_immediate': True, 'sim_live_and_delayed': True,
    'wrong_kind_and_stale_refs': True, 'malformed_payloads': True,
    'replay_suppression': True, 'manual_lane_refs': True,
    'package_scoped_route_collisions': True,
    'alias_and_move_invariance': True}, indent=2) + '\n')
print('KIT_QUALIFIED_EVENTS_OK')
