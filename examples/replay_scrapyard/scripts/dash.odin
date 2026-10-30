package replay_scrapyard

import gd "godot:godot"
import net "godot:replay/net"
import rgd "godot:replay/godot"

dash_reset :: proc(self: ^ReplayScrapyard) {
	self.dash_next = false
	net.intent_reset(&self.dash_intent[0])
	net.intent_reset(&self.turret_intent[0])
}

dash_submit :: proc(self: ^ReplayScrapyard) {
	sequence: u64
	error: net.Error
	if self.room.ready {
		sequence, error = rgd.room_intent(&self.room, &self.dash_intent[0])
	} else {
		sequence, error = rgd.session_intent(self.session, &self.dash_intent[0])
	}
	if error != .None || sequence == 0 {
		return
	}
	self.dash_next = false
	self.buttons.pressed &= ~u64(1)
}

@(gd_method)
replay_scrapyard_dash_probe :: proc(self: ^ReplayScrapyard, key: string) -> gd.Int {
	intent := &self.dash_intent[0]
	switch key {
	case "submitted":
		return gd.Int(intent.submitted)
	case "confirmed":
		return gd.Int(intent.confirmed)
	case "refused":
		return gd.Int(intent.refused)
	case "pending":
		return gd.Int(intent.pending_count)
	case "captured":
		return gd.Int(intent.captured)
	case "reason":
		return gd.Int(intent.last.reason)
	case "retired":
		return gd.Int(intent.retired)
	case "unknown":
		return gd.Int(intent.unknown)
	}
	return -1
}
