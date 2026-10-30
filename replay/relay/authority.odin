package replay_relay

import auth "godot:replay/authority"
import p "godot:replay/provision"

// Membership authorizes relay use; it is not a live gameplay/process lease.
// Current RPC registration and rendezvous still gate actual game participation.
hub_authorize :: proc(user: rawptr, room, content, member: u64) -> (auth.Key, u64, bool) {
	hub := cast(^p.Hub)user
	if hub == nil || !hub.ready || hub.poisoned || hub.config.content != content {return {}, 0, false}
	r := p.hub_room(hub, room)
	if r == nil || r.service.coordinator.poisoned {return {}, 0, false}
	for m, i in r.bundle.record.members {
		if m.identity.member == member {return r.bundle.enrollments[i].key, m.identity.incarnation, m.enabled}
	}
	return {}, 0, false
}
