package cave_rocks_test

import "core:reflect"
import "core:testing"
import r "godot:replay"
import base "godot:examples/replay_cavecrawl/shared/cave"
import owner "godot:examples/replay_cavecrawl/shared/owner_cave"
import draw "godot:examples/replay_cavecrawl/shared/presentation"

@(test)
rock_preview_is_frame_rate_motion_with_no_gameplay_writes :: proc(t:^testing.T) {
 w:=base.initial()
 _,ok:=r.pool_insert(&w.rocks,base.Rock{position={100,100},velocity={12,0},left=24,shooter=1});assert(ok)
 before:=w
 for i in 0..=6 {
  phase:=f32(i)/6
  testing.expect_value(t,draw.rock_position(&w,0,phase,base.BODY_RADIUS),([2]f32{100+12*phase,100}))
 }
 testing.expect_value(t,draw.rock_position(&w,0,3,base.BODY_RADIUS),([2]f32{112,100}))
 testing.expect(t,reflect.equal(w,before))
}

@(test)
preview_stops_at_nearest_visible_body_and_ignores_shooter_and_corpses :: proc(t:^testing.T) {
 w:=base.initial()
 _,ok:=r.pool_insert(&w.rocks,base.Rock{position={100,100},velocity={12,0},left=24,shooter=1});assert(ok)
 w.players[0]={connected=true,hp=100,position={100,100}}
 w.players[1]={connected=true,hp=0,position={100,100}}
 testing.expect_value(t,draw.rock_position(&w,0,1,base.BODY_RADIUS),([2]f32{112,100}))
 w.players[1].hp=100;w.players[1].position={120,100}
 testing.expect_value(t,draw.rock_position(&w,0,1,base.BODY_RADIUS),([2]f32{106,100}))
 _,ok=r.pool_insert(&w.dwellers,base.Dweller{position={116,100},home={116,100},hp=70});assert(ok)
 before:=w
 testing.expect_value(t,draw.rock_position(&w,0,1,base.BODY_RADIUS),([2]f32{102,100}))
 testing.expect(t,reflect.equal(before,w))
 // Owner-controlled positions use the same copied-value presentation contract.
 o:=owner.initial();o.cave=w
 testing.expect_value(t,draw.rock_position(&o,0,1,base.BODY_RADIUS),([2]f32{102,100}))
 testing.expect(t,reflect.equal(o.cave,before))
}

@(test)
removed_and_recycled_rocks_do_not_retain_a_previous_visual_trajectory :: proc(t:^testing.T) {
 w:=base.initial()
 first,ok:=r.pool_insert(&w.rocks,base.Rock{position={100,100},velocity={12,0},left=24,shooter=1});assert(ok)
 testing.expect_value(t,draw.rock_position(&w,int(first.index),.5,base.BODY_RADIUS),([2]f32{106,100}))
 r.pool_remove(&w.rocks,first)
 testing.expect_value(t,draw.rock_position(&w,int(first.index),.5,base.BODY_RADIUS),([2]f32{}))
 second,spawned:=r.pool_insert(&w.rocks,base.Rock{position={300,200},velocity={0,-12},left=24,shooter=1});assert(spawned)
 testing.expect(t,second.index==first.index && second.generation!=first.generation)
 testing.expect_value(t,draw.rock_position(&w,int(second.index),.5,base.BODY_RADIUS),([2]f32{300,194}))
 // A corrected source position replaces its preview directly; the helper owns
 // no hidden integration state capable of continuing the abandoned trajectory.
 w.rocks.values[second.index].position={310,210}
 testing.expect_value(t,draw.rock_position(&w,int(second.index),.5,base.BODY_RADIUS),([2]f32{310,204}))
}
