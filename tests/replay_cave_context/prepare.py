from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'examples/replay_cavecrawl_owned/prepare.py'),str(out)],check=True)
project=out/'project';p=project/'scripts/cave.odin';s=p.read_text()
s=s.replace('owner: gd.Node2d,','owner: gd.Node2d,\n\tcontext_gate:[1]Context_Gate,',1)
s=s.replace('if self.ready {gd.print_str("REPLAY_CAVE_READY")}','if self.ready {context_gate_open(self);gd.print_str("REPLAY_CAVE_READY")}')
s=s.replace('replay_cave_exit_tree :: proc(self: ^ReplayCave) {','replay_cave_exit_tree :: proc(self: ^ReplayCave) {\n context_gate_close(self)')
p.write_text(s);shutil.copy2(root/'tests/replay_cave_context/gate.odin',project/'scripts/context_gate.odin')
manifest=json.loads((out/'prepared.json').read_text())
for n in ['scripts/cave.odin','scripts/context_gate.odin']:manifest[n]=hashlib.sha256((project/n).read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps(manifest,indent=2)+'\n')
