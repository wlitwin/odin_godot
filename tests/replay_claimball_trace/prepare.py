from pathlib import Path
import hashlib,json,re,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'tests/replay_claimball_ui/prepare.py'),str(out)],check=True)
p=out/'project/scripts/claimball.odin';s=p.read_text()
def patch(pattern,replacement,label):
 global s
 s,count=re.subn(pattern,replacement,s,flags=re.M)
 if count!=1:raise RuntimeError(f'{label}: expected one source anchor, found {count}')
patch(r'^([ \t]*owner:[ \t]*gd\.Node2d,)[ \t]*$',r'\1\n    observer_trace: [1]Observer_Trace,','trace storage')
patch(r'^([ \t]*)gd\.print_str\("REPLAY_CLAIMBALL_READY"\)$',r'\1trace_start(self)\n\1gd.print_str("REPLAY_CLAIMBALL_READY")','trace start')
patch(r'^([ \t]*)observe_room\(self\)$',r'\1trace_frame(self)\n\1observe_room(self)','trace frame')
patch(r'(replay_claimball_exit_tree\s*::\s*proc\(self:\s*\^ReplayClaimball\)\s*\{)',r'\1\n    trace_close(self)','trace close')
p.write_text(s)
shutil.copy2(root/'tests/replay_claimball_trace/observer.odin',out/'project/scripts/observer_trace.odin')
manifest=json.loads((out/'prepared.json').read_text())
for name in ['scripts/claimball.odin','scripts/observer_trace.odin']:manifest[name]=hashlib.sha256((out/'project'/name).read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps(manifest,indent=2)+'\n')
