from pathlib import Path
import hashlib,importlib.util,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
project=out/'project'
shutil.copytree(root/'examples/replay_cavecrawl',project,ignore=shutil.ignore_patterns('.godot','bin','out','addons','node_modules','*.gen.odin','*.uid','*.import','__pycache__'))
shutil.copy2(root/'tests/replay_cave_feedback/probe.odin',project/'scripts/feedback_probe.odin')
shutil.copy2(root/'tests/replay_cave_feedback/drive.gd',project/'feedback_test.gd')
if len(sys.argv)>2 and sys.argv[2]=='owner':
 spec=importlib.util.spec_from_file_location('owner_profile',root/'examples/replay_cavecrawl_owned/prepare.py');owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner);owner.apply_profile(project)
p=project/'project.godot';s=p.read_text().replace('run/main_scene="res://cave.tscn"','run/main_scene="res://feedback_test.tscn"');p.write_text(s)
# SceneTree script for native execution; an equivalent scene wrapper for Web.
s=(project/'feedback_test.gd').read_text().replace('extends SceneTree','extends Node').replace('func _initialize():','func _ready():').replace('root.add_child(game)','add_child(game)').replace('await process_frame','await get_tree().process_frame').replace('await create_timer(', 'await get_tree().create_timer(').replace('quit(1)','get_tree().quit(1)').replace('quit(0)','get_tree().quit(0)').replace('root.get_texture()','get_viewport().get_texture()')
(project/'feedback_web.gd').write_text(s)
(project/'feedback_test.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://feedback_web.gd" id="1"]\n[node name="FeedbackTest" type="Node"]\nscript = ExtResource("1")\n')
p=project/'campaign_test.gd';s=p.read_text()
old='\t\t\t\tif p("hp",2)==55:done()'
new='''\t\t\t\tif role=="host" and read("heal-proof").is_empty():
\t\t\t\t\tvar proof_tick:int=int(game.feedback_heal_proof("tick"))
\t\t\t\t\tif proof_tick==-2:fail("accepted heal transition violated rules");return false
\t\t\t\t\tif proof_tick>0:write("heal-proof",{"tick":proof_tick,"before":game.feedback_heal_proof("before"),"damage":game.feedback_heal_proof("damage"),"after":game.feedback_heal_proof("after"),"stamina":game.feedback_heal_proof("stamina"),"cooldown":game.feedback_heal_proof("cooldown"),"sequence":game.feedback_heal_proof("sequence")})
\t\t\t\tvar proof:=read("heal-proof")
\t\t\t\tif not proof.is_empty() and p("hp",2)==int(proof.after) and p("heal_cd",2)>0:done()'''
assert old in s;s=s.replace(old,new)
needle='print("REPLAY_CAVE_CAMPAIGN_OK role="';i=s.index(needle);s=s[:i]+'''assert(int(game.feedback_probe("died"))>=2,"both deaths presented")
						assert(int(game.feedback_probe("slain"))>=12,"all slain bursts presented")
						assert(int(game.feedback_probe("hits"))>0,"hit feedback presented")
						assert(int(game.feedback_probe("dweller_hits"))>=24,"all dweller impacts presented")
						assert(int(game.feedback_probe("dropped"))==0,"no presentation overflow")
						print("CAVE_FEEDBACK_CAMPAIGN died=",game.feedback_probe("died")," slain=",game.feedback_probe("slain")," hits=",game.feedback_probe("hits")," dweller_hits=",game.feedback_probe("dweller_hits")," started=",game.feedback_probe("started"))
						'''+s[i:];p.write_text(s)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()},indent=2)+'\n')
names=subprocess.check_output(['rg','--files','replay','godot','gdext','runtime','core','scriptgen','build','examples/replay_cavecrawl/shared'],cwd=root,text=True).splitlines()
(out/'framework.json').write_text(json.dumps({n:sha(root/n) for n in names if Path(n).suffix in ('.odin','.py','.sh','.nix')},indent=2)+'\n')
