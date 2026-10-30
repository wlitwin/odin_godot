from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True);project=out/'project'
shutil.copytree(root/'tests/replay_dedicated_room',project,ignore=shutil.ignore_patterns('.godot','bin','out','addons','*.gen.odin','*.uid','__pycache__'))
from overlay import apply
p=project/'scripts/probe.odin';p.write_text(apply(p.read_text()))
shutil.copy2(root/'tests/replay_dedicated_combat/combat.odin',project/'scripts/combat.odin')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()},indent=2)+'\n')
paths=subprocess.check_output(['rg','--files','replay','godot','gdext','runtime','core','build','scriptgen'],cwd=root,text=True).splitlines();(out/'framework.json').write_text(json.dumps({n:sha(root/n) for n in paths if Path(n).suffix in ('.odin','.sh','.py','.nix')},indent=2)+'\n')
