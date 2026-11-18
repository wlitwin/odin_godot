"""Run owner callback bindings before and after an entity-package move."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys

root, work = map(Path, sys.argv[1:3])
sgen, odin = sys.argv[3:5]
attributes = [f'-custom-attribute:{name}' for name in
              ['gd_command', 'gd_half', 'gd_tick', 'gd_step', 'gd_input']]


def prepare(name, flat=False):
    project = work / name
    shutil.copytree(root / 'tests/kit_subpackages/callback_fixture', project / 'scripts')
    if flat:
        for path in (project / 'scripts/actors').glob('*.odin'):
            (project / 'scripts' / path.name).write_text(path.read_text().replace('package callback_actors', 'package callback_game'))
        shutil.rmtree(project / 'scripts/actors')
        for path in (project / 'scripts').glob('*.odin'):
            text = re.sub(r'^import (?:actors|bodies|units) "actors"\n', '', path.read_text(), flags=re.M)
            text = re.sub(r'\b(?:actors|bodies|units)\.', '', text)
            path.write_text(text)
    return project


def check(project):
    with (project / 'generate.log').open('w') as log:
        subprocess.run([sgen, str(project / 'scripts'), f'-godot:{root}', f'-project:{project}'],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    with (project / 'compile.log').open('w') as log:
        subprocess.run([odin, 'test', str(project / 'scripts'), f'-collection:godot={root}', *attributes,
                        f'-out:{project / "callback.test"}'], stdout=log, stderr=subprocess.STDOUT, check=True)
        subprocess.run([odin, 'check', str(project / 'scripts'), f'-collection:godot={root}', *attributes,
                        '-no-entry-point', '-target:freestanding_wasm32'], stdout=log, stderr=subprocess.STDOUT, check=True)
    text = (project / 'scripts/odin_godot_guard.gen.odin').read_text()
    hashes = re.findall(r'^NET_(?:ABI_)?FINGERPRINT :: .*$', text, re.M)
    schema = re.search(r'NET_SCHEMA_CANONICAL :: `(.*?)`', text, re.S).group(1)
    assert 'event entity.Walker.walker_tick id=0 schedule=watch' in schema
    return hashes, schema


flat = check(prepare('flat', flat=True))
moved = check(prepare('moved'))
assert flat == moved, 'moving owner callbacks changed the wire contract'

helper = prepare('helper_package')
source = helper / 'scripts/actors/counter.odin'
destination = helper / 'scripts/blocks/counter.odin'
destination.parent.mkdir()
destination.write_text(source.read_text().replace('package callback_actors', 'package callback_blocks'))
source.unlink()
source = helper / 'scripts/actors/actor.odin'
source.write_text(source.read_text().replace('import gd "godot:godot"', 'import gd "godot:godot"\nimport blocks "../blocks"').replace('counter: Counter(i32)', 'counter: blocks.Counter(i32)'))
assert check(helper) == flat, 'private helper package changed the wire contract'
bridge = helper / 'scripts/blocks/odin_godot_scripts.gen.odin'
assert '_kit_proc_counter_gain :: proc {counter_gain}' in bridge.read_text()

def reject(project, expected):
    result = subprocess.run([sgen, str(project / 'scripts'), f'-godot:{root}', f'-project:{project}'],
                            capture_output=True, text=True)
    (project / 'generate.log').write_text(result.stdout + result.stderr)
    assert result.returncode != 0 and expected in result.stderr, result.stderr
    assert not list((project / 'scripts').rglob('*.gen.odin'))

wrong = prepare('wrong_owner')
path = wrong / 'scripts/hooks.odin'
path.write_text(path.read_text().replace('game_a_actor_add_then :: proc(game: ^GameA', 'game_a_actor_add_then :: proc(game: ^GameB'))
reject(wrong, 'callback game_a_actor_add_then expects ^GameB')

conflict = prepare('conflicting_id')
path = conflict / 'scripts/game_b.odin'
path.write_text(path.read_text().replace('entity=bodies.Actor:1', 'entity=bodies.Actor:3'))
reject(conflict, 'already uses wire id 1')

inherited = prepare('incompatible_default')
path = inherited / 'scripts/actors/actor.odin'
path.write_text(path.read_text().replace('actor_add_then :: proc(self: ^Actor', 'actor_add_then :: proc(game: ^OtherOwner, self: ^Actor') + '\nOtherOwner :: struct {unused:i32}\n')
reject(inherited, 'callback actor_add_then expects ^OtherOwner')

(work / 'report.json').write_text(json.dumps({'owner_specific': True, 'commands': True,
    'generic_private_command': True, 'edges': True, 'tick_consequences': True,
    'live_and_delayed_presentation': True, 'prediction_replay_suppression': True,
    'unsampled_private_input': True, 'flat_moved_contract': True,
    'private_helper_package': True, 'wrong_owner_refused': True,
    'conflicting_identity_refused': True, 'incompatible_default_refused': True,
    'native': True, 'wasm_check': True}, indent=2) + '\n')
print('KIT_OWNER_CALLBACKS_OK')
