package replay_slopball3d_test
import "core:testing"
import "core:reflect"
import r "godot:replay"
import own "godot:replay/owned"
import lb "godot:replay/lobby"
import game "../../examples/replay_slopball3d/shared/pitch"

@(test)
manual_lobby_ignores_solver_samples_and_only_its_leader_can_start :: proc(t:^testing.T) {
 w:=game.initial(minimum=2,manual_start=true);events:[32]r.Occurrence(game.Event)
 ctx:=r.Step(game.Event){epoch=1,tick=1,events=events[:]};game.step(&w,{},3,0,&ctx)
 testing.expect(t,!w.started && game.state_valid(w));before:=w
 controls:[game.SEATS]game.Control
 pose:=w.players[1].body.value;pose.position[0]+=0.5
 controls[1].player={own.scope(w.players[1].body),1,1,pose}
 ball:=w.ball.value;ball.position[0]+=0.3;controls[0].ball={own.scope(w.ball),1,1,ball}
 ctx.tick=2;game.step(&w,controls,0,0,&ctx)
 testing.expect(t,reflect.equal(w.players,before.players) && reflect.equal(w.ball,before.ball))
 snapshot:=w;testing.expect(t,!game.action(&w,2,{start=true},&ctx));testing.expect(t,reflect.equal(w,snapshot))
 testing.expect(t,game.action(&w,1,{start=true},&ctx));testing.expect(t,w.started && w.kickoff_until==2+game.KICKOFF_TICKS)
 testing.expect_value(t,ctx.count,1);testing.expect_value(t,events[0].value.kind,game.Event_Kind.Started)
 testing.expect(t,!game.action(&w,1,{start=true},&ctx))
 ctx.tick=3;controls[0]={};game.step(&w,controls,0,0,&ctx)
 testing.expect_value(t,w.players[1].body.value.position,pose.position)
 testing.expect(t,game.state_valid(w))
}

@(test)
names_preserve_owner_scopes_and_leadership_follows_the_connected_roster :: proc(t:^testing.T) {
 w:=game.initial(minimum=2,manual_start=true);events:[32]r.Occurrence(game.Event)
 ctx:=r.Step(game.Event){epoch=1,tick=1,events=events[:]};game.step(&w,{},7,0,&ctx)
 name,ok:=lb.name("Kicker Ω");testing.expect(t,ok)
 body:=w.players[1].body;ball:=w.ball
 testing.expect(t,game.action(&w,2,{name=name},&ctx));testing.expect(t,w.names[1]==name && w.players[1].named)
 testing.expect(t,reflect.equal(w.players[1].body,body) && reflect.equal(w.ball,ball))
 before:=w;testing.expect(t,!game.action(&w,0,{name=name},&ctx));testing.expect(t,!game.action_valid({name=name,start=true}));testing.expect(t,reflect.equal(w,before))
 ctx.tick=2;game.step(&w,{},0,1,&ctx)
 testing.expect_value(t,game.leader(&w),u16(2));testing.expect(t,game.action(&w,2,{start=true},&ctx))
 testing.expect(t,game.state_valid(w) && w.players[0].initialized && !w.players[0].connected)
}
