package common_bounds_test

import "core:testing"
import b "godot:box3d"
import common "godot:examples/box3d_common"
import adapter "godot:examples/replay_box3d/shared/adapter"
import fixture "godot:tests/box3d_slices/common"

cleanup :: proc(t:^testing.T){
 native,ns:=b.engine_allocation_stats();wrapper,ws:=b.snapshot_allocation_stats()
 testing.expect_value(t,ns,b.Status.Ok);testing.expect_value(t,ws,b.Status.Ok)
 testing.expect_value(t,native.live_bytes,u64(0));testing.expect_value(t,wrapper.live_bytes,u64(0))
}

@(test)
shared_game_structure_rejects_unsafe_counts_and_incoherent_bindings :: proc(t:^testing.T){
 defer cleanup(t)
 world,game,status:=common.world(4,42);testing.expect_value(t,status,b.Status.Ok);if status!=.Ok{return};defer b.world_destroy(&world)
 testing.expect(t,common.game_valid(game))
 codec:adapter.Codec;model:=adapter.model(&codec)
 for variant in 0..<19{
  bad:=game
  switch variant{
  case 0:bad.retired_count=9
  case 1:bad.initial=0
  case 2:bad.initial=33
  case 3:bad.rng=0
  case 4:bad.next_event=0
  case 5:bad.next_lifetime=u64(game.initial)
  case 6:bad.floor=0
  case 7:bad.sensor=bad.floor
  case 8:bad.sensor_shape=0
  case 9:bad.joint=0
  case 10:bad.alive[0]=false
  case 11:bad.bodies[0]=0
  case 12:bad.shapes[0]=0
  case 13:bad.lifetimes[0]=0
  case 14:bad.bodies[1]=bad.bodies[0]
  case 15:bad.shapes[1]=bad.shapes[0]
  case 16:bad.bodies[0]=bad.sensor
  case 17:bad.shapes[0]=bad.sensor_shape
  case 18:bad.bodies[32]=bad.bodies[0]
  }
  testing.expect(t,!common.game_valid(bad));testing.expect(t,!model.state_valid(bad),"Replay uses the same pure shared contract")
 }
 // No diagnostic-counter maximum or numeric Native-key bit layout is added.
 counters:=game;counters.queries=max(u64);counters.begins=max(u64);counters.motor_changes=max(u64)
 testing.expect(t,common.game_valid(counters))
}

@(test)
shared_game_retirement_edges_use_real_spawn_remove_and_keep_inactive_lifetime :: proc(t:^testing.T){
 defer cleanup(t)
 world,game,status:=common.world(4,42);testing.expect_value(t,status,b.Status.Ok);if status!=.Ok{return};defer b.world_destroy(&world)
 source:=fixture.Context{world=world}
 for _ in 0..<56{fixture.tick(t,&source,&game);testing.expect(t,common.game_valid(game))}
 slot:=int(game.initial)
 testing.expect(t,!game.alive[slot]&&game.bodies[slot]==0&&game.shapes[slot]==0&&game.lifetimes[slot]!=0&&game.retired_count==1)
 // Real rules/native operations fill the bounded retirement array. This is a
 // common-rules edge, not a claim that transport admits seven actions per tick.
 for _ in 0..<7{
  _,spawned:=common.apply_action(&game,1,{.Spawn},fixture.operations(&source));testing.expect(t,spawned)
  testing.expect(t,common.game_valid(game))
  _,removed:=common.apply_action(&game,1,{.Remove},fixture.operations(&source));testing.expect(t,removed)
  testing.expect(t,common.game_valid(game))
 }
 testing.expect_value(t,game.retired_count,u32(8))
 for variant in 0..<8{
  bad:=game
  switch variant{
  case 0:bad.retired_count=9
  case 1:bad.retired[0].shape=0
  case 2:bad.retired[0].lifetime=0
  case 3:bad.retired[0].tick=bad.tick+1
  case 4:bad.retired[0].shape=bad.sensor_shape
  case 5:bad.retired[0].shape=bad.shapes[0]
  case 6:bad.retired[1].shape=bad.retired[0].shape
  case 7:bad.retired[1].lifetime=bad.retired[0].lifetime
  }
  testing.expect(t,!common.game_valid(bad))
 }
 retained:=game.lifetimes[slot]
 fixture.tick(t,&source,&game)
 testing.expect(t,game.retired_count==0&&!game.alive[slot]&&game.lifetimes[slot]==retained&&common.game_valid(game),
  "retirement expiry must preserve the legal inactive slot's last lifetime")
}

actual_trajectory :: proc(t:^testing.T,initial:u32){
 world,game,status:=common.world(initial,42);testing.expect_value(t,status,b.Status.Ok);if status!=.Ok{return};defer b.world_destroy(&world)
 source:=fixture.Context{world=world};testing.expect(t,common.game_valid(game))
 spawned,removed,expired:=false,false,false
 for _ in 0..<300{
  fixture.tick(t,&source,&game)
  testing.expect(t,common.game_valid(game),"actual shared rules trajectory must remain valid")
  if game.tick==40{
   counters,cs:=b.world_counters(world);testing.expect_value(t,cs,b.Status.Ok)
   testing.expect(t,game.alive[initial]&&counters.body_count==initial+3&&counters.shape_count==initial+3)
   spawned=true
  }
  if game.tick==56{removed=!game.alive[initial]&&game.retired_count==1;testing.expect(t,removed)}
  if game.tick==57{expired=game.retired_count==0&&game.lifetimes[initial]!=0;testing.expect(t,expired)}
 }
 testing.expect(t,spawned&&removed&&expired&&source.verified_sleep>0&&source.verified_wake>0&&game.queries>0)
}

@(test)
shared_game_actual_initial4_and32_all_scripted_trajectories_and_cleanup :: proc(t:^testing.T){
 defer cleanup(t)
 actual_trajectory(t,4);actual_trajectory(t,32)
}
