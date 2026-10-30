from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True);project=out/'project'
shutil.copytree(root/'examples/replay_scrapyard',project,ignore=shutil.ignore_patterns('.godot','bin','out','node_modules','*.gen.odin','*.uid','*.import','__pycache__'))
p=project/'project.godot';p.write_text(p.read_text().replace('config/custom_user_dir_name="replay_scrapyard"','config/custom_user_dir_name="replay_observer_name_fixture"'))
shutil.copy2(root/'tests/replay_observer_names/bridge.gd',project/'observer_names.gd')
p=project/'main.tscn';s=p.read_text().replace('[gd_scene format=3]','[gd_scene format=3]\n[ext_resource type="Script" path="res://observer_names.gd" id="observer_names"]',1);s+='\n[node name="ObserverNames" type="Node" parent="."]\nscript = ExtResource("observer_names")\n';p.write_text(s)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'source.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()},indent=2)+'\n')
paths=subprocess.check_output(['rg','--files','core','godot','gdext','runtime','kit','play','replay','build','scriptgen'],cwd=root,text=True).splitlines();(out/'framework.json').write_text(json.dumps({p:sha(root/p) for p in paths if Path(p).suffix in ('.odin','.sh','.py','.nix')},indent=2)+'\n')
