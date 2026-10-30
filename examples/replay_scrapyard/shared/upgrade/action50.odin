package scrapyard_upgrade

import game "../game"
import net "godot:replay/net"
import assets "godot:replay/assets"
import frozen "../revisions/content50"

Action_50 :: frozen.Action_50

map_action_50 :: proc(old: Action_50) -> (game.Action, bool) {
	if old.kind > .Dash {
		return {}, false
	}
	value := game.Action {
		kind = game.Action_Kind(old.kind),
		profile = {
			meta = {old.profile.meta.cores, old.profile.meta.parts},
			name = {old.profile.name.count, old.profile.name.bytes},
			look = old.profile.look,
			iron = old.profile.iron,
			abilities = old.profile.abilities,
			ready = old.profile.ready,
		},
		ready = old.ready,
		slot = old.slot,
		aim = old.aim,
		aim_is_point = old.aim_is_point,
		item = old.item,
		image = {assets.ID(old.image.id), old.image.bytes},
		development = {
			game.Development_Kind(old.development.kind),
			old.development.seat,
			old.development.amount,
			old.development.status,
		},
	}
	return value, true
}

action_50_valid :: proc(a: Action_50) -> bool {
	value, ok := map_action_50(a)
	return ok && game.action_valid(value)
}

action_50_admit :: proc(user: rawptr, seat: u16, a: Action_50) -> bool {
	value, ok := map_action_50(a)
	return ok && game.development_allowed(false, 0, seat, value)
}

schedule_50 :: proc() -> net.Action_Schedule(Action_50) {
	return {id = 0x5253594441534831, timing = proc(a: Action_50) -> net.Action_Timing {
			return a.kind == .Dash ? .Receipt : .Scheduled
		}}
}
