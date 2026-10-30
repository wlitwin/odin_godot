from pathlib import Path
import hashlib,json,shutil,subprocess,sys
from overlay import apply
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'tests/replay_dedicated_browser/prepare.py'),str(out)],check=True)
p=out/'game/project/scripts/probe.odin';p.write_text(apply(p.read_text(),browser=True))
shutil.copy2(root/'tests/replay_dedicated_combat/combat.odin',out/'game/project/scripts/combat.odin')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(out)):sha(p) for base in ['game','service'] for p in (out/base/'project').rglob('*') if p.is_file()},indent=2)+'\n')
