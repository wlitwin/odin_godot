from pathlib import Path
import hashlib,importlib.util,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'tests/replay_cave_carrier/browser_prepare.py'),str(out)],check=True)
spec=importlib.util.spec_from_file_location('owner_profile',root/'examples/replay_cavecrawl_owned/prepare.py');profile=importlib.util.module_from_spec(spec);spec.loader.exec_module(profile)
project=out/'project';profile.apply_profile(project)
# Read actual owner scopes in the same authoritative observations as the existing
# social/carrier gate. This does not change simulation or production input.
p=project/'social_details.gd';s=p.read_text();needle=' if not previous.is_empty()'
s=s.replace(needle,''' state.compact_facts_sent=int(game.social_metrics("compact_facts_sent",0));state.compact_sent=int(game.social_metrics("compact_sent",0));state.compact_authority=bool(game.social_metrics("compact_authority",0))
 state.owner_profile=int(game.motion_probe("profile",0))
 state.owner_epoch=int(game.motion_probe("epoch",0))
 state.prop_owner=int(game.motion_probe("prop_owner",0));state.prop_revision=int(game.motion_probe("prop_revision",0));state.prop_sequence=int(game.motion_probe("prop_sequence",0))
 state.avatar_revisions=[];state.avatar_sequences=[]
 for seat in range(1,4):
  state.avatar_revisions.append(int(game.motion_probe("avatar_revision",seat)));state.avatar_sequences.append(int(game.motion_probe("avatar_sequence",seat)))
'''+needle,1);p.write_text(s)
shutil.copytree(root/'tests/replay_web_authority/server',out/'server',ignore=shutil.ignore_patterns('.godot','bin','out','addons','*.gen.odin','*.uid'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(out)):sha(p) for base in [project,out/'server'] for p in base.rglob('*') if p.is_file()},indent=2)+'\n')
paths=subprocess.check_output(['rg','--files','replay','godot','gdext','runtime','core','build','scriptgen','examples/replay_cavecrawl/shared'],cwd=root,text=True).splitlines()
(out/'framework.json').write_text(json.dumps({n:sha(root/n) for n in paths if Path(n).suffix in ('.odin','.sh','.py','.nix')},indent=2)+'\n')
