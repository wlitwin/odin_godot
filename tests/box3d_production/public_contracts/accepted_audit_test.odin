package box3d_production_public_test

import "core:testing"
import audit "godot:examples/replay_box3d_authoring/modules/authoring_demo/accepted_audit"
import rn "godot:replay/net"
import tr "godot:replay/transport"
import v "godot:replay/view"
import pf "godot:tests/replay_physics_net/fixture"
import ar "godot:tests/box3d_soak/replay/action_retire"

@(test)
accepted_audit_canonical_gap_requires_all_actual_anchor_evidence :: proc(t:^testing.T){
 // Pure gate controls; the genuine public Snapshot test binds these fields
 // to real adoption/retention, without manufacturing a Native/history row.
 good:=audit.Snapshot_Evidence{
  previous_catchups=0,current_catchups=1,first=8,last=12,head=12,confirmed=8,final=8,frame_tick=8,
  window_valid=true,frame_found=true,has_input=false,
 }
 gap,ok:=audit.snapshot_gap(2,good)
 testing.expect(t,ok&&gap==(audit.Gap{3,8}))
 invalid:[10]audit.Snapshot_Evidence
 for &e in invalid{e=good}
 invalid[0].current_catchups=0
 invalid[1].previous_catchups=2
 invalid[2].window_valid=false
 invalid[3].last=11
 invalid[4].frame_found=false
 invalid[5].frame_tick=7
 invalid[6].has_input=true
 invalid[7].first=2;invalid[7].frame_tick=2
 invalid[8].final=7
 invalid[9].confirmed=7
 for e in invalid{
  rejected,allowed:=audit.snapshot_gap(2,e)
  testing.expect(t,!allowed&&rejected==(audit.Gap{}),"no counter change/wrong window/nonanchor/unconfirmed evidence cannot authorize an interval")
 }
 rejected,allowed:=audit.snapshot_gap(8,good)
 testing.expect(t,!allowed&&rejected==(audit.Gap{}),"no interval can move a cursor already at or past the anchor")
 unchanged,missing:=audit.record(8,9,false)
 testing.expect_value(t,missing,audit.Error.Missing_Input);testing.expect_value(t,unchanged,u64(8))
}

@(test)
accepted_audit_receipt_origin_requires_matching_whole_typed_batch :: proc(t:^testing.T){
 // Pure metadata gate controls; no Native/history/authority row is fabricated.
 batch:=rn.Batch(i32,u8,2){controls={1,-1},has_action={true,false},actions={7,0},sequences={3,0}}
 testing.expect(t,audit.origin_matches(batch,batch,true))
 testing.expect(t,!audit.origin_matches(batch,batch,false),"missing receipt is origin-unavailable, never an inferred Sample/Held")
 receipt:=batch;receipt.controls[1]=0
 testing.expect(t,!audit.origin_matches(batch,receipt,true))
 receipt=batch;receipt.stamps[0].valid=true
 testing.expect(t,!audit.origin_matches(batch,receipt,true),"typed equality includes stamps without using them to infer origin")
 receipt=batch;receipt.sequences[0]+=1
 testing.expect(t,!audit.origin_matches(batch,receipt,true))
 receipt=batch;receipt.prediction_seat=1
 testing.expect(t,!audit.origin_matches(batch,receipt,true))
 next,error:=audit.record(262,263,true)
 testing.expect_value(t,error,audit.Error.None);testing.expect_value(t,next,u64(263))
 unchanged,missing:=audit.record(262,263,false)
 testing.expect_value(t,missing,audit.Error.Missing_Input);testing.expect_value(t,unchanged,u64(262))
}

@(test)
accepted_audit_initial_and_same_scope_never_skip :: proc(t:^testing.T){
 scope:=audit.Scope{1,1,1,1}
 next,gap,error:=audit.begin({},scope,1,true)
 testing.expect_value(t,error,audit.Error.None)
 testing.expect(t,next==1&&gap==audit.Gap{},"initial baseline is not an accepted input or unavailable interval")
 next,gap,error=audit.begin(scope,scope,244,true)
 testing.expect_value(t,error,audit.Error.None)
 testing.expect(t,next==244&&gap==audit.Gap{},"same scope cannot skip even when authority is far ahead")
}

@(test)
accepted_audit_invalid_or_uncommitted_scope_cannot_move :: proc(t:^testing.T){
 previous:=audit.Scope{1,1,1,1}
 invalid:=[?]audit.Scope{
  {0,1,2,268},{1,0,2,268},{1,1,0,268},{2,1,2,268},
  {1,1,1,268},{1,1,2,239},{1,1,0,268},
 }
 for scope in invalid{
  next,gap,error:=audit.begin(previous,scope,240,true)
  testing.expect(t,error!=.None&&next==240&&gap==audit.Gap{})
 }
 next,gap,error:=audit.begin(previous,{1,1,2,268},240,false)
 testing.expect_value(t,error,audit.Error.Uncommitted_Scope)
 testing.expect(t,next==240&&gap==audit.Gap{})
 next,gap,error=audit.begin({},previous,0,true)
 testing.expect_value(t,error,audit.Error.Invalid_Cursor)
 testing.expect(t,next==0&&gap==audit.Gap{})
}

@(test)
accepted_audit_missing_same_or_post_baseline_is_fatal :: proc(t:^testing.T){
 previous:=audit.Scope{1,1,1,1};current:=audit.Scope{1,1,2,268}
 same,_,same_error:=audit.begin(previous,previous,244,true)
 testing.expect_value(t,same_error,audit.Error.None)
 unchanged,missing:=audit.record(same,245,false)
 testing.expect_value(t,missing,audit.Error.Missing_Input);testing.expect_value(t,unchanged,u64(244))
 next,gap,error:=audit.begin(previous,current,244,true)
 testing.expect_value(t,error,audit.Error.None)
 testing.expect(t,next==268&&gap==(audit.Gap{245,268}))
 unchanged,missing=audit.record(next,269,false)
 testing.expect_value(t,missing,audit.Error.Missing_Input);testing.expect_value(t,unchanged,u64(268))
 unchanged,missing=audit.record(next,270,true)
 testing.expect_value(t,missing,audit.Error.Invalid_Cursor);testing.expect_value(t,unchanged,u64(268))
 observed,ok:=audit.record(next,269,true)
 testing.expect_value(t,ok,audit.Error.None);testing.expect_value(t,observed,u64(269))
}

@(test)
accepted_audit_actual_validated_complete_welcome_bounds_unavailable_span :: proc(t:^testing.T){
 defer cleanup(t)
 pair:=new(ar.Pair);defer free(pair);defer ar.close(t,pair);if !ar.open(t,pair){return}
 c:=&pair.client
 previous:=audit.Scope{c.cfg.epoch,c.generation,c.serial,c.baseline}
 cursor:=c.baseline
 start,gap,error:=audit.begin({},previous,cursor,c.initialized&&c.has_world&&c.phase==.Running)
 testing.expect(t,error==.None&&start==cursor&&gap==audit.Gap{})
 // Reuse the real receiver-discard control from the public H128 regression.
 // No head, scope, history row, recovery flag or payload is assigned.
 receiver:=tr.memory_transport(&pair.endpoints[1]);scratch:[tr.MAX_PACKET_BYTES]u8
 discarded:u64
 for pair.server.timeline.head<160{
  now:=(pair.server.timeline.head+1)*17
  testing.expect(t,tr.memory_advance(&pair.memory,now))
  testing.expect_value(t,rn.server_pump(&pair.server,now),rn.Error.None)
  testing.expect_value(t,rn.server_local(&pair.server,pf.Control{}),rn.Error.None)
  testing.expect_value(t,rn.server_step(&pair.server),rn.Error.None)
  testing.expect(t,tr.memory_advance(&pair.memory,now))
  if pair.server.timeline.head<=129{
   drained:=false
   for _ in 0..<65{
    packet:=tr.receive(&receiver,scratch[:])
    if packet.state==.Empty{drained=true;break}
    testing.expect_value(t,packet.state,tr.Receive_State.Received)
    if packet.state!=.Received{return}
    discarded+=1
   }
   testing.expect(t,drained)
  }
 }
 changes:[320]v.Change(rn.Net_Event(pf.Event))
 for pump in 0..<64{
  now:=u64(3000+pump*25);tr.memory_advance(&pair.memory,now)
  testing.expect_value(t,rn.client_pump(c,now),rn.Error.None);_=v.drain(&c.journal,changes[:])
  tr.memory_advance(&pair.memory,now);testing.expect_value(t,rn.server_pump(&pair.server,now),rn.Error.None)
  if c.phase==.Running&&c.timeline.confirmed>=160{break}
 }
 current:=audit.Scope{c.cfg.epoch,c.generation,c.serial,c.baseline}
 committed:=c.initialized&&c.has_world&&c.phase==.Running&&c.physics!=nil
 if committed{committed=c.physics.accepted.epoch==current.epoch&&c.physics.accepted.baseline==current.baseline}
 testing.expect(t,discarded>0&&committed&&current.baseline>cursor)
 testing.expect(t,current.generation>previous.generation||current.serial>previous.serial)
 next,unavailable,rebase:=audit.begin(previous,current,cursor,committed)
 testing.expect_value(t,rebase,audit.Error.None)
 testing.expect(t,next==current.baseline&&unavailable==(audit.Gap{cursor+1,current.baseline}))
 // The canonical baseline has no accepted-input row. A missing row AFTER it
 // still fails; it is never attributed to the declared unavailable interval.
 _,baseline_found:=rn.accepted_read(&c.physics.accepted,current.baseline)
 _,post_found:=rn.accepted_read(&c.physics.accepted,current.baseline+1)
 testing.expect(t,!baseline_found&&!post_found)
 unchanged,missing:=audit.record(next,current.baseline+1,post_found)
 testing.expect_value(t,missing,audit.Error.Missing_Input);testing.expect_value(t,unchanged,next)
 testing.expect(t,ar.full_pair(t,pair,160),"same actual complete five-part recovery remains required")
}
