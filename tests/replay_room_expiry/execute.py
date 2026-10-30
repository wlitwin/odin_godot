from pathlib import Path
import json,subprocess,sys
root=Path(__file__).resolve().parents[2];app,coordinator,out=map(Path,sys.argv[1:4])
subprocess.run([sys.executable,str(root/'tests/replay_claimball_migration/execute.py'),str(app),str(coordinator),str(out)],check=True)
for mode,members in [('planned',[1,2,3]),('crash',[2,3])]:
 for member in members:
  text=(out/mode/f'member-{member}.log').read_text()
  assert text.count('ROOM_EXPIRY_INJECTED member='+str(member))==1,(mode,member)
  assert text.count('ROOM_EXPIRY_PRESERVED member='+str(member))==1,(mode,member)
 print('REPLAY_ROOM_EXPIRY_PHASE_OK',mode)
print('REPLAY_ROOM_EXPIRY_OK')
