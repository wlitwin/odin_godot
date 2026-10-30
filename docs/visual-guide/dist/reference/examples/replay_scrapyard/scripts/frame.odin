package replay_scrapyard

import "core:fmt"
import gd "godot:godot"
import rgd "godot:replay/godot"
import v "godot:replay/view"
import game "../shared/game"
import debuggd "godot:replay/godot/debug"

// Preserve the old callback's deferred order, including on unavailable sessions
// and frame failures. Re-check readiness between hooks just as each defer did.
finish_frame :: proc(self: ^ReplayScrapyard, dt: f64) {
	if self.ready {
		audio_frame(self, dt)
	}
	if self.ready {
		recording_frame(self)
	}
	self.menu_input_guard = false
	if self.ready {
		debuggd.session_diagnostics_frame(&self.diagnostics[0], self.session)
	}
	if self.ready {
		social_frame(self)
	}
	if self.ready {
		transitions_recovery(self)
	}
	if self.ready {
		screen_frame(self, dt)
	}
	if self.ready {
		feedback_frame(self)
	}
}

poll_frame_ui :: proc(self: ^ReplayScrapyard) -> bool {
	typing := self.ready ? social_input(self) : false
	if self.ready {
		online_frame(self)
		online_status(self)
	}
	if self.ready {
		flow_input(self, typing)
		settings_poll(self)
	}
	if self.ready && self.pending_open {
		open(self, self.pending_role)
	}
	return typing
}

poll_frame_services :: proc(self: ^ReplayScrapyard, typing: bool) {
	browser_run_poll(self)
	web_spray_store_poll(self)
	web_spray_poll(self)
	if !typing && gd.is_action_just_pressed("rsy_save") {
		replay_scrapyard_save_run(self)
	}
	if !typing && !self.menu_open && gd.is_action_just_pressed("rsy_stamp") {
		replay_scrapyard_stamp(self)
	}
}

advance_gameplay_session :: proc(self: ^ReplayScrapyard, dt: f64, control: game.Control) -> bool {
	dash_submit(self)
	turret_intent_submit(self)
	if err := frame_session(self, dt, control); err != .None {
		if err == .Presentation && !self.session.authority {
			gd.print_str(
				fmt.tprintf(
					"RSY_PRESENTATION_FAILURE %v pending_changes=%d",
					self.session.client.presentation_failure,
					self.session.change_count,
				),
			)
		}
		fail(self, fmt.tprintf("frame %v", err))
		return false
	}
	if self.session.control_consumed {
		// Sampling movement/fire does not acknowledge a pending dash intent.
		self.buttons.pressed &= 1
		self.buttons.released = 0
	}
	if !self.declared {
		declare(self)
	}
	return true
}

update_prediction_smoothing :: proc(self: ^ReplayScrapyard) {
	if !self.session.authority {
		if self.last_reset != self.session.client.view_reset {
			self.last_reset = self.session.client.view_reset
			self.smoothing = {}
		}
		if self.last_correction != self.session.client.correction.serial {
			correction := self.session.client.correction
			self.last_correction = correction.serial
			for i in 0 ..< game.SEATS {
				v.smooth_correct(
					&self.smoothing[i],
					correction.before.state.players[i].position,
					correction.after.state.players[i].position,
					discontinuity = correction.before.state.players[i].generation !=
						correction.after.state.players[i].generation ||
					correction.before.state.players[i].warp != correction.after.state.players[i].warp,
				)
			}
		}
	}
}

present_session_frame :: proc(self: ^ReplayScrapyard, dt: f64) {
	frame, ok := rgd.session_state(self.session)
	truth, confirmed := rgd.session_authority_state(self.session)
	if confirmed {
		muster_pending(self, &truth.state)
	}
	if self.ready_retry && confirmed {
		sequence, err := issue_action(self, game.Action{kind = .Ready, ready = self.ready_wanted})
		if err == .None {
			self.ready_sequence, self.ready_retry = sequence, false
		}
	}
	if ok && confirmed {
		self.bench[0].tick = truth.tick
		profile_sync(self, &truth)
		paint_started := self.bench[0].active ? gd.time_get_ticks_usec(gd.singleton_time()) : u64(0)
		paint(self, frame, truth, dt)
		if paint_started != 0 {
			bench_note(&self.bench[0], .Paint, gd.time_get_ticks_usec(gd.singleton_time()) - paint_started)
		}
	}
	if self.room.ready {
		observe_recovery(self)
	}
	if confirmed {
		spray_frame(self, truth)
	}
}
