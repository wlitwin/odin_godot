package replay_action_retire_test

import "core:testing"
import "core:fmt"
import "core:mem"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import view "godot:replay/view"
import f "godot:tests/replay_physics_net/fixture"

Held :: struct {bytes:[]u8,channel:tr.Channel,kind:u16,tick:u64}
collect :: proc(t:^testing.T,p:^Pair,now:u64,out:[]Held)->int{
 testing.expect(t,tr.memory_advance(&p.memory,now));wire:=tr.memory_transport(&p.endpoints[1]);scratch:[tr.MAX_PACKET_BYTES]u8;n:=0
 for n<len(out){
  packet:=tr.receive(&wire,scratch[:]);if packet.state==.Empty{return n};testing.expect_value(t,packet.state,tr.Receive_State.Received);if packet.state!=.Received{return n}
  meta,_,report:=sc.inspect(scratch[:packet.count]);testing.expect_value(t,report.error,sc.Error.None)
  bytes:=make([]u8,packet.count);copy(bytes,scratch[:packet.count]);out[n]={bytes,packet.channel,meta.kind,meta.tick};n+=1
 }
 testing.expect(t,false);return n
}
drop_held :: proc(items:[]Held){for &item in items{delete(item.bytes);item={}}}
deliver :: proc(t:^testing.T,p:^Pair,items:[]Held,kind:u16=0,tick:u64=0){
 sender:=tr.memory_transport(&p.endpoints[0])
 for item in items{if (kind==0||item.kind==kind)&&(tick==0||item.tick==tick){testing.expect_value(t,tr.send(&sender,2,item.channel,item.bytes),tr.Send_Result.Sent)}}
}
receive :: proc(t:^testing.T,p:^Pair,now:u64)->net.Error{testing.expect(t,tr.memory_advance(&p.memory,now));return net.client_pump(&p.client,now)}
host_action :: proc(t:^testing.T,p:^Pair,now:u64,sequence:u64)->u64{
 testing.expect(t,tr.memory_advance(&p.memory,now));if !none(t,net.server_pump(&p.server,now),"receive action")||!none(t,net.server_step(&p.server),"settle action"){return 0}
 tick:=p.server.timeline.head;entry,found:=net.server_accepted_input(&p.server,tick)
 testing.expect(t,found&&entry.batch.has_action[1]&&entry.batch.sequences[1]==sequence&&entry.decisions.applied[1]);return tick
}
request :: proc(t:^testing.T,p:^Pair,tick,sequence,now:u64){
 schema:=&p.server.codecs.request;testing.expect_value(t,schema.wire_size,32)
 bytes:[sc.HEADER_BYTES+32]u8;body:=bytes[sc.HEADER_BYTES:];values:=[4]u64{p.client.generation,p.client.serial,sequence,now}
 for value,index in values{for i in 0..<8{body[index*8+i]=u8(value>>uint(i*8))}}
 testing.expect_value(t,sc.pack_bytes(schema.fingerprint,{kind=31,epoch=p.server.cfg.epoch,tick=tick,content=p.server.cfg.content},body,bytes[:]).error,sc.Error.None)
 remote:=tr.memory_transport(&p.endpoints[1]);testing.expect_value(t,tr.send(&remote,1,.Reliable,bytes[:]),tr.Send_Result.Sent)
 testing.expect(t,tr.memory_advance(&p.memory,now));none(t,net.server_pump(&p.server,now),"public retained request")
}

@(test)
historical_header_does_not_retire_unobserved_future_and_old_headers_are_idempotent :: proc(t:^testing.T){
 p:=new(Pair);defer free(p);defer close(t,p);if !open(t,p){return}
 first,fe:=net.client_issue(&p.client,f.Action{kind=.Motor});if !none(t,fe,"issue1"){return};tick1:=host_action(t,p,17,first)
 old:[64]Held;nold:=collect(t,p,17,old[:]);defer drop_held(old[:nold])
 second,se:=net.client_issue(&p.client,f.Action{kind=.Motor});if !none(t,se,"issue2"){return};future_tick:=p.client.actions[p.client.action_count-1].tick
 tick2:=host_action(t,p,34,second);later:[64]Held;nlater:=collect(t,p,34,later[:]);defer drop_held(later[:nlater])
 request(t,p,tick1,1,34);historical:[64]Held;nh:=collect(t,p,34,historical[:]);defer drop_held(historical[:nh])
 deliver(t,p,old[:nold],30,tick1);deliver(t,p,historical[:nh],28,tick1);if !none(t,receive(t,p,34),"historical full snapshot"){return}
 testing.expect_value(t,p.client.pending.action_settled,second);testing.expect_value(t,p.client.last_outcome,first)
 testing.expect_value(t,p.client.action_count,1);testing.expect_value(t,p.client.actions[0].sequence,second);testing.expect_value(t,p.client.actions[0].tick,future_tick);testing.expect_value(t,p.client.next_action,second)
 if !full_pair(t,p,tick1){return}
 // Repeated valid current-header/historical-image and actual older header1.
 request(t,p,tick1,2,35);repeat:[64]Held;nr:=collect(t,p,35,repeat[:]);defer drop_held(repeat[:nr])
 deliver(t,p,repeat[:nr],28,tick1);none(t,receive(t,p,35),"repeat historical")
 deliver(t,p,old[:nold],28,tick1);none(t,receive(t,p,36),"actual older header")
 testing.expect_value(t,p.client.action_count,1);testing.expect_value(t,p.client.actions[0].sequence,second)
 request(t,p,tick2,3,51);current:[64]Held;nc:=collect(t,p,51,current[:]);defer drop_held(current[:nc])
 deliver(t,p,later[:nlater],30,tick2);deliver(t,p,current[:nc],28,tick2);if !none(t,receive(t,p,51),"future verdict then full snapshot"){return}
 testing.expect_value(t,p.client.action_count,0);testing.expect_value(t,p.client.last_outcome,second);full_pair(t,p,tick2)
 outcomes:[16]net.Action_Outcome;n:=net.client_outcomes(&p.client,outcomes[:]);testing.expect_value(t,n,2);testing.expect_value(t,outcomes[0].sequence,first);testing.expect_value(t,outcomes[1].sequence,second)
 fmt.println("ACTION_RETIRE_CONTROL historical_current_frontier=true future_preserved=true repeated_older_idempotent=true both_outcomes=true")
}

@(test)
undrained_outcomes_keep_the_existing_combined_sixteen_capacity :: proc(t:^testing.T){
 p:=new(Pair);defer free(p);defer close(t,p);if !open(t,p){return};generation,serial:=p.client.generation,p.client.serial
 changes:[512]view.Change(net.Net_Event(f.Event));view.drain(&p.client.journal,changes[:])
 for index in 1..=16{
  sequence,error:=net.client_issue(&p.client,f.Action{kind=.Motor});if !none(t,error,"undrained issue"){return}
  none(t,net.client_step(&p.client,f.Control{}),"undrained predict");now:=u64(index)*17;tick:=host_action(t,p,now,sequence)
  if !none(t,receive(t,p,now),"undrained confirm")||!full_pair(t,p,tick){return};view.drain(&p.client.journal,changes[:])
  testing.expect_value(t,p.client.action_count,0);testing.expect_value(t,p.client.outcome_count,index)
  tr.memory_advance(&p.memory,now);none(t,net.server_pump(&p.server,now),"actual ACK")
 }
 _,blocked:=net.client_issue(&p.client,f.Action{kind=.Motor});testing.expect_value(t,blocked,net.Error.Capacity);testing.expect_value(t,p.client.next_action,u64(16))
 outcomes:[16]net.Action_Outcome;n:=net.client_outcomes(&p.client,outcomes[:]);testing.expect_value(t,n,16)
 for outcome,index in outcomes[:n]{testing.expect(t,outcome.sequence==u64(index+1)&&outcome.applied&&outcome.reason==.None)}
 sequence,error:=net.client_issue(&p.client,f.Action{kind=.Motor});testing.expect_value(t,error,net.Error.None);testing.expect_value(t,sequence,u64(17));testing.expect_value(t,p.client.generation,generation);testing.expect_value(t,p.client.serial,serial)
 fmt.println("ACTION_RETIRE_CONTROL all16_outcomes_preserved=true capacity_until_drain=true issue17_after_drain=true")
}

@(test)
held_partial_malformed_and_wrong_scope_do_not_retire_before_valid_complete_image :: proc(t:^testing.T){
 p:=new(Pair);defer free(p);defer close(t,p);if !open(t,p){return}
 sequence,error:=net.client_issue(&p.client,f.Action{kind=.Motor});if !none(t,error,"held issue"){return};tick:=host_action(t,p,17,sequence)
 packets:[64]Held;n:=collect(t,p,17,packets[:]);defer drop_held(packets[:n])
 deliver(t,p,packets[:n],30,tick);none(t,receive(t,p,17),"facts while image held")
 testing.expect_value(t,p.client.action_count,1)
 parts:=0;for item in packets[:n]{if item.kind==28{parts+=1}}
 // Deliver all but the final ACTUAL fragment;0/N is explicit for a1part image.
 sent:=0;sender:=tr.memory_transport(&p.endpoints[0])
 for item in packets[:n]{if item.kind==28&&sent<parts-1{tr.send(&sender,2,item.channel,item.bytes);sent+=1}}
 none(t,receive(t,p,18),"incomplete actual image");testing.expect_value(t,p.client.action_count,1)
 rejected:=p.client.stats.rejected_packets
 for item in packets[:n]{if item.kind==28{
  bad:=make([]u8,len(item.bytes));copy(bad,item.bytes);bad[len(bad)-1]~=1;tr.send(&sender,2,item.channel,bad);delete(bad);break
 }}
 none(t,receive(t,p,19),"malformed checksum");testing.expect(t,p.client.stats.rejected_packets>rejected);testing.expect_value(t,p.client.action_count,1)
 rejected=p.client.stats.rejected_packets
 for item in packets[:n]{if item.kind==28{
  bad:=make([]u8,len(item.bytes));copy(bad,item.bytes);body:=bad[sc.HEADER_BYTES:];schema:=&p.server.physics.schemas.chunk
  for field in schema.fields{if field.path=="$.generation"{value:=p.client.generation+1;for i in 0..<field.width{body[field.wire_offset+i]=u8(value>>uint(i*8))}}}
  meta,_,_:=sc.inspect(item.bytes);testing.expect_value(t,sc.pack_bytes(schema.fingerprint,meta,body,bad).error,sc.Error.None)
  tr.send(&sender,2,item.channel,bad);delete(bad);break
 }}
 none(t,receive(t,p,20),"wrong generation");testing.expect(t,p.client.stats.rejected_packets>rejected);testing.expect_value(t,p.client.action_count,1)
 deliver(t,p,packets[:n],28,tick);none(t,receive(t,p,21),"valid complete image");testing.expect_value(t,p.client.action_count,0);full_pair(t,p,tick)
 outcomes:[16]net.Action_Outcome;testing.expect_value(t,net.client_outcomes(&p.client,outcomes[:]),1)
 fmt.printf("ACTION_RETIRE_CONTROL incomplete_fragments=%d/%d malformed_reject=true no_early_retire=true final_valid=true\n",sent,parts)
}

@(test)
revision_native_compare_and_presentation_failures_cannot_retire :: proc(t:^testing.T){
 for variant in 0..<5{
  p:=new(Pair);if !open(t,p){close(t,p);free(p);return}
  sequence,error:=net.client_issue(&p.client,f.Action{kind=.Motor});if !none(t,error,"failure issue"){close(t,p);free(p);return}
  if variant==0{p.client.model.step=proc(game:^f.Game,controls:[2]f.Control,joins,leaves:u64,ctx:^r.Step(f.Event)){step(game,controls,joins,leaves,ctx);r.abort(ctx)}}
  if variant==1{p.client.model.step=proc(game:^f.Game,controls:[2]f.Control,joins,leaves:u64,ctx:^r.Step(f.Event)){step(game,controls,joins,leaves,ctx);ph.body_velocity(ctx.execution,game.bodies[0],{1e13,0,0},{})}}
  if variant==2{p.client.model.step=proc(game:^f.Game,controls:[2]f.Control,joins,leaves:u64,ctx:^r.Step(f.Event)){step(game,controls,joins,leaves,ctx);game.rng~=1}}
  if variant==3{changes:[512]view.Change(net.Net_Event(f.Event));view.drain(&p.client.journal,changes[:]);testing.expect_value(t,view.journal_reset(&p.client.journal,2,1),view.Error.None)}
  if variant==4{p.client.model.complete_codec.decode=proc(catalog:rawptr,frame:r.Frame(f.Game),epoch:u64,events:[]r.Occurrence(net.Net_Event(f.Event)),src:[]u8)->(r.Complete_Checkpoint(f.Game,net.Net_Event(f.Event)),net.Error){return {},.Invalid_Frame}}
  rejected:=p.client.stats.rejected_packets;tick:=host_action(t,p,17,sequence);status:=receive(t,p,17)
  testing.expect_value(t,p.client.action_count,1);testing.expect_value(t,p.client.actions[0].sequence,sequence);testing.expect_value(t,p.client.next_action,sequence)
  if variant==2{testing.expect(t,p.client.physics.waiting_tick==tick || p.client.phase==.Failed)}else if variant==4{testing.expect(t,p.client.stats.rejected_packets>rejected)}else{testing.expect(t,status!=.None)}
  if variant==4{
   // The earlier real Physics_Facts already passed complete paired revision.
   // The subsequent image decode fails: preserve BOTH request and owed verdict.
   testing.expect_value(t,p.client.last_outcome,sequence);testing.expect_value(t,p.client.outcome_count,1)
   outcomes:[16]net.Action_Outcome;testing.expect_value(t,net.client_outcomes(&p.client,outcomes[:]),1)
   testing.expect(t,outcomes[0].sequence==sequence&&outcomes[0].applied&&outcomes[0].reason==.None);full_pair(t,p,tick)
  }else{testing.expect_value(t,p.client.last_outcome,u64(0));testing.expect_value(t,p.client.outcome_count,0)}
  fmt.printf("ACTION_RETIRE_CONTROL failure_variant=%d public_status=%v waiting_tick=%d request_preserved=true\n",variant,status,p.client.physics.waiting_tick)
  close(t,p);free(p)
 }
}
