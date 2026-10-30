from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'tests/replay_claimball_ui/prepare.py'),str(out)],check=True)
p=out/'project/scripts/claimball.odin';s=p.read_text();s=s.replace('owner: gd.Node2d,','owner: gd.Node2d,\n observer_trace:[1]Observer_Trace,',1)
s=s.replace('gd.print_str("REPLAY_CLAIMBALL_READY")','trace_start(self);gd.print_str("REPLAY_CLAIMBALL_READY")')
s=s.replace('\tobserve_room(self)','\ttrace_frame(self)\n\tobserve_room(self)',1)
s=s.replace('replay_claimball_exit_tree :: proc(self:', 'replay_claimball_exit_tree :: proc(self:',1)
a=s.index('{',s.index('replay_claimball_exit_tree ::'));s=s[:a+1]+'\n trace_close(self)'+s[a+1:];p.write_text(s)
shutil.copy2(root/'tests/replay_claimball_trace/observer.odin',out/'project/scripts/observer_trace.odin')
manifest=json.loads((out/'prepared.json').read_text())
for name in ['scripts/claimball.odin','scripts/observer_trace.odin']:manifest[name]=hashlib.sha256((out/'project'/name).read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps(manifest,indent=2)+'\n')
