package replay_claimball_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import lb "godot:replay/lobby"
import game "../../examples/replay_claimball/shared/pitch"

@(test)
manual_start_reads_boundary_roster_without_predicting_outsiders :: proc(t:^testing.T) {
 w:=game.initial(min_players=2,manual_start=true)
 storage:[32]r.Occurrence(game.Event);ctx:=r.Step(game.Event){tick=1,epoch=1,events=storage[:]}
 game.step(&w,{},7,0,&ctx)
 testing.expect(t,!w.started && game.state_valid(w))
 controls:[game.SEATS]game.Controls;controls[0]={move={1,0},buttons=game.KICK}
 position:=w.players[0].motion.position
 ctx.tick=2;game.step(&w,controls,0,0,&ctx)
 testing.expect_value(t,w.players[0].motion.position,position);testing.expect_value(t,w.kicks,u32(0))
 guest:=game.project(r.Frame(game.World){tick=2,state=w},2);before:=guest
 testing.expect_value(t,game.leader(&guest),u16(1));testing.expect(t,!game.action(&guest,2,{start=true},&ctx));testing.expect(t,reflect.equal(guest,before))
 host:=game.project(r.Frame(game.World){tick=2,state=w},1)
 testing.expect(t,game.action(&host,1,{start=true},&ctx));testing.expect(t,game.group_valid(host,1))
 testing.expect(t,host.players[1]==game.Player{} && host.players[2]==game.Player{})
 // Departed leaders are read from the boundary; the remaining roster still
 // satisfies the two-player rule without promoting outsiders into simulation.
 guest.outside.value[0].connected=false
 testing.expect_value(t,game.leader(&guest),u16(2));testing.expect(t,game.action(&guest,2,{start=true},&ctx));testing.expect(t,game.group_valid(guest,2))
}

@(test)
profile_commands_are_owned_values_and_do_not_change_the_group :: proc(t:^testing.T) {
 w:=game.initial(manual_start=true);storage:[32]r.Occurrence(game.Event);ctx:=r.Step(game.Event){tick=1,epoch=1,events=storage[:]};game.step(&w,{},3,0,&ctx)
 projected:=game.project(r.Frame(game.World){tick=1,state=w},2);outside:=projected.outside
 name,ok:=lb.name("Blue Ω");testing.expect(t,ok)
 testing.expect(t,game.action(&projected,2,{name=name},&ctx));testing.expect_value(t,projected.names[1],name)
 testing.expect(t,projected.players[1].named && reflect.equal(projected.outside,outside) && game.group_valid(projected,2))
 before:=projected
 testing.expect(t,!game.action(&projected,1,{name=name},&ctx));testing.expect(t,!game.action_valid({name=name,spike=true}));testing.expect(t,!game.action_valid({start=true,spike=true}));testing.expect(t,reflect.equal(projected,before))
 bad:=name;bad.bytes[47]=1;testing.expect(t,!game.action_valid({name=bad}))
}
