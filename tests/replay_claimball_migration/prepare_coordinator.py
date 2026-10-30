from pathlib import Path
import hashlib,json,shutil,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
shutil.copytree(root/'tests/replay_migration',out/'project',ignore=shutil.ignore_patterns('.godot','bin','out','addons','*.gen.odin','*.uid','*.import'))
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(out/'project')):hashlib.sha256(p.read_bytes()).hexdigest() for p in (out/'project').rglob('*') if p.is_file()},indent=2)+'\n')
