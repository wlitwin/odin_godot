"""Trace current dash actions by sequence in isolated diagnostic copies."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve()
profile=os.environ.get('REPLAY_INPUT_AUDIT_PROFILE','endurance');assert profile in ('endurance','jam')
shots=os.environ.get('REPLAY_INPUT_AUDIT_SHOTS','0')=='1'
subprocess.run([sys.executable,str(root/f'tests/replay_{profile}_comparison/prepare.py'),str(out)],check=True)
framework=out/'framework';framework.mkdir()
for p in root.iterdir():
 if not p.name.startswith('.') and p.name!='replay':(framework/p.name).symlink_to(p,target_is_directory=p.is_dir())
shutil.copytree(root/'replay',framework/'replay');changes={}
def edit(name,old,new):
 p=out/name;before=p.read_text();assert before.count(old)==1,(name,old)
 after=before.replace(old,new,1);p.write_text(after)
 changes.setdefault(name,{'before':hashlib.sha256(before.encode()).hexdigest()})['after']=hashlib.sha256(after.encode()).hexdigest()

name='replay/project/scripts/comparison_mixed.odin'
edit(name,'package replay_scrapyard','package replay_scrapyard\nimport net "godot:replay/net"')
edit(name,'replay_scrapyard_compare_dash :: proc(self:^ReplayScrapyard) {compare_dash_pending=true}',
     'replay_scrapyard_compare_dash :: proc(self:^ReplayScrapyard) {compare_dash_pending=true;net.input_audit_note(.Request,0,0,gd.time_get_ticks_msec(gd.singleton_time()))}')
name='replay/project/scripts/dash.odin'
edit(name,'\tself.dash_next=false\n\tself.buttons.pressed','\tnet.input_audit_note(.Queued,0,0,gd.time_get_ticks_msec(gd.singleton_time()),sequence)\n\tself.dash_next=false\n\tself.buttons.pressed')
name='replay/project/scripts/scrapyard.odin';marker='replay_scrapyard_exit_tree :: proc(self: ^ReplayScrapyard) {'
edit(name,marker,marker+'net.input_audit_dump();')
marker='rgd.intent_observe(&self.dash_intent[0],self.session,change)'
edit(name,marker,'if '+marker+' {net.input_audit_note(.Result,0,0,gd.time_get_ticks_msec(gd.singleton_time()),event.sequence,u64(event.applied),u64(event.reason))}')
name='framework/replay/net/client.odin'
marker='== .Sent {action.sent = true} else {break}'
edit(name,marker,'== .Sent {action.sent = true;input_audit_note(.Action_Sent,c.seat,action.tick,c.now,action.sequence)} else {break}')
name='framework/replay/net/server.odin'
marker='\t\tpeer.last_seen = s.now\n\t\tif packet.sequence <= peer.action_received'
edit(name,marker,'\t\tinput_audit_note(.Arrival,peer.seat,packet.tick,s.now,packet.sequence,s.timeline.head)\n'+marker)
marker='peer.action_received = packet.sequence'
edit(name,marker,marker+'\n\t\tinput_audit_note(.Admitted,peer.seat,due,s.now,packet.sequence,packet.tick,u64(reason))')
marker='peer.action_settled = event.sequence'
edit(name,marker,marker+'\n\t\t\tinput_audit_note(.Settled,event.seat,tick,s.now,event.sequence,u64(event.applied),u64(event.reason))')
if shots:
 name='replay/project/shared/game/combat.odin'
 marker='\t\tplayer.shots += 1'
 edit(name,marker,marker+'\n\t\tnet.input_audit_note(.Shot_Born,seat,ctx.tick,0,u64(shot.generation)<<32|u64(shot.serial),u64(shot.damage),u64(def.family))')
 marker='\t\tif target >= 0 {damage_mob(w, target, shot^, feedback, ctx)}'
 edit(name,marker,'\t\thp_before:u16;if target>=0 {hp_before=w.mobs.values[target].hp}\n'+marker)
 marker='\t\t\tr.pool_remove(&w.shots, r.Handle(Shot){u32(i), w.shots.generations[i]})'
 edit(name,marker,'\t\t\thp_after:u16;if target>=0 {hp_after=w.mobs.values[target].hp}\n\t\t\tnet.input_audit_note(.Shot_End,shot.seat,ctx.tick,0,u64(shot.generation)<<32|u64(shot.serial),target>=0 ? 2 : blocked ? 1 : 0,u64(hp_before)<<32|u64(hp_after))\n'+marker)
helper=framework/'replay/net/input_audit.odin';shutil.copy2(Path(__file__).with_name('buffer.odin'),helper)
changes[str(helper.relative_to(out))]={'before':None,'after':hashlib.sha256(helper.read_bytes()).hexdigest()}
(out/'audit-manifest.json').write_text(json.dumps({'kind':'actions','shots':shots,'profile':profile,'original_root':str(root),'collection':str(framework),'changes':changes,'scope':'Bounded buffered request/queue/send/admission/committed outcome records and optional ballistic impact records in copied source; not a performance result.'},indent=2)+'\n')
print('REPLAY_ACTION_INPUT_AUDIT_PREPARED')
