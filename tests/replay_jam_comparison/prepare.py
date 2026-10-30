from pathlib import Path
import hashlib,json,re,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];here=Path(__file__).resolve().parent;out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'tests/replay_endurance_comparison/prepare.py'),str(out)],check=True)
shutil.copy2(out/'contract.json',out/'endurance-preparation-contract.json')
for impl in ('kit','replay'):
 project=out/impl/'project';baseline=impl=='kit';prefix='scrapyard' if baseline else 'replay_scrapyard';typ='Scrapyard' if baseline else 'ReplayScrapyard'
 resource=project/'data/guns/bolter.tres';before=resource.read_text();after,n=re.subn(r'^jam_per_mille = \d+$','jam_per_mille = 200',before,flags=re.M);assert n==1;resource.write_text(after)
 fixture=json.loads((out/impl/'endurance-fixture.json').read_text());fixture['data/guns/bolter.tres']['after_sha256']=hashlib.sha256(after.encode()).hexdigest();fixture['data/guns/bolter.tres']['setting']['jam_per_mille']=200
 (out/impl/'endurance-fixture.json').write_text(json.dumps(fixture,indent=2)+'\n')
 p=project/'scripts/comparison_mixed.odin';s=p.read_text().replace('mode:u8}', 'mode:u8,taps:u8,salt:u32,shots:i64}')
 s=s.replace('mode=u8(player.weapon.mode)}', 'mode=u8(player.weapon.mode),taps=player.weapon.taps,salt=player.weapon.salt,shots=-1}') if baseline else s.replace('mode=u8(player.gun.mode)}','mode=u8(player.gun.mode),taps=player.gun.taps,salt=player.gun.salt,shots=i64(player.shots)}')
 s=s.replace('case "burn":', 'case "salt":return gd.Int(player.salt);case "taps":return gd.Int(player.taps);case "shots":return gd.Int(player.shots);case "burn":',1)
 if baseline:
  s+='''
compare_pull_counts:[2][6]u32
compare_pull_note :: proc(by:u64,pull:u8) {if by>=1 && by<=2 && pull<6 {compare_pull_counts[by-1][pull]+=1}}
@(gd_method)
scrapyard_compare_pull :: proc(self:^Scrapyard,seat,pull:gd.Int)->gd.Int {return seat>=1 && seat<=2 && pull>=0 && pull<6 ? gd.Int(compare_pull_counts[seat-1][pull]) : -1}
'''
  combat=project/'scripts/combat.odin';text=combat.read_text();needle='\t#partial switch self.weapon.pull {';assert text.count(needle)==1;combat.write_text(text.replace(needle,'\tcompare_pull_note(u64(by),u8(self.weapon.pull))\n'+needle,1))
  s=s.replace('return gd.Int(player.shots)', 'return self.ses.is_host ? gd.Int(compare_pull_counts[seat-1][1]) : -1')
 p.write_text(s);shutil.copy2(here/'driver.gd',project/'comparison.gd')
files=[p for p in out.rglob('*') if p.is_file() and p.suffix in ('.odin','.gd','.tscn','.tres','.png','.wav','.mp3') and not p.name.endswith('.gen.odin')]
(out/'source-sha256.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(out))+'\n' for p in sorted(files)))
shutil.copy2(here/'contract.json',out/'contract.json');print('REPLAY_JAM_PREPARED')
