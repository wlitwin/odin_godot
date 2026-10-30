from pathlib import Path
import hashlib,json,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();profile=sys.argv[2] if len(sys.argv)>2 else 'server'
subprocess.run([sys.executable,str(root/'tests/replay_cave_feedback/prepare.py'),str(out),profile],check=True)
project=out/'project'
(project/'scripts/rock_probe.odin').write_text((root/'tests/replay_cave_rocks/probe.odin').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()},indent=2)+'\n')

# The exported Web main scene runs the same static-value visual contract.
s=(root/'tests/replay_cave_rocks/visual.gd').read_text().replace('extends SceneTree','extends Node').replace('func _initialize():','func _ready():').replace('root.add_child(game)','add_child(game)').replace('await process_frame','await get_tree().process_frame').replace('quit(1)','get_tree().quit(1)').replace('quit(0)','get_tree().quit(0)').replace('root.get_texture()','get_viewport().get_texture()')
(project/'feedback_web.gd').write_text(s)
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()},indent=2)+'\n')
