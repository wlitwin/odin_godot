"""Prepare the archived C2 app and receiver in an isolated collection overlay."""
from pathlib import Path
import hashlib,json,shutil,sys,tarfile
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True);overlay=out/'collection';overlay.mkdir();project=out/'project';project.mkdir()
# Only source directories are linked; all build outputs remain under out.
for name in ['build','core','decl','gdext','godot','runtime','kit','scriptgen','tests']:(overlay/name).symlink_to(root/name,target_is_directory=True)
(overlay/'replay').mkdir()
for p in (root/'replay').iterdir():
 if p.name in ['net','godot']:shutil.copytree(p,overlay/'replay'/p.name)
 else:(overlay/'replay'/p.name).symlink_to(p,target_is_directory=p.is_dir())
with tarfile.open(root/'docs/replay/results/claimball-ui-2026-09-13/source.tar.gz') as archive:
 for name in ['replay/net/client.odin','replay/net/server.odin','replay/net/recent_facts.odin','replay/godot/room.odin']:(overlay/name).write_bytes(archive.extractfile(name).read())
with tarfile.open(root/'docs/replay/results/claimball-ui-2026-09-13/prepared.tar.gz') as archive:
 for item in archive.getmembers():
  if not item.isfile() or item.name.endswith(".gen.odin"):continue
  rel=Path(item.name);assert not rel.is_absolute() and '..' not in rel.parts
  target=project/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.extractfile(item).read())
(overlay/'examples/replay_claimball/shared').mkdir(parents=True)
shutil.copytree(project/'shared/pitch',overlay/'examples/replay_claimball/shared/pitch')
p=project/'scripts/claimball.odin';s=p.read_text().replace('owner: gd.Node2d,','owner: gd.Node2d,\n observer_trace:[1]Observer_Trace,',1)
s=s.replace('gd.print_str("REPLAY_CLAIMBALL_READY")','trace_start(self);gd.print_str("REPLAY_CLAIMBALL_READY")')
needle='\tif err := rgd.session_frame(&self.session, dt, control); err != .None {gd.print_str(fmt.tprintf("REPLAY_CLAIMBALL_FAIL frame=%v", err)); return}'
assert needle in s;s=s.replace(needle,needle+'\n\ttrace_frame(self)')
a=s.index('{',s.index('replay_claimball_exit_tree ::'));s=s[:a+1]+'\n trace_close(self)'+s[a+1:];p.write_text(s)
shutil.copy2(root/'tests/replay_claimball_trace/observer.odin',project/'scripts/observer_trace.odin')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()},indent=2)+'\n')
(out/'overlay.json').write_text(json.dumps({name:sha(overlay/name) for name in ['replay/net/client.odin','replay/net/server.odin','replay/net/recent_facts.odin','replay/godot/room.odin']},indent=2)+'\n')
current=out/'current-collection';current.mkdir()
for p in overlay.iterdir():
 if p.name in ['replay','bin']:continue
 (current/p.name).symlink_to(p,target_is_directory=p.is_dir())
(current/'replay').mkdir()
for p in (overlay/'replay').iterdir():
 if p.name=='net':shutil.copytree(root/'replay/net',current/'replay/net')
 else:(current/'replay'/p.name).symlink_to(p,target_is_directory=p.is_dir())
print(overlay)
