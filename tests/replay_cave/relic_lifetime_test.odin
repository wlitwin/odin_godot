package replay_cave_test
import "core:testing"
import "core:reflect"
import "core:os"
import "core:fmt"
import net "godot:replay/net"
import upgrade "../../examples/replay_cavecrawl/shared/upgrade"
import r "godot:replay"
import cave "../../examples/replay_cavecrawl/shared/cave"

relic_floor_world :: proc(carried:bool)->cave.World {
 w:=joined_world();w.clock=100;w.director={wave=2,done=true};w.door_open=true
 for &player in w.players {if player.connected {player.position=cave.floor(1).door}}
 w.relic={position={200,150},carrier=carried ? 1 : 0,version=7}
 return w
}
@(test)
relic_initial_position_and_carried_floor_identity_match_original :: proc(t:^testing.T) {
 initial:=cave.initial();testing.expect_value(t,initial.relic.position,([2]f32{120,80}))
 w:=relic_floor_world(true)
 events:[32]r.Occurrence(cave.Event);ctx:=context_for(events[:],101)
 cave.step(&w,[cave.SEATS]cave.Control{},0,0,&ctx)
 testing.expect_value(t,w.depth,u8(2));testing.expect_value(t,w.relic.carrier,u16(1));testing.expect_value(t,w.relic.version,u32(7))
 testing.expect_value(t,w.relic.position,w.players[0].position+([2]f32{10,-12}))
 testing.expect(t,cave.state_valid(w))
}
@(test)
resting_relic_survives_descent_and_restart_releases_without_repositioning :: proc(t:^testing.T) {
 w:=relic_floor_world(false);before:=w.relic
 events:[32]r.Occurrence(cave.Event);ctx:=context_for(events[:],101)
 cave.step(&w,[cave.SEATS]cave.Control{},0,0,&ctx)
 testing.expect_value(t,w.depth,u8(2));testing.expect(t,reflect.equal(w.relic,before))
 w.won=true
 testing.expect(t,cave.act(&w,1,cave.Action{verb=.Lobby,lobby={verb=.Restart}},&ctx))
 testing.expect(t,reflect.equal(w.relic,before))
 w.won=true;w.depth=2;w.relic.carrier=1;w.relic.position={250,150}
 testing.expect(t,cave.act(&w,1,cave.Action{verb=.Lobby,lobby={verb=.Restart}},&ctx))
 testing.expect_value(t,w.relic.carrier,u16(0));testing.expect_value(t,w.relic.position,([2]f32{250,150}));testing.expect_value(t,w.relic.version,u32(8))
}

@(test)
relic_descent_correction_restores_identity_position_and_events :: proc(t:^testing.T) {
 initial:=r.Frame(cave.World){tick=100,state=relic_floor_world(true)}
 left,right:r.Timeline(cave.World,bool,cave.Event)
 r.init(&left,initial,floor_replay_step);r.init(&right,initial,floor_replay_step);defer r.destroy(&left);defer r.destroy(&right)
 for tick in 101..=105 {
  testing.expect_value(t,r.advance(&left,true).error,r.Error.None)
  testing.expect_value(t,r.advance(&right,tick!=101).error,r.Error.None)
 }
 testing.expect_value(t,r.revise_input(&left,101,false).error,r.Error.None)
 a,_:=r.current(&left);b,_:=r.current(&right);testing.expect(t,reflect.equal(a,b))
 testing.expect_value(t,a.state.relic.carrier,u16(1));testing.expect_value(t,a.state.relic.version,u32(7))
 ea,eb:[32]r.Occurrence(cave.Event)
 for tick in 101..=105 {na,_:=r.copy_events(&left,u64(tick),ea[:]);nb,_:=r.copy_events(&right,u64(tick),eb[:]);testing.expect_value(t,na,nb);testing.expect(t,reflect.equal(ea[:na],eb[:nb],true))}
 testing.expect_value(t,r.audit(&left,101).error,r.Error.None)
}

@(test)
content5_conversion_preserves_relic_archive_before_new_rules_execute :: proc(t:^testing.T) {
 names:=[3]string{"resting","carried","restart"}
 for name in names {
  bytes,error:=os.read_entire_file(fmt.tprintf("tests/replay_cave/fixtures/content5/%s.replay",name),context.allocator);testing.expect(t,error==nil);defer delete(bytes)
  old:net.Checkpoint(upgrade.World_7,cave.Control,cave.Action,cave.SEATS);current:net.Checkpoint(cave.World,cave.Control,cave.Action,cave.SEATS);defer net.checkpoint_destroy(&old);defer net.checkpoint_destroy(&current)
  testing.expect_value(t,net.checkpoint_decode(&old,bytes,upgrade.model5(),upgrade.CONTENT_5),net.Error.None)
  testing.expect(t,net.checkpoint_decode(&current,bytes,cave.model(),cave.CONTENT)!=.None)
  converted,result:=upgrade.convert_archive(bytes);defer delete(converted);testing.expect_value(t,result,net.Error.None)
  testing.expect_value(t,net.checkpoint_decode(&current,converted,cave.model(),cave.CONTENT),net.Error.None)
  expected,_:=upgrade.convert_world7(old.frame.state);expected.authority_known=true;expected.authority_seat=old.header.local_seat;testing.expect(t,reflect.equal(current.frame,r.Frame(cave.World){tick=old.frame.tick,state=expected}));testing.expect(t,reflect.equal(current.peers[:],old.peers[:],true))
  w:=current.frame.state;events:[32]r.Occurrence(cave.Event);ctx:=context_for(events[:],101)
  if name=="restart" {
   testing.expect(t,cave.act(&w,1,cave.Action{verb=.Lobby,lobby={verb=.Restart}},&ctx))
   testing.expect_value(t,w.relic.carrier,u16(0));testing.expect_value(t,w.relic.version,u32(8));testing.expect_value(t,w.relic.position,old.frame.state.relic.position)
  } else {
   cave.step(&w,[cave.SEATS]cave.Control{},0,0,&ctx);testing.expect_value(t,w.depth,u8(2));testing.expect_value(t,w.relic.version,u32(7))
   if name=="carried" {testing.expect_value(t,w.relic.carrier,u16(1));testing.expect_value(t,w.relic.position,w.players[0].position+([2]f32{10,-12}))}
   else {testing.expect(t,reflect.equal(w.relic,old.frame.state.relic))}
  }
 }
}
