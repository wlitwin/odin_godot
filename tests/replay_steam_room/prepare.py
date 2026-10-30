from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
subprocess.run([sys.executable,str(root/'tests/replay_cave_feedback/prepare.py'),str(out)],check=True)
project=out/'project'
for name in ['fake_steam.gd','fake_peer.gd']:shutil.copy2(root/'tests/replay_steam_room'/name,project/name)
shutil.copy2(root/'tests/replay_steam_room/probe.odin',project/'scripts/steam_room_probe.odin')
shutil.copy2(root/'tests/replay_cave_carrier/probe.odin',project/'scripts/carrier_probe.odin')
p=project/'scripts/cave.odin';s=p.read_text().replace('owner: gd.Node2d,','owner: gd.Node2d,\n test_steam:transportgd.Steam_Runtime,');s=s.replace('opts.network.content = game.CONTENT','opts.network.content = game.CONTENT\n if !steam_room_configure(self,&opts) {gd.print_str("STEAM_ROOM_FAIL runtime");return}');s=s.replace('replay_cave_exit_tree :: proc(self: ^ReplayCave) {','replay_cave_exit_tree :: proc(self: ^ReplayCave) {\n defer transportgd.steam_runtime_release(&self.test_steam)');p.write_text(s)
p=project/'cave.tscn';s=p.read_text().replace('[gd_scene load_steps=7 format=3]','[gd_scene load_steps=8 format=3]\n[ext_resource type="Script" path="res://fake_steam.gd" id="steam_fixture"]',1);s+='\n[node name="FakeSteam" type="Node" parent="."]\nscript = ExtResource("steam_fixture")\n';p.write_text(s)
shutil.copytree(root/'tests/replay_migration',out/'coordinator',ignore=shutil.ignore_patterns('.godot','bin','out','addons','*.gen.odin','*.uid','__pycache__'))
p=out/'coordinator/scripts/coordinator.odin';s=p.read_text().replace('endpoint, _ := auth.endpoint("127.0.0.1", u16(port + i + 1))','endpoint, _ := transportgd.steam_endpoint(u64(76561198000000001+i),u16(gd.env_int("STEAM_VIRTUAL_PORT",0)))');p.write_text(s)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()},indent=2)+'\n')
(out/'coordinator.json').write_text(json.dumps({str(p.relative_to(out/'coordinator')):sha(p) for p in (out/'coordinator').rglob('*') if p.is_file()},indent=2)+'\n')
