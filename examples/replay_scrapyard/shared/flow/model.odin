package scrapyard_flow

import game "../game"

Kind :: enum {
	None,
	Wave,
	Rest,
	Securing,
	Remaining,
	Clear,
	Depart,
	Over,
}

View :: struct {
	kind: Kind,
	floor: u8,
	wave, total: u16,
	seconds, pending, alive: u32,
	depart_left: u16,
	personal: bool,
	kills, scrap, cores: u32,
}

// A current-state display: reconstruction, late join and migration need no
// remembered transition edge or local wall-clock deadline.
derive :: proc(w: ^game.World, tick: u64, seat: u16) -> (view: View) {
	view.floor, view.wave, view.total = w.floor, w.director.wave, u16(w.wave_count)
	if w.stage == .Staging {
		return
	}
	if seat > 0 && seat <= game.SEATS {
		player := w.players[seat - 1]
		view.personal = player.in_yard
		view.kills, view.scrap, view.cores = player.kills, player.scrap, player.cores
	}
	if w.stage == .Over {
		view.kind = .Over
		return
	}
	if !w.rules.enabled {
		return
	}
	if w.stage == .Clear {
		view.kind = .Clear
		if w.depart.left > 0 {
			view.kind, view.depart_left = .Depart, w.depart.left
			view.seconds = (u32(w.depart.left) + game.HZ - 1) / game.HZ
		}
		return
	}
	view.pending, view.alive = w.director.pending, game.living_enemies(w)
	if w.director.pending == 0 && w.director.alive == 0 && w.director.rest_until > tick {
		view.seconds = u32(min((w.director.rest_until - tick - 1) / u64(game.HZ) + 1, u64(max(u32))))
		if w.director.wave < u16(w.wave_count) {
			view.kind, view.wave = .Rest, w.director.wave + 1
		} else if view.alive == 0 {
			view.kind = .Securing
		} else {
			view.kind = .Remaining
		}
		return
	}
	view.kind = w.director.done ? .Remaining : .Wave
	view.wave = max(view.wave, 1)
	return
}
