package replay_scrapyard_test

import "core:testing"
import r "godot:replay"
import game "../../examples/replay_scrapyard/shared/game"
import sound "../../examples/replay_scrapyard/shared/audio"
import settings "../../examples/replay_scrapyard/shared/settings"

@(test)
shot_sound_uses_owned_event_family_after_the_world_changes :: proc(t:^testing.T) {
	families:=[5]sound.Sfx{.Bolter,.Riveter,.Slime,.Bolter,.Ping}
	for expected,family in families {
		event:=game.Event{kind=.Shot,position={50,60},detail=u8(family)}
		cue,ok:=sound.gameplay(event)
		testing.expect(t,ok && cue.kind==expected && cue.position==event.position && cue.spatial)
	}
}
@(test)
confirmed_sound_edges_have_silent_initial_restore_and_rewind_boundaries :: proc(t:^testing.T) {
	w:=yard();frame:=r.Frame(game.World){tick=10,state=w};observer:sound.Observer;out:[64]sound.Cue
	testing.expect_value(t,sound.observe(&observer,1,&frame,out[:]),0)
	frame.tick=11;frame.state.players[0].gun.mode=.Jammed;frame.state.players[0].gun.taps=3
	testing.expect_value(t,sound.observe(&observer,1,&frame,out[:]),1);testing.expect_value(t,out[0].kind,sound.Sfx.Jam)
	testing.expect_value(t,sound.observe(&observer,1,&frame,out[:]),0)
	frame.tick=9;frame.state.players[0].gun.mode=.Ready;testing.expect_value(t,sound.observe(&observer,1,&frame,out[:]),0)
	frame.tick=11;frame.state.players[0].gun.mode=.Jammed;testing.expect_value(t,sound.observe(&observer,1,&frame,out[:]),0)
	frame.tick=12;frame.state.players[0].gun.mode=.Ready
	testing.expect_value(t,sound.observe(&observer,1,&frame,out[:]),1);testing.expect_value(t,out[0].kind,sound.Sfx.Unjam)
	frame.tick=100;frame.state.players[0].hp=0;frame.state.wipes=1
	testing.expect_value(t,sound.observe(&observer,2,&frame,out[:]),0)
	testing.expect_value(t,sound.observe(&observer,1,&frame,out[:]),0)
	frame.tick=101;frame.state.players[0].hp=5
	testing.expect_value(t,sound.observe(&observer,2,&frame,out[:]),1);testing.expect_value(t,out[0].kind,sound.Sfx.Revive)
}
@(test)
settings_round_trip_rejects_invalid_values_and_corruption :: proc(t:^testing.T) {
	value:=settings.Value{1,3,true,true};bytes,ok:=settings.encode(value);defer delete(bytes);testing.expect(t,ok)
	decoded,valid:=settings.decode(bytes);testing.expect(t,valid);testing.expect_value(t,decoded,value)
	bytes[len(bytes)-1]~=1;_,valid=settings.decode(bytes);testing.expect(t,!valid)
	bad,encoded:=settings.encode(settings.Value{1,11,false,false});defer delete(bad);testing.expect(t,!encoded && len(bad)==0)
}

@(test)
departure_ticks_are_once_per_observed_second_and_restore_silently :: proc(t: ^testing.T) {
	frame := r.Frame(game.World){tick = 10, state = clear_world()}
	observer: sound.Observer; out: [64]sound.Cue
	testing.expect_value(t, sound.observe(&observer, 1, &frame, out[:]), 0)
	frame.tick = 11; frame.state.depart = {wind = 180, left = 180}
	testing.expect_value(t, sound.observe(&observer, 1, &frame, out[:]), 1)
	testing.expect(t, out[0].kind == .Buy && out[0].jolt == 1.2)
	testing.expect_value(t, sound.observe(&observer, 1, &frame, out[:]), 0)
	frame.tick = 12; frame.state.depart.left = 179
	testing.expect_value(t, sound.observe(&observer, 1, &frame, out[:]), 0)
	frame.tick = 71; frame.state.depart.left = 120
	testing.expect_value(t, sound.observe(&observer, 1, &frame, out[:]), 1)
	frame.tick = 72; frame.state.depart = {}
	testing.expect_value(t, sound.observe(&observer, 1, &frame, out[:]), 0)
	frame.tick = 73; frame.state.depart = {wind = 180, left = 180}
	testing.expect_value(t, sound.observe(&observer, 1, &frame, out[:]), 1)
	frame.tick = 90; frame.state.depart.left = 90
	testing.expect_value(t, sound.observe(&observer, 2, &frame, out[:]), 0)
	testing.expect_value(t, sound.observe(&observer, 2, &frame, out[:]), 0)
	frame.tick = 120; frame.state.depart.left = 60
	testing.expect_value(t, sound.observe(&observer, 2, &frame, out[:]), 1)
}
