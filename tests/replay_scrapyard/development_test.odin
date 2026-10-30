package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import game "../../examples/replay_scrapyard/shared/game"

@(test)
development_actions_require_explicit_local_authority_admission :: proc(t:^testing.T) {
	a:=game.Action{kind=.Dev_Spawn,item=5,slot=0,aim={150,50}}
	model:=game.model()
	testing.expect(t,game.action_valid(a))
	testing.expect(t,!model.action_admit(nil,1,a))
	testing.expect(t,!game.development_allowed(false,1,1,a))
	testing.expect(t,!game.development_allowed(true,0,1,a))
	testing.expect(t,!game.development_allowed(true,1,2,a))
	testing.expect(t,!game.development_allowed(true,game.SEATS+1,game.SEATS+1,a))
	testing.expect(t,game.development_allowed(true,1,1,a))
	a.slot=game.SEATS;testing.expect(t,!game.action_valid(a))
	testing.expect(t,game.development_allowed(false,0,2,game.Action{kind=.Ready}))
}

Dev_Input :: struct {spawn:bool,offset:[2]f32}
dev_step :: proc(w:^game.World,input:Dev_Input,ctx:^r.Step(game.Event)) {
	if input.spawn {if !game.action(w,1,game.Action{kind=.Dev_Spawn,item=5,aim=input.offset},ctx) {r.abort(ctx);return}}
	game.step(w,[game.SEATS]game.Control{},0,0,ctx)
}
@(test)
development_spawn_restores_allocator_and_history_during_replay :: proc(t:^testing.T) {
	w:=game.initial(encounter_count=0);w.stage=.Yard;w.players[0].connected,w.players[0].in_yard=true,true;w.players[0].position={600,960}
	timeline,fresh:r.Timeline(game.World,Dev_Input,game.Event)
	testing.expect_value(t,r.init(&timeline,r.Frame(game.World){state=w},dev_step),r.Error.None);defer r.destroy(&timeline)
	testing.expect_value(t,r.init(&fresh,r.Frame(game.World){state=w},dev_step),r.Error.None);defer r.destroy(&fresh)
	first:=Dev_Input{true,{150,0}};second:=Dev_Input{true,{150,50}}
	testing.expect_value(t,r.advance(&timeline,first).error,r.Error.None)
	testing.expect_value(t,r.advance(&timeline,second).error,r.Error.None)
	testing.expect_value(t,r.revise_input(&timeline,1,Dev_Input{}).error,r.Error.None)
	testing.expect_value(t,r.advance(&fresh,Dev_Input{}).error,r.Error.None)
	testing.expect_value(t,r.advance(&fresh,second).error,r.Error.None)
	a,_:=r.current(&timeline);b,_:=r.current(&fresh)
	testing.expect(t,reflect.equal(a,b));testing.expect(t,game.state_valid(a.state))
	testing.expect_value(t,a.state.mobs.count,u32(1))
}

@(test)
development_spawn_capacity_refusal_preserves_the_world :: proc(t:^testing.T) {
	w:=game.initial(encounter_count=0);w.stage=.Yard;w.players[0].connected,w.players[0].in_yard=true,true
	for _ in 0..<game.MAX_MOBS {testing.expect(t,game.spawn_mob(&w,5,{750,960}))}
	before:=w;events:[32]r.Occurrence(game.Event);ctx:=r.Step(game.Event){epoch=1,events=events[:]}
	testing.expect(t,!game.action(&w,1,game.Action{kind=.Dev_Spawn,item=5,aim={150,0}},&ctx))
	testing.expect(t,reflect.equal(before,w));testing.expect_value(t,ctx.count,0)
}

@(test)
workbench_edits_use_real_status_damage_grant_and_jam_rules :: proc(t:^testing.T) {
	w:=yard();events:[64]r.Occurrence(game.Event);ctx:=r.Step(game.Event){tick=1,epoch=1,events=events[:]}
	commands:=[?]game.Development{{.Hurt,1,5,0},{.Jam,1,0,0},{.Status,1,0,4},{.Status,1,0,3},{.Grant_Scrap,1,500,0},{.Grant_Cores,1,20,0}}
	for command in commands {
		a:=game.Action{kind=.Dev_Edit,development=command}
		testing.expect(t,game.action_valid(a));testing.expect(t,!game.model().action_admit(nil,1,a))
		testing.expect(t,!game.development_allowed(true,1,2,a));testing.expect(t,game.development_allowed(true,1,1,a))
		testing.expect(t,game.action(&w,1,a,&ctx))
	}
	testing.expect_value(t,w.players[0].hp,u8(5));testing.expect_value(t,w.players[0].scrap,u32(500));testing.expect_value(t,w.players[0].cores,u32(20))
	testing.expect(t,w.players[0].gun.mode==.Jammed && w.players[0].gun.taps>0)
	testing.expect_value(t,w.status_applied,u32(2));testing.expect(t,game.state_valid(w))
	bad:=game.Development{.Hurt,1,256,0};testing.expect(t,!game.development_valid(bad));before:=w
	testing.expect(t,!game.development_apply(&w,1,bad,&ctx));testing.expect(t,reflect.equal(before,w))
}
@(test)
workbench_smite_preserves_bosses_props_and_normal_death_credit :: proc(t:^testing.T) {
	w:=yard();game.spawn_mob(&w,0,{650,1000});game.spawn_mob(&w,4,{900,1000});game.spawn_mob(&w,5,{1100,1000})
	events:[64]r.Occurrence(game.Event);ctx:=r.Step(game.Event){tick=1,epoch=1,events=events[:]}
	testing.expect(t,game.action(&w,1,game.Action{kind=.Dev_Edit,development={kind=.Smite,seat=1}},&ctx))
	testing.expect_value(t,w.players[0].kills,u32(1));testing.expect_value(t,w.drops.count,u32(1))
	testing.expect_value(t,w.mobs.values[0].hp,u16(0));testing.expect(t,w.mobs.values[1].hp>0 && w.mobs.values[2].hp>0)
	testing.expect(t,game.state_valid(w))
}
Edit_Input :: struct {edit:bool,command:game.Development}
edit_step :: proc(w:^game.World,input:Edit_Input,ctx:^r.Step(game.Event)) {
	if input.edit {game.action(w,1,game.Action{kind=.Dev_Edit,development=input.command},ctx)}
	game.step(w,[game.SEATS]game.Control{},0,0,ctx)
}
@(test)
workbench_edit_correction_replays_without_duplicating_grants :: proc(t:^testing.T) {
	w:=yard();a,b:r.Timeline(game.World,Edit_Input,game.Event)
	r.init(&a,r.Frame(game.World){state=w},edit_step);defer r.destroy(&a)
	r.init(&b,r.Frame(game.World){state=w},edit_step);defer r.destroy(&b)
	grant:=Edit_Input{true,{kind=.Grant_Scrap,seat=1,amount=500}}
	testing.expect_value(t,r.advance(&a,grant).error,r.Error.None);testing.expect_value(t,r.advance(&a,grant).error,r.Error.None)
	testing.expect_value(t,r.revise_input(&a,1,Edit_Input{}).error,r.Error.None)
	r.advance(&b,Edit_Input{});r.advance(&b,grant)
	actual,_:=r.current(&a);expected,_:=r.current(&b)
	testing.expect(t,reflect.equal(actual,expected));testing.expect_value(t,actual.state.players[0].scrap,u32(500))
}
