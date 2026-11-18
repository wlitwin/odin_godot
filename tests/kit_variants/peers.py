"""Exercise authored scene variants and predicted creation in the real starter."""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import sys

root, work = map(Path, sys.argv[1:3])
project = work / 'project'
shutil.copytree(root / 'examples/hello_sim', project,
                ignore=shutil.ignore_patterns('bin', '.godot', '*.gen.odin', '*.dSYM', '.runlogs'))
(project / 'scripts/variant_probe.odin').write_text((root / 'tests/kit_variants/predicted_probe.odin.txt').read_text())
actor = project / 'scripts/actors/player.odin'
source = actor.read_text().replace('import knet "godot:kit/net"', 'import knet "godot:kit/net"\nimport kboot "godot:kit/boot"\nimport ksess "godot:kit/session"')
fields = '''
    test_boot:^kboot.Boot,
    test_allow:bool,
    test_mode:i32 `gd:"replicate"`,
    test_fires:i32,
    test_first_id,test_last_id:knet.Net_Id,
'''
source, count = re.subn(r'(Player :: struct \{\s*\n\s*owner:[^\n]*\n)', lambda match: match[1] + fields, source)
assert count == 1
source += '''
@(gd_command = knet.ACTION_OWNER_PREDICTED)
player_test_equip :: proc(self:^Player) -> bool {
    if !self.test_allow {return false}
    self.test_mode = 1
    return true
}
@(gd_command = knet.ACTION_OWNER_PREDICTED)
player_test_fire :: proc(self:^Player) -> bool {
    variant := ksess.DEFAULT_SCENE_VARIANT
    if self.test_mode == 1 {
        for kind in self.test_boot.ent_kinds {
            if kind.type != 1 {continue}
            for scene in kind.scenes {if scene.name == "Diamond" {variant = scene.variant}}
        }
    }
    raw,id := kboot.boot_fire_spawn(self.test_boot, 1, knet.PLAYER_ID_INVALID, variant)
    if raw == nil {return false}
    projectile := cast(^Player)raw
    projectile.x,projectile.y = self.x,self.y
    self.test_fires += 1
    if self.test_first_id == 0 {self.test_first_id = id}
    self.test_last_id = id
    kboot.boot_spawn_send(self.test_boot,id)
    return true
}
'''
actor.write_text(source)
hooks = project / 'scripts/player_hooks.odin'
source = hooks.read_text()
needle_hook = '    _ = id'
assert needle_hook in source
hooks.write_text(source.replace(needle_hook, '    self.test_boot = &game.boot\n' + needle_hook))
driver = project / 'hello_test.gd'
source = driver.read_text()
source = source.replace('var phase := "boot"', 'var phase := "boot"\nvar chain_started := false\nvar chain_verified := false\nvar chain_logged := false')
needle = '\t\t\t\tprint("HELLO_VARIANTS_OK default=1 diamond=1")'
assert needle in source
source = source.replace(needle, needle + '''
				if role == "guest" and not game.test_predicted_variants():
					print("HELLO_FAIL predicted scene variants")
					quit(1); return true''')
source = source.replace('\t\t"walk":\n', '''\t\t"walk":
			if role == "guest" and not chain_started: chain_started = game.test_begin_variant_chain()
			if role == "guest" and chain_started and not chain_verified: chain_verified = game.test_variant_chain_done()
			if role == "guest" and now - t0 > 1000 and not chain_logged:
				print("HELLO_VARIANT_CHAIN_TRACE started=", chain_started, " ", game.test_variant_chain_status())
				chain_logged = true
''')
source = source.replace('\t\t"done":\n', '\t\t"done":\n\t\t\tif role == "guest" and not chain_verified: return false\n')
driver.write_text(source)
env = {**os.environ, 'ODIN_GODOT_ROOT': str(root), 'HELLO_SIM_PROJECT': str(project)}
with (work / 'run.log').open('w') as output:
    result = subprocess.run(['bash', str(root / 'examples/hello_sim/run.sh')], env=env,
                            stdout=output, stderr=subprocess.STDOUT, timeout=240)
text = (work / 'run.log').read_text()
assert result.returncode == 0 and 'HELLO_SIM_OK' in text, text[-5000:]
guest_logs = list(project.rglob('guest.log'))
assert guest_logs and any('HELLO_PREDICTED_VARIANTS_OK' in p.read_text() for p in guest_logs)
assert any('HELLO_VARIANT_REJECT_CHAIN_OK' in p.read_text() for p in guest_logs)
for path in guest_logs:
    assert not re.search(r'SCRIPT ERROR|ERROR:|leaked at exit|resources still in use', path.read_text())
(work / 'report.json').write_text(json.dumps({'authored_scenes_on_both_peers': True,
    'predicted_scene_selection': True, 'reverse_order_match': True,
    'replay_reuses_node': True, 'provisional_alias_keeps_variant': True,
    'unknown_variant_refused': True, 'cancel_cleans_census': True,
    'rejected_command_replaces_provisional_variant': True,
    'scene_lifecycle': True}, indent=2) + '\n')
print('KIT_SCENE_VARIANTS_PEERS_OK')
