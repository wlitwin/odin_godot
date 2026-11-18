"""Equal local names remain distinct through kind IDs and declaring packages."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys

root, work = map(Path, sys.argv[1:3])
sgen, odin = sys.argv[3:5]


def write(project, name, text):
    path = project / 'scripts' / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


project = work / 'original'
write(project, 'game.odin', '''//gd:extends Node
package names_game
import gd "godot:godot"
import kboot "godot:kit/boot"
import a "a"
import b "b"
Game :: struct {
    owner:gd.Node,
    boot:kboot.Boot,
    first:gd.Packed_Scene `gd:"entity=a.Actor:11"`,
    second:gd.Packed_Scene `gd:"entity=b.Actor:22"`,
    first_points, second_points:i64,
}
''')
for package, scalar in [('a', 'i32'), ('b', 'i64')]:
    write(project, package + '/actor.odin', f'''//gd:extends Node
package names_{package}
import gd "godot:godot"
import knet "godot:kit/net"
Actor :: struct {{owner:gd.Node, net_id:knet.Net_Id, value:{scalar} `gd:"replicate"`}}
@(private)
@(gd_command)
actor_add :: proc(self:^Actor, amount:i32) -> (bool, {scalar}) {{self.value += {scalar}(amount);return true,self.value}}
''')
write(project, 'hooks.odin', '''package names_game
import knet "godot:kit/net"
import a "a"
import b "b"
@(gd_half)
game_first_add_then :: proc(game:^Game, self:^a.Actor, by:knet.Player_Id, amount:i32, result:i32) {game.first_points += i64(result)}
@(gd_half)
game_second_add_then :: proc(game:^Game, self:^b.Actor, by:knet.Player_Id, amount:i32, result:i64) {game.second_points += 10*result}
''')
write(project, 'names_test.odin', '''#+build !freestanding
package names_game
import "core:testing"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import rt "godot:runtime"
import a "a"
import b "b"
@(test)
distinct_entities :: proc(t:^testing.T) {
    testing.expect_value(t,len(rt.registration_errors()),0)
    game:Game
    session:ksess.Session
    session.reg=knet.registry_make()
    session.ctx=knet.command_ctx_make()
    session.is_host,session.ran,session.joined=true,true,true
    session.ctx.is_authority=true
    session.ctx.game_user=&game
    defer ksess.session_destroy(&session)
    game.boot.ses=&session
    first:a.Actor
    second:b.Actor
    knet.registry_insert(&session.reg,1,&first,game_entity_kinds[0].set)
    knet.registry_insert(&session.reg,2,&second,game_entity_kinds[1].set)
    testing.expect(t,a.actor_add_cmd(&game.boot,&first,3).state==.Applied)
    testing.expect(t,b.actor_add_cmd(&game.boot,&second,4).state==.Applied)
    testing.expect_value(t,game.first_points,i64(3))
    testing.expect_value(t,game.second_points,i64(40))
    testing.expect_value(t,len(NET_SCHEMA.entities),2)
    testing.expect_value(t,NET_SCHEMA.entities[0].name,"Actor#11")
    testing.expect_value(t,NET_SCHEMA.entities[0].wire_id,u16(11))
    testing.expect_value(t,NET_SCHEMA.entities[1].name,"Actor#22")
    testing.expect_value(t,NET_SCHEMA.entities[1].wire_id,u16(22))
}
''')


def check(project, expected=None):
    result = subprocess.run([sgen, str(project / 'scripts'), f'-godot:{root}', f'-project:{project}'], capture_output=True, text=True)
    (project / 'generate.log').write_text(result.stdout + result.stderr)
    if expected:
        assert result.returncode != 0 and expected in result.stderr, result.stderr
        assert not list((project / 'scripts').rglob('*.gen.odin'))
        return
    assert result.returncode == 0, result.stderr
    text = (project / 'scripts/odin_godot_guard.gen.odin').read_text()
    schema = re.search(r'NET_SCHEMA_CANONICAL :: `(.*?)`', text, re.S).group(1)
    assert 'field entity.Actor#11.value lane=delta encoding=raw struct-width=4' in schema
    assert 'field entity.Actor#22.value lane=delta encoding=raw struct-width=8' in schema
    with (project / 'compile.log').open('w') as output:
        flags = [f'-collection:godot={root}', '-custom-attribute:gd_command', '-custom-attribute:gd_half']
        subprocess.run([odin, 'test', str(project / 'scripts'), *flags, f'-out:{project / "names.test"}'], stdout=output, stderr=subprocess.STDOUT, check=True)
        subprocess.run([odin, 'check', str(project / 'scripts'), *flags, '-no-entry-point', '-target:freestanding_wasm32'], stdout=output, stderr=subprocess.STDOUT, check=True)
    return re.findall(r'^NET_(?:ABI_)?FINGERPRINT :: .*$', text, re.M), schema


baseline = check(project)
for variant in ['renamed', 'root_move', 'duplicate_id', 'unbound', 'alias_collision']:
    dest = work / variant
    shutil.copytree(project, dest, ignore=shutil.ignore_patterns('*.gen.odin', '*.log', '*.test'))
    if variant == 'renamed':
        (dest / 'scripts/a').rename(dest / 'scripts/units')
        for path in (dest / 'scripts').glob('*.odin'):
            path.write_text(path.read_text().replace('import a "a"', 'import left "units"').replace('a.Actor', 'left.Actor').replace('a.actor_add_cmd', 'left.actor_add_cmd'))
        assert check(dest) == baseline
    elif variant == 'root_move':
        source = dest / 'scripts/a/actor.odin'
        (dest / 'scripts/actor.odin').write_text(source.read_text().replace('package names_a', 'package names_game'))
        shutil.rmtree(source.parent)
        for path in (dest / 'scripts').glob('*.odin'):
            path.write_text(path.read_text().replace('import a "a"\n', '').replace('a.Actor', 'Actor').replace('a.actor_add_cmd', 'actor_add_cmd'))
        assert check(dest) == baseline
    elif variant == 'duplicate_id':
        path = dest / 'scripts/game.odin'
        path.write_text(path.read_text().replace('entity=b.Actor:22', 'entity=b.Actor:11'))
        check(dest, 'wire id 11 is already claimed')
    else:
        (dest / 'scripts/hooks.odin').unlink()
        path = dest / 'scripts/game.odin'
        path.write_text(re.sub(r'`gd:"entity=[^"]+"`', '', path.read_text()))
        if variant == 'unbound':
            check(dest, 'wire type Actor is declared in multiple packages')
        else:
            for directory, alias in [('a', 'FirstActor'), ('b', 'SecondActor')]:
                path = dest / 'scripts' / directory / 'actor.odin'
                path.write_text(path.read_text().replace('//gd:extends Node', '//gd:extends Node\n//gd:class ' + alias))
            write(dest, 'c/extra.odin', '//gd:extends Node\npackage names_c\nimport gd "godot:godot"\nFirstActor :: struct {owner:gd.Node, value:i32 `gd:"replicate"`}\n')
            check(dest, 'wire identity "FirstActor" also names')
(work / 'report.json').write_text(json.dumps({'same_names_distinct': True,
    'alias_and_move_invariance': True, 'field_scoped_callbacks': True,
    'duplicate_ids_refused': True, 'ambiguous_unbound_refused': True,
    'native': True, 'wasm_check': True}, indent=2) + '\n')
print('KIT_QUALIFIED_NAMES_OK')
