"""Move real Kit starter entities into packages, then run their peer journeys."""
from pathlib import Path
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time

root, work = map(Path, sys.argv[1:3])
odin, godot, sgen = sys.argv[3:6]
work.mkdir(parents=True, exist_ok=True)
attributes = [f'-custom-attribute:{name}' for name in (
    'gd_method', 'gd_connect', 'gd_rpc', 'gd_command', 'gd_tick', 'gd_input',
    'gd_sample', 'gd_step', 'gd_event', 'gd_half', 'gd_message')]
errors = re.compile(r'SCRIPT ERROR|ERROR:|leaked at exit|resources still in use')


def run(command, log, **kwargs):
    with log.open('w') as output:
        subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, check=True, timeout=180, **kwargs)
    assert not errors.search(log.read_text()), log


def generate(project, label):
    run([sgen, str(project / 'scripts'), f'-godot:{root}', f'-project:{project}'], project / f'{label}-generate.log')
    text = (project / 'scripts/odin_godot_guard.gen.odin').read_text()
    fingerprints = re.findall(r'^NET_(?:ABI_)?FINGERPRINT :: .*$', text, re.M)
    schema = re.search(r'NET_SCHEMA_CANONICAL :: `(.*?)`', text, re.S)
    assert len(fingerprints) == 2 and schema
    return fingerprints, schema.group(1)


def prepare(name):
    project = work / name
    shutil.copytree(root / 'examples' / name, project,
                    ignore=shutil.ignore_patterns('bin', '.godot', '*.gen.odin', '*.dSYM'))
    # The shipped starters use subpackages. Flatten the isolated copy first
    # to compare that organization with the equivalent one-package contract.
    actors = project / 'scripts/actors'
    player = actors / 'player.odin'
    hooks = project / 'scripts/player_hooks.odin'
    text = player.read_text().replace(f'package {name}_entities', f'package {name}')
    callback = hooks.read_text()
    text += '\n' + callback[callback.index('@(gd_half)'):].replace('actors.Player', 'Player')
    (project / 'scripts/player.odin').write_text(text)
    uid = player.with_suffix('.odin.uid')
    if uid.exists():
        uid.rename(project / 'scripts' / uid.name)
    shutil.rmtree(actors)
    hooks.unlink()
    game = project / 'scripts/hello.odin'
    game.write_text(game.read_text().replace('import actors "actors"\n', '').replace('actors.', ''))
    scene = project / 'player.tscn'
    scene.write_text(scene.read_text().replace('res://scripts/actors/player.odin', 'res://scripts/player.odin'))
    if name == 'hello_net':
        player = project / 'scripts/player.odin'
        text = player.read_text()
        text = re.sub(r'(?m)^(\s*)pid:\s+u8', lambda m: m[1] + 'score: i32 `gd:"replicate"`,\n' + m[0], text, count=1)
        command = '''@(private)
@(gd_command = knet.ACTION_OWNER_PREDICTED)
player_award :: proc(self:^Player, amount:i32) -> (bool, i32) {
    self.score += amount
    return true, amount
}

'''
        player.write_text(text.replace('@(gd_half)\nplayer_born', command + '@(gd_half)\nplayer_born'))
        game = project / 'scripts/hello.odin'
        game.write_text(re.sub(r'(?m)^(\s*owner:\s+gd.Node2d[^\n]*\n)',
                              r'\1    command_points: i32,\n', game.read_text(), count=1))
        (project / 'scripts/commands.odin').write_text('''package hello_net
import gd "godot:godot"
import knet "godot:kit/net"
@(gd_half)
player_award_then :: proc(game:^HelloNet, self:^Player, by:knet.Player_Id, amount, awarded:i32) {
    game.command_points += awarded
}
@(gd_method)
hello_net_award :: proc(self:^HelloNet, amount:gd.Int) {
    if player, ok := player_mine(&self.boot); ok {player_award_cmd(&self.boot, player, i32(amount))}
}
@(gd_method)
hello_net_command_points :: proc(self:^HelloNet) -> gd.Int {return gd.Int(self.command_points)}
''')
        driver = project / 'hello_test.gd'
        text = driver.read_text().replace('phase = "watch"; t0 = now',
            'phase = "watch"; t0 = now\n\t\t\t\tif role == "guest": game.award(3)')
        text = text.replace('"done":\n', '''"done":
			if role == "host" and game.command_points() != 3: return false
			if role == "guest":
				if game.command_points() != 0:
					print("HELLO_FAIL consequence ran on predicting client"); quit(1); return true
				if game.probe_player_score(0) != 3: return false
			print("HELLO_OWNER_CALLBACK_OK points=", game.command_points())
''')
        driver.write_text(text)
    baseline = generate(project, 'flat')
    source = project / 'scripts/player.odin'
    text = source.read_text()
    at = text.index('@(gd_half)\nplayer_born')
    actors = project / 'scripts/actors'
    actors.mkdir()
    (actors / 'player.odin').write_text(text[:at].replace(f'package {name}', f'package {name}_entities'))
    uid = source.with_suffix('.odin.uid')
    if uid.exists():
        uid.rename(actors / uid.name)
    source.unlink()
    hooks = (f'package {name}\nimport gd "godot:godot"\nimport knet "godot:kit/net"\n'
             'import actors "actors"\n\n' + text[at:].replace('^Player', '^actors.Player'))
    (project / 'scripts/player_hooks.odin').write_text(hooks)
    game = project / 'scripts/hello.odin'
    text = game.read_text().replace('import "core:fmt"', 'import "core:fmt"\nimport actors "actors"')
    game.write_text(re.sub(r'\b(Player|Player_Input)\b', r'actors.\1', text))
    if name == 'hello_net':
        helper = project / 'scripts/commands.odin'
        helper.write_text(helper.read_text().replace('import gd "godot:godot"',
            'import gd "godot:godot"\nimport actors "actors"').replace('^Player', '^actors.Player')
            .replace('player_award_cmd(', 'actors.player_award_cmd('))
    scene = project / 'player.tscn'
    scene.write_text(scene.read_text().replace('res://scripts/player.odin', 'res://scripts/actors/player.odin'))
    assert generate(project, 'moved') == baseline, f'{name}: relocation changed wire contract'
    # Different aliases in the tag/sampler and the hook's defining file must
    # resolve to the same declaration. Generated imports choose their own names.
    for filename, alias in [('hello.odin', 'units'), ('player_hooks.odin', 'bodies')]:
        path = project / 'scripts' / filename
        path.write_text(path.read_text().replace('import actors "actors"', f'import {alias} "actors"')
                        .replace('actors.', alias + '.'))
    assert generate(project, 'aliased') == baseline, f'{name}: aliases changed wire contract'
    return project


def pair(project, sim):
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    processes, outputs = [], []
    try:
        for role, mode in [('host', 'host'), ('guest', 'join')]:
            path = project / f'{role}.log'
            output = path.open('w')
            outputs.append(output)
            env = {**os.environ, 'ROLE': role, 'HELLO_ROLE': mode, 'HELLO_PORT': str(port),
                   'HELLO_LATENCY': '120', 'HELLO_TOKEN': 'moved-guest',
                   'ODIN_SCRIPTS_DLL': str(project / 'bin' / ('libodinscripts.dylib' if sys.platform == 'darwin' else 'libodinscripts.so'))}
            process = subprocess.Popen([godot, '--headless', '--path', str(project), '--script', 'hello_test.gd'],
                                       env=env, stdout=output, stderr=subprocess.STDOUT)
            processes.append(process)
            if role == 'host':
                deadline = time.monotonic() + 10
                while time.monotonic() < deadline and 'HELLO_STARTED' not in path.read_text():
                    assert process.poll() is None, path
                    time.sleep(0.1)
                assert 'HELLO_STARTED' in path.read_text(), path
        for process in processes:
            assert process.wait(timeout=40) == 0, project
        for role in ['host', 'guest']:
            text = (project / f'{role}.log').read_text()
            assert role.upper() + '_DONE' in text and not errors.search(text), text
            if not sim:
                assert 'HELLO_BORN_PRESENTATION_OK' in text, text
                assert 'HELLO_OWNER_CALLBACK_OK points=' + ('3' if role == 'host' else '0') in text, text
        guest = (project / 'guest.log').read_text()
        assert 'HELLO_SAW_WALK' in guest, guest
        if sim:
            assert 'HELLO_PREDICTED' in guest, guest
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
        for output in outputs:
            output.close()


results = []
for name in ['hello_net', 'hello_sim']:
    project = prepare(name)
    env = {**os.environ, 'ODIN': odin, 'ODIN_GODOT_ROOT': str(root)}
    env.pop('ODIN_SCRIPTS_DLL', None)
    run(['bash', str(root / 'build/build_scripts.sh'), str(project)], project / 'build.log', env=env)
    run([godot, '--headless', '--path', str(project), '--editor', '--quit-after', '120'], project / 'editor.log', env=env)
    run([sys.executable, str(root / 'tests/replay_comparison/wait_builds.py'), str(project), str(project / 'wait.json')], project / 'wait.log', env=env)
    run(['bash', str(root / 'build/build_scripts.sh'), str(project)], project / 'final-build.log', env={**env, 'SKIP_CORE': '1'})
    run([odin, 'check', str(project / 'scripts'), f'-collection:godot={root}', '-target:freestanding_wasm32', '-no-entry-point', *attributes], project / 'wasm.log')
    pair(project, name == 'hello_sim')
    results.append({'project': name, 'entity_moved': True, 'input_moved': name == 'hello_sim',
                    'wire_identity_preserved': True, 'independent_import_aliases': True,
                    'native_pair': True, 'wasm_check': True})
(work / 'report.json').write_text(json.dumps(results, indent=2) + '\n')
print('KIT_SUBPACKAGE_ENTITIES_OK')
