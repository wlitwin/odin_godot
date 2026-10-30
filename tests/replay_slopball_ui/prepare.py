from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
shutil.copytree(root/'examples/replay_slopball',out/'project',ignore=shutil.ignore_patterns('.godot','bin','out','addons','*.gen.odin','*.uid','*.import'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(out/'project')):sha(p) for p in (out/'project').rglob('*') if p.is_file()},indent=2)+'\n')
files=subprocess.check_output(['rg','--files','core','godot','gdext','runtime','kit','replay','build','scriptgen'],cwd=root,text=True).splitlines();(out/'framework.json').write_text(json.dumps({n:sha(root/n) for n in files if Path(n).suffix in ('.odin','.sh','.py','.nix')},indent=2)+'\n')
