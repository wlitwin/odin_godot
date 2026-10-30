from pathlib import Path
import hashlib,json,re,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];here=Path(__file__).resolve().parent;out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'tests/replay_mixed_comparison/prepare.py'),str(out)],check=True)
shutil.copy2(out/'contract.json',out/'mixed-preparation-contract.json')
for impl in ('kit','replay'):
 project=out/impl/'project';baseline=impl=='kit';prefix='scrapyard' if baseline else 'replay_scrapyard';typ='Scrapyard' if baseline else 'ReplayScrapyard'
 resource=project/'data/guns/bolter.tres';before=resource.read_text();after,n=re.subn(r'^mag = \d+$','mag = 8',before,flags=re.M);assert n==1;resource.write_text(after)
 (out/impl/'endurance-fixture.json').write_text(json.dumps({'data/guns/bolter.tres':{'before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':hashlib.sha256(after.encode()).hexdigest(),'setting':{'mag':8}}},indent=2)+'\n')
 if not baseline:
  model=project/'shared/game/game.odin';before_model=model.read_text();after_model=before_model.replace('return {step_view = step_view, action = action,','return {action_timing = .Receipt, step_view = step_view, action = action,',1);assert after_model!=before_model;assert 'action_schedule = dash_schedule(),' in after_model;after_model=after_model.replace('action_schedule = dash_schedule(),','action_schedule = {},',1);model.write_text(after_model)
  (out/impl/'action-policy.json').write_text(json.dumps({'policy':'Receipt','before_sha256':hashlib.sha256(before_model.encode()).hexdigest(),'after_sha256':hashlib.sha256(after_model.encode()).hexdigest()},indent=2)+'\n')
 p=project/'scripts/comparison_mixed.odin';s=p.read_text();s=s.replace('rally:bool}', 'rally:bool,burn,salve,surge:bool,dashes:u32,mode:u8}')
 s=s.replace('compare_chilled:u32','compare_chilled:u32\ncompare_dash_pending:bool\ncompare_hazard_pending:u8\ncompare_hazards_sent,compare_hazards_refused:u32')
 if baseline:
  s=s.replace('abilities={player.ab_l,player.ab_r}}','abilities={player.ab_l,player.ab_r},dashes=u32(player.dash_seq),mode=u8(player.weapon.mode)}')
  s=s.replace('if fx.kind==4 && fx.left>0 {compare_people[i].rally=true}', 'if fx.kind==4 && fx.left>0 {compare_people[i].rally=true};if fx.kind==2 && fx.left>0 {compare_people[i].burn=true};if fx.kind==5 && fx.left>0 {compare_people[i].salve=true};if fx.kind==8 && fx.left>0 {compare_people[i].surge=true}')
  hazard='''if self.ses.is_host {for seat in 1..=2 {if player,ok:=runner_of(self,kn.Player_Id(seat));ok {runner_apply_status(self,player,compare_hazard_pending,1);compare_hazards_sent+=1} else {compare_hazards_refused+=1}}}'''
  p2=project/'scripts/input.odin';input_text=p2.read_text();needle='if !want || r.health.hp == 0 {return}';assert input_text.count(needle)==1;input_text=input_text.replace(needle,'want = want || compare_dash_pending\n compare_dash_pending=false\n '+needle);p2.write_text(input_text)
 else:
  s=s.replace('gd.Int(compare_move[1]),false)', 'gd.Int(compare_move[1]),compare_dash_pending);compare_dash_pending=false')
  s=s.replace('abilities=player.profile.abilities}', 'abilities=player.profile.abilities,dashes=player.dashes,mode=u8(player.gun.mode)}')
  s=s.replace('if fx.kind==4 && fx.left>0 {compare_people[i].rally=true}', 'if fx.kind==4 && fx.left>0 {compare_people[i].rally=true};if fx.kind==2 && fx.left>0 {compare_people[i].burn=true};if fx.kind==5 && fx.left>0 {compare_people[i].salve=true};if fx.kind==8 && fx.left>0 {compare_people[i].surge=true}')
  hazard='''if self.session.authority {for seat in 1..=2 {if replay_scrapyard_dev_status(self,gd.Int(seat),gd.Int(compare_hazard_pending))>0 {compare_hazards_sent+=1} else {compare_hazards_refused+=1}}}'''
 s=s.replace('compare_cast_pending=0','compare_cast_pending=0\n if compare_hazard_pending!=0 {'+hazard+';compare_hazard_pending=0}')
 flow='if key=="stalls" {return 0};if key=="catchups" {return 0}' if baseline else 'if key=="stalls" {return gd.Int(self.session.client.stats.stalls)};if key=="catchups" {return gd.Int(self.session.client.stats.snapshot_catchups)}'
 s=s.replace('if key=="chilled" {return gd.Int(compare_chilled)}',flow+'\n if key=="chilled" {return gd.Int(compare_chilled)}')
 s=s.replace('if key=="chilled" {return gd.Int(compare_chilled)}', 'if key=="chilled" {return gd.Int(compare_chilled)}\n if key=="hazards_sent" {return gd.Int(compare_hazards_sent)}\n if key=="hazards_refused" {return gd.Int(compare_hazards_refused)}')
 s=s.replace('case "rally":return gd.Int(player.rally);', 'case "burn":return gd.Int(player.burn);case "salve":return gd.Int(player.salve);case "surge":return gd.Int(player.surge);case "dashes":return gd.Int(player.dashes);case "mode":return gd.Int(player.mode);case "rally":return gd.Int(player.rally);')
 if baseline:
  s=s.replace('compare_cast_pending:u8','compare_cast_pending:u8\nCompare_Cast_Receipt :: struct {slot:u8,outcome:kn.Action_Outcome,seen,submitted:bool}\ncompare_cast_receipts:[4]Compare_Cast_Receipt\ncompare_cast_count:int\ncompare_cast_observed:kn.Action_Outcome\ncompare_cast_observed_valid:bool\ncompare_prediction_refused:[2]u32')
  s=s.replace('accepted:=slot==0 ?', 'compare_cast_observed={};compare_cast_observed_valid=false\n  accepted:=slot==0 ?')
  old='if accepted {compare_cast_sent[slot]+=1} else {compare_cast_refused[slot]+=1}'
  new="""submitted:=compare_cast_observed_valid && (compare_cast_observed.seq!=0 || compare_cast_observed.state==.Applied)
  if submitted {compare_cast_sent[slot]+=1} else {compare_cast_refused[slot]+=1}
  if submitted && !accepted {compare_prediction_refused[slot]+=1}
  if compare_cast_count<len(compare_cast_receipts) {compare_cast_receipts[compare_cast_count]={u8(slot),compare_cast_observed,compare_cast_observed_valid,submitted};compare_cast_count+=1}"""
  assert old in s;s=s.replace(old,new)
  s+="""
compare_cast_observe :: proc(outcome:kn.Action_Outcome) {compare_cast_observed=outcome;compare_cast_observed_valid=true}
@(gd_method)
scrapyard_compare_cast_receipt :: proc(self:^Scrapyard,key:string,index:gd.Int)->gd.Int {
 if key=="count" {return gd.Int(compare_cast_count)}
 if index<0 || index>=gd.Int(compare_cast_count) {return -1}
 receipt:=compare_cast_receipts[index]
 switch key {case "slot":return gd.Int(receipt.slot);case "seen":return gd.Int(receipt.seen);case "submitted":return gd.Int(receipt.submitted);case "state":return gd.Int(receipt.outcome.state);case "reason":return gd.Int(receipt.outcome.reason);case "sequence":return gd.Int(receipt.outcome.seq);case "model":return gd.Int(receipt.outcome.model)}
 return -1
}
"""
  combat=project/'scripts/combat.odin';text=combat.read_text()
  for verb,args in [('slime','tx, ty'),('ignite','dx, dy')]:
   before=f'if !knet.command_ok(runner_{verb}_cast_cmd(&self.boot, r, {args}, r.x, r.y)) {{return false}}'
   after=f'outcome := runner_{verb}_cast_cmd(&self.boot, r, {args}, r.x, r.y)\n\tcompare_cast_observe(outcome)\n\tif !knet.command_ok(outcome) {{return false}}'
   assert text.count(before)==1;text=text.replace(before,after)
  combat.write_text(text)
 s+=f'''\n@(gd_method)
{prefix}_compare_dash :: proc(self:^{typ}) {{compare_dash_pending=true}}
@(gd_method)
{prefix}_compare_hazard :: proc(self:^{typ},status:gd.Int) {{if status==2 || status==5 {{compare_hazard_pending=u8(status)}}}}
''';p.write_text(s)
 shutil.copy2(here/'driver.gd',project/'comparison.gd')
files=[p for p in out.rglob('*') if p.is_file() and p.suffix in ('.odin','.gd','.tscn','.tres','.png','.wav','.mp3') and not p.name.endswith('.gen.odin')]
(out/'source-sha256.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(out))+'\n' for p in sorted(files)))
shutil.copy2(here/'contract.json',out/'contract.json');print('REPLAY_ENDURANCE_PREPARED')
