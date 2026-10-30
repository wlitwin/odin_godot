package replay_scrapyard_test

import "core:testing"
import "core:math"
import "core:reflect"
import r "godot:replay"
import sc "godot:replay/schema"
import net "godot:replay/net"
import game "godot:examples/replay_scrapyard/shared/game"
import flow "godot:examples/replay_scrapyard/shared/flow"
import upgrade "godot:examples/replay_scrapyard/shared/upgrade"

@(test)
spread_records_actual_hops_credit_and_payload_before_reentry :: proc(t:^testing.T) {
 w:=yard();w.clock=10;game.spawn_mob(&w,1,{700,900});game.spawn_mob(&w,1,{740,900})
 ctx:=r.Step(game.Event){tick=10,epoch=1};notices:game.Notices
 game.apply_status(&w,game.mob_target(&w,0),1,{1,1},&notices,&ctx)
 game.apply_status(&w,game.mob_target(&w,0),6,{1,1},&notices,&ctx)
 count:=0;found:=false
 for alive,i in w.flashes.alive {if alive && w.flashes.values[i].kind==.Arc {
  f:=w.flashes.values[i];count+=1
  testing.expect_value(t,f.origin,([2]f32{700,900}));testing.expect_value(t,f.status,u8(6));testing.expect_value(t,f.seat,u16(1));testing.expect_value(t,f.generation,u32(1));testing.expect_value(t,f.until,u64(27))
  if f.end==([2]f32{740,900}) {found=true}
 }}
 testing.expect(t,count>=2 && found && game.state_valid(w))
 before:=w;game.flash_step(&w,27);testing.expect_value(t,w.flashes.count,u32(0))
 testing.expect(t,reflect.equal(w.mobs,before.mobs) && reflect.equal(w.players,before.players))
}
@(test)
cast_paths_match_original_fan_and_kink_with_degenerate_guards :: proc(t:^testing.T) {
 origin:=[2]f32{100,200};end:=[2]f32{250,200}
 first,ok:=flow.flame_position(origin,end,10,27,0);testing.expect(t,ok);testing.expect_value(t,first,([2]f32{118,200}))
 next,visible:=flow.flame_position(origin,end,14,27,0);testing.expect(t,visible);testing.expect_value(t,next,([2]f32{158,200}))
 left,_:=flow.flame_position(origin,end,10,27,-2);right,_:=flow.flame_position(origin,end,10,27,2)
 testing.expect(t,math.abs(left[0]-right[0])<0.001 && math.abs(left[1]+right[1]-400)<0.001)
 _,expired:=flow.flame_position(origin,end,25,27,0);testing.expect(t,!expired)
 _,degenerate:=flow.flame_position(origin,origin,10,27,0);testing.expect(t,!degenerate)
 polygon,draw:=flow.arc_polygon(origin,end);testing.expect(t,draw)
 expected:=[8][2]f32{{0,2},{50,9},{100,-5},{150,2},{150,-2},{100,-9},{50,5},{0,-2}}
 testing.expect_value(t,polygon,expected)
 _,zero:=flow.arc_polygon(origin,origin);testing.expect(t,!zero)
}
@(test)
frozen_world45_maps_canonical_values_and_rejects_new_arc_discriminator :: proc(t:^testing.T) {
 #assert(size_of(upgrade.World_45)==size_of(upgrade.World_48))
 #assert(align_of(upgrade.World_45)==align_of(game.World))
 w:=yard();w.catalog=upgrade.catalog_current(upgrade.stock_49());w.clock=10
 game.flash_add(&w,{kind=.Cast,ability=4,status=4,seat=1,generation=1,serial=1,origin={700,900},until=27},&r.Step(game.Event){})
 old:=transmute(upgrade.World_45)upgrade.world_48(w);mapped,ok:=upgrade.map_world(old);testing.expect(t,ok && reflect.equal(w,mapped))
 a,b:sc.Schema;defer sc.destroy(&a);defer sc.destroy(&b)
 testing.expect_value(t,sc.init(&a,upgrade.World_45).error,sc.Error.None);testing.expect_value(t,sc.init(&b,upgrade.World_49).error,sc.Error.None)
 testing.expect(t,a.fingerprint!=b.fingerprint && a.wire_size+8==b.wire_size)
 left:=make([]u8,a.wire_size);defer delete(left);right:=make([]u8,b.wire_size);defer delete(right)
 testing.expect_value(t,sc.encode(&a,old,left).error,sc.Error.None);testing.expect_value(t,sc.encode(&b,upgrade.world_49(mapped),right).error,sc.Error.None)
 testing.expect(t,reflect.equal(left,right[:len(left)],true) && reflect.equal(right[len(left):],([]u8{0,0,0,0,0,0,0,0}),true))
 old.flashes.values[0].kind=upgrade.Flash_45_Kind(5)
 _,valid:=upgrade.map_world(old);testing.expect(t,!valid)
}

@(test)
spread_hops_survive_checkpoint_restore_and_expire_without_changing_targets :: proc(t:^testing.T) {
 w:=yard();game.spawn_mob(&w,1,{700,900});game.spawn_mob(&w,1,{740,900})
 ctx:=r.Step(game.Event){epoch=1};notices:game.Notices
 game.apply_status(&w,game.mob_target(&w,0),1,{1,1},&notices,&ctx)
 game.apply_status(&w,game.mob_target(&w,0),6,{1,1},&notices,&ctx)
 s,resumed:net.Server(game.World,game.Control,game.Action,game.Event,game.SEATS);defer net.server_destroy(&s);defer net.server_destroy(&resumed)
 model:=game.model();model.reset_player=nil;cfg:=net.DEFAULT_CONFIG;cfg.content=game.CONTENT
 testing.expect_value(t,net.server_init(&s,r.Frame(game.World){state=w},model,{},cfg,local_seat=1),net.Error.None);net.server_set_local_token(&s,net.Token{0=55})
 cp,decoded:net.Checkpoint(game.World,game.Control,game.Action,game.SEATS);defer net.checkpoint_destroy(&cp);defer net.checkpoint_destroy(&decoded)
 testing.expect_value(t,net.checkpoint_capture(&s,&cp),net.Error.None)
 bytes,err:=net.checkpoint_encode(&cp,model);defer delete(bytes);testing.expect_value(t,err,net.Error.None)
 testing.expect_value(t,net.checkpoint_decode(&decoded,bytes,model,game.CONTENT),net.Error.None)
 testing.expect(t,reflect.equal(decoded.frame.state.flashes,w.flashes))
 testing.expect_value(t,net.server_restore(&resumed,&decoded,model,{}, {epoch=2,local_seat=1}),net.Error.None)
	before,_:=r.current(&resumed.timeline);testing.expect(t,reflect.equal(before,decoded.frame))
	reference_authority_epoch(&s,2)
 for _ in 0..<20 {testing.expect_value(t,net.server_step(&s),net.Error.None);testing.expect_value(t,net.server_step(&resumed),net.Error.None)}
 a,_:=r.current(&s.timeline);b,_:=r.current(&resumed.timeline)
 testing.expect(t,reflect.equal(a,b) && a.state.flashes.count==0)
}

@(test)
flame_correction_replacement_does_not_inherit_a_stopped_tongue :: proc(t:^testing.T) {
 track:flow.Flame_Track;key:=flow.Flame_Key{1,27,1,1,1,{100,200},{250,200}}
 testing.expect(t,flow.flame_reconcile(&track,key,12,true));track.stopped[2]=true
 testing.expect(t,!flow.flame_reconcile(&track,key,13,true) && track.stopped[2])
 key.serial=2;key.until=28
 testing.expect(t,flow.flame_reconcile(&track,key,13,true) && !track.stopped[2])
 track.stopped[2]=true;key.origin[1]+=2
 testing.expect(t,flow.flame_reconcile(&track,key,14,true) && !track.stopped[2])
 track.stopped[2]=true
 testing.expect(t,flow.flame_reconcile(&track,key,12,true) && !track.stopped[2])
 track.stopped[2]=true
 testing.expect(t,flow.flame_reconcile(&track,key,12,false) && !track.seeded && !track.stopped[2])
}

@(test)
arc_instance_axes_preserve_the_existing_polygon_for_reused_view_slots :: proc(t:^testing.T) {
 unit,valid:=flow.arc_polygon({}, {1,0});testing.expect(t,valid)
 origin:=[2]f32{250,-170}
 for delta in ([7][2]f32{{1,0},{0,1},{-200,0},{0,-400},{20,30},{-30,20},{800,-700}}) {
  expected,draw:=flow.arc_polygon(origin,origin+delta);x,y,ready:=flow.arc_axes(origin,origin+delta);testing.expect(t,draw && ready)
  for scale in ([3]f32{0.25,1,1.4}) {
   for point,i in unit {
    actual:=(x*point[0]+y*point[1])*scale
    for axis in 0..<2 {testing.expect(t,abs(actual[axis]-expected[i][axis]*scale)<0.0002)}
   }
  }
 }
 for delta in ([3][2]f32{{},{0.5,0},{0.1,0.2}}) {_,_,ready:=flow.arc_axes(origin,origin+delta);testing.expect(t,!ready)}
}
