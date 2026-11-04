package replay_bounds_test

import "core:mem"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import game "godot:examples/box3d_common"

@(test)
complete_snapshot_rejects_model_invalid_held_before_publication :: proc(t:^testing.T){
 p:=new(Pair);defer free(p);defer close(t,p);if !open(t,p){return}
 x:Transfer;defer drop_transfer(&x)
 now:=u64(17);tr.memory_advance(&p.memory,now)
 if !none(t,net.server_pump(&p.server,now),"ordinary pump")||!none(t,net.server_step(&p.server),"actual Snapshot step"){return}
 if !collect(t,p,now,&x,.Snapshot){return}
 if !check(t,x.header.generation==p.client.generation&&x.header.serial==p.client.serial,"actual current Snapshot scope"){return}
 if !deliver_original(t,p,&x,false){return};tr.memory_advance(&p.memory,now)
 if !none(t,net.client_pump(&p.client,now),"real signed facts without image"){return};drain(p)
 before:=published(p);original,ce:=r.capture_complete(&p.client.timeline,before.head)
 if !check(t,ce==.None,"original complete recipient5"){return};defer r.complete_checkpoint_destroy(&original)
 source,se:=r.capture_complete(&p.server.timeline,x.meta.tick)
 if !check(t,se==.None,"real authority Native checkpoint"){return};defer r.complete_checkpoint_destroy(&source)
 inspection,ie:=net.complete_inspect(x.bytes,p.codec.value.identity,p.server.cfg.epoch)
 if !none(t,ie,"original complete image inspect"){return}
 metadata:=make([]u8,len(inspection.metadata));defer delete(metadata);copy(metadata,inspection.metadata)
 if !check(t,!game.control_valid(game.Control{x=101}),"schema-valid i16 exceeds actual model control bound"){return}
 if !scalar_mutation(t,&p.server.codecs.snapshot,metadata,"$.held[0].x",i16(101)){return}
 candidate,ee:=net.complete_encode(p.codec.value,&source,.Snapshot,metadata,&p.server.physics.schemas.state,&p.server.physics.schemas.occurrence)
 if !none(t,ee,"public complete candidate encode"){return};defer net.complete_data_destroy(&candidate)
 bad,be:=net.complete_inspect(candidate.bytes,p.codec.value.identity,p.server.cfg.epoch)
 if !none(t,be,"malicious metadata still has valid complete integrity"){return}
 for part in bd.Part{if !check(t,mem.compare(inspection.frame.parts[part],bad.frame.parts[part])==0,"all real canonical5 unchanged by held mutation"){return}}
 packets:Packets;defer drop_packets(&packets);rejected:=p.client.stats.rejected_packets
 if !send_candidate(t,p,&x,&candidate,&packets){return};tr.memory_advance(&p.memory,now)
 none(t,net.client_pump(&p.client,now),"malicious Snapshot public receive")
 _=after_rejected(t,p,before,&original,rejected) // prospective RED; do not skip the valid control
 if !check(t,bd.hash_bytes(x.bytes)==x.hash,"original authority raw image immutable"){return}
 if !deliver_original(t,p,&x,true){return};tr.memory_advance(&p.memory,now)
 if !none(t,net.client_pump(&p.client,now),"unmodified authority Snapshot control"){return}
 if !pair_same(t,p){return};resume(t,p,now+17)
}

@(test)
shared_game_retirement_invariants_reject_before_complete_recovery_publication :: proc(t:^testing.T){
 // Both variants are sent to a real initialized spectator. Even the old RED
 // imports no predicted Game step, so count9 is never sliced/executed.
 for variant in 0..<2 {
  p:=new(Pair);if !open(t,p){close(t,p);free(p);return}
  x:Transfer;now,ready:=new_welcome(t,p,&x)
  if !ready{drop_transfer(&x);close(t,p);free(p);return}
  before:=published(p)
  original,oe:=r.capture_complete(&p.client.timeline,before.head)
  source,se:=r.capture_complete(&p.server.timeline,x.meta.tick)
  if !check(t,oe==.None&&se==.None,"real before/candidate complete Native images"){
   r.complete_checkpoint_destroy(&original);r.complete_checkpoint_destroy(&source);drop_transfer(&x);close(t,p);free(p);return
  }
  inspection,ie:=net.complete_inspect(x.bytes,p.codec.value.identity,p.server.cfg.epoch)
  metadata:=make([]u8,len(inspection.metadata));copy(metadata,inspection.metadata)
  prepared:=none(t,ie,"actual replacement Welcome image")
  if variant==0{
   source.frame.state.retired_count=9
   prepared=scalar_mutation(t,&p.server.codecs.welcome,metadata,"$.frame.state.retired_count",u32(9))&&prepared
  }else{
   source.frame.state.retired_count=1;source.frame.state.retired[0]={shape=0,lifetime=0,tick=source.frame.state.tick}
   prepared=scalar_mutation(t,&p.server.codecs.welcome,metadata,"$.frame.state.retired_count",u32(1))&&prepared
   prepared=scalar_mutation(t,&p.server.codecs.welcome,metadata,"$.frame.state.retired[0].shape",b.Shape_Key(0))&&prepared
   prepared=scalar_mutation(t,&p.server.codecs.welcome,metadata,"$.frame.state.retired[0].lifetime",u64(0))&&prepared
   prepared=scalar_mutation(t,&p.server.codecs.welcome,metadata,"$.frame.state.retired[0].tick",source.frame.state.tick)&&prepared
  }
  candidate,ee:=net.complete_encode(p.codec.value,&source,.Welcome,metadata,&p.server.physics.schemas.state,&p.server.physics.schemas.occurrence)
  prepared=none(t,ee,"typed malicious Game with genuine Native5 encode")&&prepared
  packets:Packets;rejected:=p.client.stats.rejected_packets
  if prepared&&send_candidate(t,p,&x,&candidate,&packets){
   tr.memory_advance(&p.memory,now);none(t,net.client_pump(&p.client,now),"malicious Game Welcome public receive")
   _=after_rejected(t,p,before,&original,rejected)
  }
  // A current bad implementation may have imported the unsafe Game. Do NOT
  // simulate it. A fresh genuine public reconnect/Welcome replaces it first;
  // only afterward is continued valid authority/recipient work exercised.
  testing.expect(t,bd.hash_bytes(x.bytes)==x.hash,"retained original Welcome bytes unchanged")
  drop_packets(&packets);net.complete_data_destroy(&candidate);delete(metadata)
  r.complete_checkpoint_destroy(&source);r.complete_checkpoint_destroy(&original);drop_transfer(&x)
  control:Transfer;later,valid:=new_welcome(t,p,&control)
  if valid&&deliver_original(t,p,&control,true){
   tr.memory_advance(&p.memory,later)
   if none(t,net.client_pump(&p.client,later),"fresh unmodified Welcome control"){pair_same(t,p);resume(t,p,later+17)}
  }
  drop_transfer(&control);close(t,p);free(p)
 }
}
