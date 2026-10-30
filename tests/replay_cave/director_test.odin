package replay_cave_test

import "core:testing"
import "core:reflect"
import "core:os"
import "core:fmt"
import r "godot:replay"
import net "godot:replay/net"
import cave "../../examples/replay_cavecrawl/shared/cave"
import upgrade "../../examples/replay_cavecrawl/shared/upgrade"

Director_Input :: struct {kill:bool}
director_replay_step :: proc(w:^cave.World,input:Director_Input,ctx:^r.Step(cave.Event)) {
 if input.kill {
  for alive,index in w.dwellers.alive {if alive {
   for _ in 0..<2 {r.pool_insert(&w.rocks,cave.Rock{position=w.dwellers.values[index].position,left=1,shooter=1})}
   break
  }}
 }
 cave.step(w,[cave.SEATS]cave.Control{},ctx.tick==1 ? 1 : 0,0,ctx)
}

@(test)
director_death_and_rest_revisions_match_a_fresh_complete_world :: proc(t:^testing.T) {
 defs:=cave.FLOORS;defs[0].waves={0=1,1=1};defs[0].rests={0=5,1=3}
 initial:=r.Frame(cave.World){state=cave.initial(floors=defs)}
 original,fresh:r.Timeline(cave.World,Director_Input,cave.Event)
 r.init(&original,initial,director_replay_step);r.init(&fresh,initial,director_replay_step)
 defer r.destroy(&original);defer r.destroy(&fresh)
 for tick in 1..=40 {
  testing.expect_value(t,r.advance(&original,Director_Input{tick==6 || tick==15 || tick==25}).error,r.Error.None)
  testing.expect_value(t,r.advance(&fresh,Director_Input{tick==15 || tick==25}).error,r.Error.None)
 }
 testing.expect_value(t,r.revise_input(&original,6,Director_Input{}).error,r.Error.None)
 left,_:=r.current(&original);right,_:=r.current(&fresh)
 testing.expect(t,reflect.equal(left,right));testing.expect(t,left.state.director.done)
 a,b:[32]r.Occurrence(cave.Event)
 for tick in 1..=40 {
  na,_:=r.copy_events(&original,u64(tick),a[:]);nb,_:=r.copy_events(&fresh,u64(tick),b[:])
  testing.expect_value(t,na,nb);testing.expect(t,reflect.equal(a[:na],b[:nb],true))
 }
 testing.expect_value(t,r.audit(&original,1).error,r.Error.None)
}

@(test)
director_announces_then_spawns_each_tick_and_resets_den_cursor_per_floor :: proc(t:^testing.T) {
 w:=cave.initial();testing.expect(t,cave.state_valid(w));testing.expect_value(t,w.director.wave,u8(0))
 events:[32]r.Occurrence(cave.Event);ctx:=r.Step(cave.Event){epoch=1,events=events[:]}
 for tick in 1..=3 {
  ctx.tick=u64(tick);ctx.count=0;cave.step(&w,[cave.SEATS]cave.Control{},tick==1 ? 1 : 0,0,&ctx)
  testing.expect_value(t,ctx.error,r.Error.None)
  testing.expect_value(t,w.dwellers.count,u32(tick-1))
 }
 testing.expect_value(t,w.dwellers.values[0].home,cave.FLOORS[0].dens[0]);testing.expect_value(t,w.dwellers.values[1].home,cave.FLOORS[0].dens[1])
 w.dens_used=5;w.depth=2;cave.enter_floor(&w)
 testing.expect_value(t,w.dens_used,u32(0));testing.expect_value(t,w.director.wave,u8(0))
 w.clock=100;cave.step_director(&w,&ctx);w.clock=101;cave.step_director(&w,&ctx)
 testing.expect_value(t,w.dwellers.count,u32(1));testing.expect_value(t,w.dwellers.values[0].home,cave.FLOORS[1].dens[0])
}

@(test)
director_retains_pending_spawns_at_pool_capacity :: proc(t:^testing.T) {
 defs:=cave.FLOORS;defs[0].waves[0]=17
 w:=cave.initial(floors=defs);w.players[0].connected=true
 ctx:=r.Step(cave.Event){}
 for tick in 1..=20 {w.clock=u64(tick);cave.step_director(&w,&ctx)}
 testing.expect_value(t,w.dwellers.count,u32(16));testing.expect_value(t,w.director.remaining,u16(1));testing.expect_value(t,w.dens_used,u32(16))
 id:=r.Handle(cave.Dweller){index=0,generation=w.dwellers.generations[0]};r.pool_remove(&w.dwellers,id)
 w.clock=21;cave.step_director(&w,&ctx)
 testing.expect_value(t,w.dwellers.count,u32(16));testing.expect_value(t,w.director.remaining,u16(0));testing.expect_value(t,w.dens_used,u32(17))
 testing.expect(t,!w.director.done)
}

@(test)
rest_deadline_overflow_cannot_commit_partial_combat :: proc(t:^testing.T) {
 w:=cave.initial();w.players[0].connected=true;w.players[0].initialized=true;w.players[0].hp=100;w.players[0].position={80,120}
 w.director={wave=1};r.pool_insert(&w.dwellers,cave.Dweller{position={320,40},home={320,40},hp=35})
 r.pool_insert(&w.rocks,cave.Rock{position={320,40},left=1,shooter=1})
 timeline:r.Timeline(cave.World,[cave.SEATS]cave.Control,cave.Event)
 r.init(&timeline,r.Frame(cave.World){tick=max(u64)-1,state=w},proc(w:^cave.World,c:[cave.SEATS]cave.Control,ctx:^r.Step(cave.Event)){cave.step(w,c,0,0,ctx)})
 defer r.destroy(&timeline)
 before,_:=r.current(&timeline);result:=r.advance(&timeline,[cave.SEATS]cave.Control{});after,_:=r.current(&timeline)
 testing.expect_value(t,result.error,r.Error.Aborted);testing.expect(t,reflect.equal(before,after))
}

@(test)
content3_conversion_preserves_complete_frame_and_scheduled_deadlines :: proc(t:^testing.T) {
 names:=[4]string{"waiting","pending","spawning","rest"}
 for name in names {
  bytes,error:=os.read_entire_file(fmt.tprintf("tests/replay_cave/fixtures/content3/%s.replay",name),context.allocator);testing.expect(t,error==nil);defer delete(bytes)
  old:net.Checkpoint(upgrade.World_7,cave.Control,cave.Action,cave.SEATS);current:net.Checkpoint(cave.World,cave.Control,cave.Action,cave.SEATS);defer net.checkpoint_destroy(&old);defer net.checkpoint_destroy(&current)
  testing.expect_value(t,net.checkpoint_decode(&old,bytes,upgrade.model3(),upgrade.CONTENT_3),net.Error.None)
  testing.expect(t,net.checkpoint_decode(&current,bytes,cave.model(),cave.CONTENT)!=.None)
  converted,result:=upgrade.convert_archive(bytes);defer delete(converted);testing.expect_value(t,result,net.Error.None)
  testing.expect_value(t,net.checkpoint_decode(&current,converted,cave.model(),cave.CONTENT),net.Error.None)
  expected,_:=upgrade.convert_world7(old.frame.state);expected.authority_known=true;expected.authority_seat=old.header.local_seat;testing.expect(t,reflect.equal(current.frame,r.Frame(cave.World){tick=old.frame.tick,state=expected}));testing.expect(t,reflect.equal(old.peers[:],current.peers[:],true))
  testing.expect_value(t,current.header.content,cave.CONTENT)
  world:=current.frame.state;ctx:=r.Step(cave.Event){}
  if name=="pending" {
   for tick in 6..=21 {
    world.clock=u64(tick);cave.step_director(&world,&ctx)
    testing.expect_value(t,world.dwellers.count,tick<20 ? u32(0) : u32(tick-19))
   }
  }
  if name=="rest" {
   for tick in 11..=42 {
    world.clock=u64(tick);cave.step_director(&world,&ctx)
    testing.expect_value(t,world.director.wave,tick<41 ? u8(1) : u8(2))
    testing.expect_value(t,world.dwellers.count,tick<42 ? u32(0) : u32(1))
   }
  }
 }
 testing.expect(t,!upgrade.world3_valid(upgrade.World_7{}))
}
