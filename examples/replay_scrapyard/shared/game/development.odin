package scrapyard_game

import r "godot:replay"
import content "../content"

// Admission is outside replay. The default model refuses development commands;
// a player-hosted tool session may explicitly authorize only its local seat.
// Once admitted, the ordinary action/fact/checkpoint machinery records it.
development_allowed :: proc(enabled: bool, authority_seat, request_seat: u16, action: Action) -> bool {
	return(
		(action.kind != .Dev_Spawn && action.kind != .Dev_Edit) ||
		enabled && authority_seat != 0 && authority_seat <= SEATS && authority_seat == request_seat \
	)
}

// Named payload keeps inspector/tool operations separate from ordinary loadout,
// ability and asset arguments. These values travel through the action ledger.
Development_Kind :: enum u8 {
	Hurt,
	Jam,
	Status,
	Grant_Scrap,
	Grant_Cores,
	Smite,
}

Development :: struct {
	kind: Development_Kind,
	seat: u16,
	amount: u32,
	status: u8,
}

development_valid :: proc(command: Development) -> bool {
	if command.seat == 0 || command.seat > SEATS || command.kind > .Smite {
		return false
	}
	switch command.kind {
	case .Hurt:
		return command.amount > 0 && command.amount <= 255 && command.status == 0
	case .Grant_Scrap, .Grant_Cores:
		return command.amount > 0 && command.amount <= 1000000 && command.status == 0
	case .Status:
		return command.amount == 0 && command.status > 0 && command.status < content.MAX_STATUS
	case .Jam, .Smite:
		return command.amount == 0 && command.status == 0
	}
	return false
}

development_apply :: proc(w: ^World, by: u16, command: Development, ctx: ^r.Step(Event)) -> bool {
	if !development_valid(command) || w.stage == .Staging {
		return false
	}
	index := int(command.seat - 1)
	player := &w.players[index]
	if !player.connected || !player.in_yard {
		return false
	}
	feedback: Notices
	credit := Credit{by, w.players[by - 1].generation}
	switch command.kind {
	case .Hurt:
		hurt_player(w, index, u8(command.amount), player.position, &feedback, ctx)
	case .Jam:
		if player.hp == 0 {
			return false
		}
		player.gun.mode, player.gun.reload_left, player.gun.taps =
			.Jammed, 0, w.catalog.guns[player.gun_id].mechanism.jam_taps
	case .Status:
		if player.hp == 0 || !content.status_present(&w.catalog, command.status) {
			return false
		}
		apply_status(w, player_target(w, index), command.status, credit, &feedback, ctx)
	case .Grant_Scrap:
		if !add_count(&player.scrap, command.amount, ctx) {
			return false
		}
	case .Grant_Cores:
		if !add_count(&player.cores, command.amount, ctx) {
			return false
		}
	case .Smite:
		// The normal death/director/drop/reaction machinery decides when the
		// room clears. Bosses and props are intentionally spared by this tool.
		for alive, i in w.mobs.alive {
			if alive {
				mob := w.mobs.values[i]
				if mob.hp > 0 && mob.kind != 4 && !w.catalog.mobs[mob.kind].prop {
					wound_mob(w, i, 250, credit, &feedback, ctx)
				}
			}
		}
	}
	flush(w, &feedback, ctx)
	return true
}
