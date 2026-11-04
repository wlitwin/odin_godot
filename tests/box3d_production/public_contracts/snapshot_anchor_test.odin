package box3d_production_public_test

import "core:fmt"
import "core:testing"
import r "godot:replay"
import rn "godot:replay/net"
import tr "godot:replay/transport"
import v "godot:replay/view"
import pf "godot:tests/replay_physics_net/fixture"
import ar "godot:tests/box3d_soak/replay/action_retire"
import audit "godot:examples/replay_box3d_authoring/modules/authoring_demo/accepted_audit"

// Standalone real Native/complete-codec/Memory contract, not SDK/Linux cause
// evidence. Only actual packets are held/re-delivered; no private state is set.
@(test)
replay_ordinary_snapshot_anchor_retains_frame_without_generating_input :: proc(t:^testing.T){
 defer cleanup(t)
 p:=new(ar.Pair);defer free(p);defer ar.close(t,p);if !ar.open(t,p){return}
 c:=&p.client
 epoch,generation,serial,baseline:=c.cfg.epoch,c.generation,c.serial,c.baseline
 resyncs,catchups:=c.stats.resyncs,c.stats.snapshot_catchups
 changes:[512]v.Change(rn.Net_Event(pf.Event));_=v.drain(&c.journal,changes[:])
 // Snapshot2 is the first outstanding ordinary image. Its genuine ACK lets
 // the authority publish its current image, just beyond restored client lead.
 target:=c.timeline.head+3
 sequence:u64
 for p.server.timeline.head<target{
  if p.server.timeline.head+1==target{
   issued,error:=rn.client_issue(c,pf.Action{kind=.Motor})
   if !ar.none(t,error,"real target Motor action"){return};sequence=issued
  }
  now:=(p.server.timeline.head+1)*17
  testing.expect(t,tr.memory_advance(&p.memory,now))
  if !ar.none(t,rn.server_pump(&p.server,now),"ordinary authority receive")||
     !ar.none(t,rn.server_step(&p.server),"ordinary authority step"){return}
 }
 accepted,found:=rn.server_accepted_input(&p.server,target)
 testing.expect(t,sequence!=0&&found&&accepted.batch.has_action[1]&&
  accepted.batch.sequences[1]==sequence&&accepted.decisions.applied[1],"real authority action/verdict at target")
 if !found{return}
 first:[64]ar.Held;now:=target*17
 first_count:=ar.collect(t,p,now,first[:]);defer ar.drop_held(first[:first_count])
 old_parts:=0;for packet in first[:first_count]{if packet.kind==28&&packet.tick==2{old_parts+=1}}
 testing.expect(t,old_parts>0,"captured genuine ordinary Snapshot2")
 if old_parts==0{return}
 // Keep the separately sent facts held. The complete image's real accepted
 // window supplies its own validated contiguous facts; nothing is repacked.
 ar.deliver(t,p,first[:first_count],28,2)
 if !ar.none(t,ar.receive(t,p,now),"deliver ordinary Snapshot2"){return}
 _=v.drain(&c.journal,changes[:])
 testing.expect(t,tr.memory_advance(&p.memory,now))
 if !ar.none(t,rn.server_pump(&p.server,now),"actual Snapshot2 ACK"){return}
 current:[64]ar.Held
 current_count:=ar.collect(t,p,now,current[:]);defer ar.drop_held(current[:current_count])
 parts:=0
 for packet in current[:current_count]{if packet.kind==28&&packet.tick==target{
  parts+=1;testing.expect_value(t,packet.channel,tr.Channel.Reliable)
 }}
 testing.expect(t,parts>0,"ordinary authority current Snapshot unlocked by actual ACK")
 before_head,before_confirmed:=c.timeline.head,c.timeline.confirmed
 eligible:=target>before_head&&target>before_confirmed&&target-before_confirmed<=8
 testing.expect(t,eligible,"actual pre-delivery target is ahead of head and within repair8 of confirmed")
 if parts==0||!eligible{return}
 before_catchups:=c.stats.snapshot_catchups
 ar.deliver(t,p,current[:current_count],28,target)
 if !ar.none(t,ar.receive(t,p,now),"deliver genuine just-ahead ordinary Snapshot"){return}
 testing.expect_value(t,c.stats.snapshot_catchups,before_catchups+1)
 testing.expect_value(t,c.stats.snapshot_catchups,catchups+1)
 testing.expect_value(t,c.phase,rn.Phase.Running)
 testing.expect(t,c.cfg.epoch==epoch&&c.generation==generation&&c.serial==serial&&c.baseline==baseline,
  "ordinary canonical adoption does not create a new Welcome scope")
 testing.expect_value(t,c.stats.resyncs,resyncs)
 frame,frame_found:=r.read_values(&c.timeline,target)
 _,input_found:=r.read_input(&c.timeline,target)
 first_tick,last_tick,window_error:=r.history_window(&c.timeline)
 testing.expect(t,frame_found&&frame.tick==target&&!input_found,
  "a genuine retained confirmed canonical anchor has no generating Timeline input")
 testing.expect(t,c.timeline.confirmed>=target&&window_error==.None&&first_tick==target&&last_tick==c.timeline.head)
 interval,unavailable:=audit.snapshot_gap(before_confirmed,audit.Snapshot_Evidence{
  previous_catchups=before_catchups,current_catchups=c.stats.snapshot_catchups,
  first=first_tick,last=last_tick,head=c.timeline.head,confirmed=c.timeline.confirmed,final=target,frame_tick=frame.tick,
  window_valid=window_error==.None,frame_found=frame_found,has_input=input_found,
 })
 testing.expect(t,unavailable&&interval==(audit.Gap{before_confirmed+1,target}),
  "only the genuine adopted anchor evidence permits declaring this unauditable interval")
 _,post_anchor:=audit.snapshot_gap(target,audit.Snapshot_Evidence{
  previous_catchups=before_catchups,current_catchups=c.stats.snapshot_catchups,
  first=first_tick,last=last_tick,head=c.timeline.head,confirmed=c.timeline.confirmed,final=target,frame_tick=frame.tick,
  window_valid=window_error==.None,frame_found=frame_found,has_input=input_found,
 })
 testing.expect(t,!post_anchor,"the same real evidence cannot cover any post-anchor missing input")
 testing.expect(t,ar.full_pair(t,p,target),"actual complete five-part state matches at canonical anchor")
 // The target's nonempty Action_Result is delivered once, including across
 // repetition of the same real image. No application ACK/outcome is invented.
 count:=v.drain(&c.journal,changes[:]);confirmed_results:=0
 for change in changes[:count]{
  event:=change.occurrence.value
  if change.confirmed&&event.kind==.Action_Result&&event.sequence==sequence{
   confirmed_results+=1;testing.expect(t,event.applied&&event.reason==.None&&change.occurrence.id.tick==target)
  }
 }
 testing.expect_value(t,confirmed_results,1)
 outcomes:[rn.ACTION_CAPACITY]rn.Action_Outcome
 outcome_count:=rn.client_outcomes(c,outcomes[:])
 testing.expect(t,outcome_count==1&&outcomes[0].sequence==sequence&&outcomes[0].tick==target&&outcomes[0].applied)
 ar.deliver(t,p,current[:current_count],28,target)
 if !ar.none(t,ar.receive(t,p,now),"repeat actual ordinary Snapshot"){return}
 count=v.drain(&c.journal,changes[:])
 for change in changes[:count]{
  event:=change.occurrence.value
  testing.expect(t,!(change.confirmed&&event.kind==.Action_Result&&event.sequence==sequence),"no duplicate confirmed effect")
 }
 testing.expect_value(t,rn.client_outcomes(c,outcomes[:]),0)
 testing.expect_value(t,c.stats.snapshot_catchups,before_catchups+1)
 // Bootstrap itself may already have simulated target+1. Also perform a new
 // real public step and inspect its actual retained input, never a fake row.
 _,following_found:=r.read_input(&c.timeline,target+1)
 testing.expect(t,following_found,"next actual bootstrap step owns a generating input")
 next:=c.timeline.head+1
 if !ar.none(t,rn.client_step(c,pf.Control{}),"next actual public client step"){return}
 _,next_found:=r.read_input(&c.timeline,next)
 testing.expect(t,c.timeline.head==next&&next_found)
 testing.expect(t,ar.full_pair(t,p,target),"later prediction preserves the complete confirmed anchor")
 testing.expect(t,tr.memory_advance(&p.memory,now))
 if !ar.none(t,rn.server_pump(&p.server,now),"actual target Snapshot ACK"){return}
 testing.expect(t,c.cfg.epoch==epoch&&c.generation==generation&&c.serial==serial&&c.baseline==baseline)
 fmt.printf("PUBLIC_REPLAY_ANCHOR target=%d before_head=%d before_confirmed=%d catchups_before=%d catchups_after=%d epoch=%d generation=%d serial=%d baseline=%d frame_found=%v input_found=%v history_first=%d next_input=%v confirmed_results=%d full5=true\n",
  target,before_head,before_confirmed,before_catchups,c.stats.snapshot_catchups,epoch,generation,serial,baseline,frame_found,input_found,first_tick,next_found,confirmed_results)
}
