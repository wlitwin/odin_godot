from pathlib import Path
import hashlib,json,re,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'examples/replay_cavecrawl_owned/prepare.py'),str(out)],check=True)
project=out/'project';p=project/'scripts/cave.odin';s=p.read_text()
def patch(pattern,replacement,label):
 global s
 s,count=re.subn(pattern,replacement,s,flags=re.M)
 if count!=1:raise RuntimeError(f'{label}: expected one source anchor, found {count}')
patch(r'^([ \t]*owner:[ \t]*gd\.Node2d,)[ \t]*$',r'\1\n    context_gate: [1]Context_Gate,','context storage')
patch(r'^([ \t]*)gd\.print_str\("REPLAY_CAVE_READY"\)$',r'\1context_gate_open(self)\n\1gd.print_str("REPLAY_CAVE_READY")','context start')
patch(r'(replay_cave_exit_tree\s*::\s*proc\(self:\s*\^ReplayCave\)\s*\{)',r'\1\n    context_gate_close(self)','context close')
p.write_text(s);shutil.copy2(root/'tests/replay_cave_context/gate.odin',project/'scripts/context_gate.odin')
manifest=json.loads((out/'prepared.json').read_text())
for n in ['scripts/cave.odin','scripts/context_gate.odin']:manifest[n]=hashlib.sha256((project/n).read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps(manifest,indent=2)+'\n')
