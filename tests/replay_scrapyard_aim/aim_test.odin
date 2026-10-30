package replay_scrapyard_aim_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import game "../../examples/replay_scrapyard/shared/game"
import scripts "../../examples/replay_scrapyard/scripts"

@(test)
stress_aim_uses_predicted_local_origin_and_observed_enemy :: proc(t:^testing.T) {
	self:=new(scripts.ReplayScrapyard);defer free(self)
	self.session=&self.standalone;s:=self.session;s.ready=true;s.client.phase=.Running;s.client.seat=1
	observed:=game.initial(encounter_count=0);observed.players[0].position={100,100}
	testing.expect(t,game.spawn_mob(&observed,0,{200,100}))
	predicted:=observed;predicted.players[0].position={200,200};predicted.mobs.values[0].position={900,900}
	s.client.authority_frame={tick=10,state=observed}
	testing.expect_value(t,r.init(&s.client.timeline,r.Frame(game.World){tick=20,state=predicted},proc(_: ^game.World,_:net.Batch(game.Control,game.Action,game.SEATS),_:^r.Step(net.Net_Event(game.Event))) {},cfg={2,0}),r.Error.None)
	defer r.destroy(&s.client.timeline)
	scripts.replay_scrapyard_dev_stress_fire(self)
	testing.expect_value(t,self.manual_aim,[2]f32{0,-1})
	testing.expect(t,self.manual && self.manual_fire && !self.auto_combat && self.manual_move==([2]f32{}))
	frame,_:=r.current(&s.client.timeline)
	testing.expect(t,reflect.equal(frame.state,predicted) && reflect.equal(s.client.authority_frame.state,observed))
	// A host reads its current authoritative body, never the unused client view.
	s.authority=true;s.server.local_seat=1
	testing.expect_value(t,r.init(&s.server.timeline,r.Frame(game.World){tick=30,state=observed},proc(_: ^game.World,_:net.Batch(game.Control,game.Action,game.SEATS),_:^r.Step(net.Net_Event(game.Event))) {},cfg={2,0}),r.Error.None)
	defer r.destroy(&s.server.timeline)
	scripts.replay_scrapyard_dev_stress_fire(self)
	testing.expect_value(t,self.manual_aim,[2]f32{1,0})
}
