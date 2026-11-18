"""One gameplay entity with stable named scene choices and a typed spawn API."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys

root, work = map(Path, sys.argv[1:3])
sgen, odin = sys.argv[3:5]
project = work / 'original'
scripts = project / 'scripts'
(scripts / 'actors').mkdir(parents=True)
(scripts / 'actors/actor.odin').write_text('''//gd:extends Node
package variant_actors
import gd "godot:godot"
import knet "godot:kit/net"
Actor :: struct {owner:gd.Node,net_id:knet.Net_Id,hp:i32 `gd:"replicate"`,skin:u32}
''')
(scripts / 'game.odin').write_text('''//gd:extends Node
package variant_game
import gd "godot:godot"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import kboot "godot:kit/boot"
import actors "actors"
Game :: struct {
    owner:gd.Node,
    boot:kboot.Boot,
    ses:ksess.Session,
    ordinary:gd.Packed_Scene `gd:"entity=actors.Actor:7"`,
    armored:gd.Packed_Scene `gd:"entity=actors.Actor:7,variant=Armored"`,
    bodies:map[knet.Net_Id]^actors.Actor,
}
''')
(scripts / 'variants_test.odin').write_text('''#+build !freestanding
package variant_game
import "core:testing"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import kboot "godot:kit/boot"
import actors "actors"
make_body :: proc(user:rawptr,type:ksess.Entity_Type,id:knet.Net_Id,owner:knet.Player_Id,variant:ksess.Scene_Variant)->(rawptr,^knet.Command_Set) {
    game:=cast(^Game)user
    body:=new(actors.Actor)
    body.skin=u32(variant)
    game.bodies[id]=body
    return body,game_entity_kinds[0].set
}
free_body :: proc(user:rawptr,id:knet.Net_Id,body:rawptr) {
    delete_key(&(cast(^Game)user).bodies,id);free(body)
}
@(test)
typed_variants_share_gameplay_identity :: proc(t:^testing.T) {
    game:Game
    game.boot.ses=&game.ses
    ksess.session_set_factory(&game.ses,&game,make_body,free_body)
    ksess.session_host_start(&game.ses,"variants")
    defer {
        for _,body in game.bodies {free(body)}
        delete(game.bodies)
        ksess.session_destroy(&game.ses)
    }
    body,id:=actor_spawn(&game.boot,variant=.Armored)
    testing.expect_value(t,body.skin,u32(Actor_Variant.Armored))
    body.hp=12
    kboot.boot_spawn_send(&game.boot,id)
    chosen,exists:=ksess.session_scene_variant(&game.ses,id)
    testing.expect(t,exists && chosen==ksess.Scene_Variant(Actor_Variant.Armored))
    ordinary,ordinary_id:=actor_spawn(&game.boot)
    testing.expect_value(t,ordinary.skin,u32(0))
    kboot.boot_spawn_send(&game.boot,ordinary_id)
    testing.expect_value(t,game.ses.types[id],game.ses.types[ordinary_id])
    testing.expect_value(t,len(game_entity_kinds),1)
    testing.expect_value(t,len(game_entity_kinds[0].scenes),2)
    testing.expect_value(t,len(NET_SCHEMA.entities),1)
    testing.expect_value(t,len(NET_SCHEMA.scenes),2)
    testing.expect(t,knet.net_schema_valid(&NET_SCHEMA))
    scene,known:=knet.net_schema_scene(&NET_SCHEMA,"Actor","Armored")
    testing.expect(t,known && scene.id==u32(Actor_Variant.Armored))
}
''')


def check(project, error=None):
    result = subprocess.run([sgen, str(project / 'scripts'), f'-godot:{root}', f'-project:{project}'], capture_output=True, text=True)
    (project / 'generate.log').write_text(result.stdout + result.stderr)
    if error:
        assert result.returncode != 0 and error in result.stderr, result.stderr
        assert not list((project / 'scripts').rglob('*.gen.odin'))
        return
    assert result.returncode == 0, result.stderr
    with (project / 'compile.log').open('w') as output:
        flags = [f'-collection:godot={root}']
        subprocess.run([odin, 'test', str(project / 'scripts'), *flags, f'-out:{project / "variants.test"}'], stdout=output, stderr=subprocess.STDOUT, check=True)
        subprocess.run([odin, 'check', str(project / 'scripts'), *flags, '-no-entry-point', '-target:freestanding_wasm32'], stdout=output, stderr=subprocess.STDOUT, check=True)
    text = (project / 'scripts/odin_godot_guard.gen.odin').read_text()
    schema = re.search(r'NET_SCHEMA_CANONICAL :: `(.*?)`', text, re.S).group(1)
    assert 'scene entity.Actor.Default id=0' in schema and 'scene entity.Actor.Armored id=' in schema
    return re.findall(r'^NET_(?:ABI_)?FINGERPRINT :: .*$', text, re.M), schema


baseline = check(project)
for name in ['reordered', 'renamed_fields', 'moved', 'duplicate', 'missing_default', 'different_type_id', 'variant_policy', 'keyword', 'renamed_variant']:
    dest = work / name
    shutil.copytree(project, dest, ignore=shutil.ignore_patterns('*.gen.odin', '*.log', '*.test'))
    path = dest / 'scripts/game.odin'
    text = path.read_text()
    error = None
    if name == 'reordered':
        lines = text.splitlines(True)
        a, b = [i for i,line in enumerate(lines) if 'gd:"entity=' in line]
        lines[a], lines[b] = lines[b], lines[a]
        text = ''.join(lines)
    elif name == 'renamed_fields':
        text = text.replace('ordinary:', 'base_model:').replace('armored:', 'heavy_model:')
    elif name == 'moved':
        (dest / 'scripts/actors').rename(dest / 'scripts/units')
        for source in (dest / 'scripts').glob('*.odin'):
            source.write_text(source.read_text().replace('import actors "actors"', 'import bodies "units"').replace('actors.', 'bodies.'))
        text = path.read_text()
    elif name == 'duplicate':
        text = text.replace(',variant=Armored', '')
        error = 'duplicates or collides'
    elif name == 'missing_default':
        text = text.replace('entity=actors.Actor:7"', 'entity=actors.Actor:7,variant=Plain"')
        error = 'needs a Default scene'
    elif name == 'different_type_id':
        text = text.replace('Actor:7,variant=Armored', 'Actor:8,variant=Armored')
        error = 'scene variants share that gameplay identity'
    elif name == 'variant_policy':
        text = text.replace('variant=Armored', 'variant=Armored,avatar')
        error = 'named variants inherit'
    elif name == 'keyword':
        text = text.replace('variant=Armored', 'variant=struct')
        error = 'using an Odin enum member name'
    else:
        text = text.replace('variant=Armored', 'variant=Heavy')
        test = dest / 'scripts/variants_test.odin'
        test.write_text(test.read_text().replace('Armored', 'Heavy'))
    path.write_text(text)
    if name == 'renamed_variant':
        result = subprocess.run([sgen, str(dest/'scripts'), f'-godot:{root}', f'-project:{dest}'], capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
        text = (dest/'scripts/odin_godot_guard.gen.odin').read_text()
        assert re.findall(r'^NET_(?:ABI_)?FINGERPRINT :: .*$', text, re.M) != baseline[0]
    elif error:
        check(dest, error)
    else:
        assert check(dest) == baseline, f'{name} changed scene identity'
(work / 'report.json').write_text(json.dumps({'native': True, 'wasm_check': True,
    'typed_spawn': True, 'default_unchanged': True, 'one_gameplay_kind': True,
    'field_order_path_alias_invariance': True, 'variant_name_changes_contract': True,
    'invalid_declarations_refused': True}, indent=2) + '\n')
print('KIT_SCENE_VARIANTS_CODEGEN_OK')
