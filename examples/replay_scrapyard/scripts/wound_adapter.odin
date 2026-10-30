package replay_scrapyard

import r "godot:replay"
import rgd "godot:replay/godot"
import game "../shared/game"
import flow "../shared/flow"
import display "../shared/presentation"

presentation_wound :: proc(self: ^ReplayScrapyard, event: game.Event, id: r.Event_Id) -> (flow.Wound_View, bool) {
	s := self.session
	if !s.ready || event.seat == 0 || event.seat > game.SEATS {
		return {}, false
	}
	epoch := s.authority ? s.server.cfg.epoch : s.client.cfg.epoch
	if id.epoch != epoch {
		return {}, false
	}
	if s.authority {
		frame, ok := rgd.session_authority_state(s)
		if !ok {
			return {}, false
		}
		return flow.wound_view(&frame.state, event, id.tick)
	}
	// Public snapshots deliberately omit hit_history. The client's retained
	// timeline owns public player poses for past ticks, including corrected or
	// locally predicted poses. Missing ticks are explicit; never use today's pose.
	if !s.client.has_world {
		return {}, false
	}
	frame, ok := r.read(&s.client.timeline, id.tick)
	if !ok {
		return {}, false
	}
	return display.wound(frame.state.players[event.seat - 1], event)
}
