from pathlib import Path
import hashlib,json,shutil,subprocess,sys

root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'tests/replay_cave_social/prepare.py'),str(out)],check=True)
project=out/'project'
shutil.copy2(root/'tests/replay_cave_carrier/probe.odin',project/'scripts/carrier_probe.odin')
p=project/'web_migration.gd';s=p.read_text()
old='\t\t\t\tif member==3: game.walk_to(300.0,180.0)\n\t\t\t\tphase="chest" if member==3 else "handoff"'
new='\t\t\t\tif member==1: game.walk_to(120.0,80.0)\n\t\t\t\telif member==3: game.walk_to(300.0,180.0)\n\t\t\t\tphase="relic" if member==1 else "chest" if member==3 else "handoff"'
assert old in s;s=s.replace(old,new,1)
needle='\t\t"chest":'
s=s.replace(needle,'\t\t"relic":\n\t\t\tif game.probe_near(120.0,80.0): game.carry();phase="relic_wait"\n\t\t"relic_wait":\n\t\t\tif game.campaign_probe("carrier",1)==1: game.walk_to(180.0,80.0);phase="handoff"\n'+needle,1)
needle='\t\t\t"presentation_ping":';assert needle in s
s=s.replace(needle,'\t\t\t"carrier_drop": game.set_down()\n'+needle,1);p.write_text(s)
p=project/'social_details.gd';s=p.read_text();needle=' if not previous.is_empty()';assert needle in s
s=s.replace(needle,' var carrier_seat:=2 if epoch>1 else 1\n state.carrier=int(game.carrier_value("carrier",carrier_seat));state.carrier_version=int(game.carrier_value("version",carrier_seat))\n state.carrier_attached=game.carrier_value("x",carrier_seat)==game.carrier_value("player_x",carrier_seat)+10 and game.carrier_value("y",carrier_seat)==game.carrier_value("player_y",carrier_seat)-12\n'+needle,1);p.write_text(s)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()},indent=2)+'\n')
