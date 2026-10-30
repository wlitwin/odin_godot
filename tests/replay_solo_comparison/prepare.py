from pathlib import Path
import hashlib,json,shutil,subprocess,sys,re
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
old=out/'kit/project';new=out/'replay/project'
subprocess.run([sys.executable,str(root/'tests/replay_scrapyard/prepare_baseline.py'),str(root.parent/'scrapyard'),str(old),str(root)],check=True)
subprocess.run([sys.executable,str(root/'tests/replay_scrapyard/baseline_cleanup.py'),str(old)],check=True)
shutil.copytree(root/'examples/replay_scrapyard',new,ignore=shutil.ignore_patterns('.godot','bin','out','node_modules','*.gen.odin','*.uid','*.import','__pycache__'))
p=new/'project.godot';p.write_text(p.read_text().replace('config/custom_user_dir_name="replay_scrapyard"','config/custom_user_dir_name="replay_solo_comparison"'))
# Match the original gauntlet launcher overrides in the isolated Replay catalog.
p=new/'data/guns/bolter.tres';s=p.read_text();s,n=re.subn(r'^mag = \d+$','mag = 255',s,flags=re.M);assert n==1;s,n=re.subn(r'^jam_per_mille = \d+$','jam_per_mille = 0',s,flags=re.M);assert n==1;p.write_text(s)
for impl,project in [('kit',old),('replay',new)]:
 shutil.copy2(root/'tests/replay_solo_comparison/driver.gd',project/'solo_compare.gd')
 shutil.copy2(root/'tests/replay_solo_comparison/navigation.gd',project/'solo_navigation.gd')
 shutil.copy2(root/f'tests/replay_solo_comparison/{impl}.odin',project/'scripts/solo_compare.odin')
# Test-only receipt counter; leave the blast's damage/reaction code intact.
p=old/'scripts/combat.odin';s=p.read_text();needle='gd.print_str(fmt.tprintf("SY_BARREL_BOOM hits=%d by=%d", hits, u64(attacker)))';assert s.count(needle)==1;p.write_text(s.replace(needle,'solo_blasts += 1\n\t'+needle))
shutil.copy2(root/'tests/replay_solo_comparison/contract.json',out/'contract.json')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(out)):sha(p) for folder in [old,new] for p in folder.rglob('*') if p.is_file()},indent=2)+'\n')
paths=subprocess.check_output(['rg','--files','core','godot','gdext','runtime','kit','play','replay','build','scriptgen'],cwd=root,text=True).splitlines();(out/'framework.json').write_text(json.dumps({p:sha(root/p) for p in paths if Path(p).suffix in ('.odin','.sh','.py','.nix')},indent=2)+'\n')
