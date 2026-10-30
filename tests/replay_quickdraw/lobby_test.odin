package replay_quickdraw_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import lb "godot:replay/lobby"
import game "../../examples/replay_quickdraw/shared/duel"

@(test)
manual_duel_waits_for_leader_and_keeps_gameplay_quiet :: proc(t:^testing.T) {
 w:=game.initial(gold=1,manual_start=true)
 events:[32]r.Occurrence(game.Event);ctx:=r.Step(game.Event){tick=1,epoch=1,events=events[:]}
 controls:[game.SEATS]game.Controls;controls[0]={move={1,0},drone={1,0},buttons=game.FIRE|game.LOB|game.DASH}
 game.step(&w,controls,{},3,0,&ctx)
 testing.expect(t,w.players[0].connected && w.players[1].connected && !w.started)
 start:=w.players[0]
 for tick in 2..<20 {ctx.tick,ctx.count=u64(tick),0;game.step(&w,controls,{},0,0,&ctx)}
 testing.expect(t,reflect.equal(start,w.players[0]));testing.expect_value(t,w.shots,u32(0));testing.expect_value(t,w.lobs,u32(0))
 before:=w
 testing.expect(t,!game.buy(&w,2,{start=true},&ctx));testing.expect(t,!game.buy(&w,1,{item=1},&ctx));testing.expect(t,reflect.equal(w,before))
 name,ok:=lb.name("Ada Ω");testing.expect(t,ok);testing.expect(t,game.buy(&w,2,{name=name},&ctx));testing.expect_value(t,w.names[1],name)
 testing.expect(t,game.buy(&w,1,{start=true},&ctx));testing.expect(t,!game.buy(&w,1,{start=true},&ctx))
 ctx.tick,ctx.count=20,0;game.step(&w,controls,{},0,0,&ctx)
 testing.expect(t,w.players[0].position!=start.position && w.players[0].drone!=start.drone)
 testing.expect_value(t,w.shots,u32(1));testing.expect_value(t,w.lobs,u32(1))
 testing.expect(t,game.state_valid(w))
}

@(test)
profile_and_start_commands_validate_payload_and_connection :: proc(t:^testing.T) {
 w:=game.initial(manual_start=true);events:[32]r.Occurrence(game.Event);ctx:=r.Step(game.Event){tick=1,epoch=1,events=events[:]}
 game.step(&w,{}, {},3,0,&ctx)
 name,_:=lb.name("Rider");before:=w
 testing.expect(t,!game.action_valid({item=1,name=name}));testing.expect(t,!game.action_valid({start=true,name=name}));testing.expect(t,!game.action_valid({}))
 bad:=name;bad.bytes[47]=1;testing.expect(t,!game.action_valid({name=bad}))
 testing.expect(t,!game.buy(&w,0,{name=name},&ctx));testing.expect(t,!game.buy(&w,5,{start=true},&ctx));testing.expect(t,reflect.equal(w,before))
 ctx.tick=2;game.step(&w,{}, {},0,1,&ctx)
 testing.expect_value(t,game.leader(&w),u16(2));testing.expect(t,!game.buy(&w,1,{name=name},&ctx))
 testing.expect(t,game.buy(&w,2,{start=true},&ctx))
 // A reconnect retains the named row and its stats through the ordinary join.
 ctx.tick=3;game.step(&w,{}, {},1,0,&ctx)
 testing.expect(t,w.players[0].connected);testing.expect_value(t,w.names[0],before.names[0])
}
