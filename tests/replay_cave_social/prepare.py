from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True);project=out/'project'
shutil.copytree(root/'examples/replay_cavecrawl',project,ignore=shutil.ignore_patterns('.godot','bin','out','addons','node_modules','*.gen.odin','*.uid','*.import','__pycache__'))
shutil.copy2(root/'tests/replay_cave_social/probe.odin',project/'scripts/social_probe.odin')
shutil.copy2(root/'tests/replay_cave_social/browser.gd',project/'social_details.gd')
p=project/'cave.tscn';s=p.read_text().replace('[gd_scene load_steps=7 format=3]','[gd_scene load_steps=8 format=3]\n[ext_resource type="Script" path="res://social_details.gd" id="social_details"]',1);s+='\n[node name="SocialDetails" type="Node" parent="."]\nscript = ExtResource("social_details")\n';p.write_text(s)
p=project/'web_migration.gd';s=p.read_text();needle='\t\t\t\tprint("RCB_DURABLE checkpoint="';at=s.index(needle);s=s[:at]+'\t\t\t\tJavaScriptBridge.eval("globalThis.caveSocialHandoffReady=true;0",true)\n\t\t\t\tif not bool(JavaScriptBridge.eval("globalThis.caveSocialAllowHandoff||false",true)):return\n'+s[at:];p.write_text(s)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()},indent=2)+'\n')
files=subprocess.check_output(['rg','--files','replay','godot','gdext','runtime','core','scriptgen','build'],cwd=root,text=True).splitlines()
(out/'framework.json').write_text(json.dumps({name:sha(root/name) for name in files if Path(name).suffix in ('.odin','.sh','.py','.nix')},indent=2)+'\n')
