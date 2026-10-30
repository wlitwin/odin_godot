from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True);project=out/'project'
shutil.copytree(root/'examples/replay_scrapyard',project,ignore=shutil.ignore_patterns('.godot','bin','out','addons','node_modules','*.gen.odin','*.uid','*.import','__pycache__'))
p=project/'project.godot';p.write_text(p.read_text().replace('config/custom_user_dir_name="replay_scrapyard"','config/custom_user_dir_name="replay_recording_test"'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()},indent=2)+'\n')
files=subprocess.check_output(['rg','--files','replay','godot','gdext','runtime','core','scriptgen','build'],cwd=root,text=True).splitlines()
(out/'framework.json').write_text(json.dumps({name:sha(root/name) for name in files if Path(name).suffix in ('.odin','.py','.sh','.nix')},indent=2)+'\n')
