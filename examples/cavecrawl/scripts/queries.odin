package cavecrawl_scripts

// Read-only windows into this peer's view of the world — what HUDs render
// and what the test drivers assert against. Everything here reads replicated
// state (plus the predicted-hp overlay); nothing mutates.

import gd "godot:godot"
import kcombat "godot:kit/combat"
import kitems "godot:kit/items"
import ksess "godot:kit/session"
import "core:math"

// What this peer DRAWS for an hp: truth plus any predicted dip from impacts
// seen on this screen (kcombat.php_display squares it with deltas).
hp_view :: proc(sp: ^Spelunker) -> i32 {
	return kcombat.php_display(&sp.php, sp.hp, now_s())
}

@(gd_method)
cave_lobby_my_hp :: proc(self: ^CaveLobby) -> gd.Int {
	if self.me_spel == nil {return 0}
	return gd.Int(hp_view(self.me_spel))
}

// The other spelunker's hp, as this peer sees it (2-player test scaffolding).
@(gd_method)
cave_lobby_their_hp :: proc(self: ^CaveLobby) -> gd.Int {
	my_av := self.avatar_of[self.ses.me]
	for id, sp in self.spelunkers {
		if id != my_av {
			return gd.Int(hp_view(sp))
		}
	}
	return 0
}

// The other spelunker's position, as this peer sees it.
@(gd_method)
cave_lobby_their_pos :: proc(self: ^CaveLobby) -> gd.Vector2 {
	my_av := self.avatar_of[self.ses.me]
	for id, sp in self.spelunkers {
		if id != my_av {
			return {sp.x, sp.y}
		}
	}
	return {}
}

@(gd_method)
cave_lobby_can_throw :: proc(self: ^CaveLobby) -> gd.Bool {
	me := self.me_spel
	if me == nil || me.hp <= 0 {return false}
	return gd.Bool(kcombat.ability_ready(me.cds[:], 0) && me.stamina >= ROCK_ABILITY.cost)
}

@(gd_method)
cave_lobby_pickups :: proc(self: ^CaveLobby) -> gd.Int {
	return gd.Int(len(self.pickups))
}

@(gd_method)
cave_lobby_rocks :: proc(self: ^CaveLobby) -> gd.Int {
	return gd.Int(len(self.tracers.live))
}

@(gd_method)
cave_lobby_dwellers :: proc(self: ^CaveLobby) -> gd.Int {
	return gd.Int(len(self.dwellers))
}

// The angriest mood on the field (0 idle, 1 chase, 2 flee) — replicated
// state, so any peer can watch a dweller lock on.
@(gd_method)
cave_lobby_dweller_mood :: proc(self: ^CaveLobby) -> gd.Int {
	mood := u8(0)
	for _, d in self.dwellers {
		mood = max(mood, d.state)
	}
	return gd.Int(mood)
}

@(gd_method)
cave_lobby_dweller_pos :: proc(self: ^CaveLobby) -> gd.Vector2 {
	if self.me_spel == nil {return {}}
	best := gd.Vector2{}
	best_d := max(f32)
	for _, d in self.dwellers {
		dx := d.x - self.me_spel.x
		dy := d.y - self.me_spel.y
		if dd := dx * dx + dy * dy; dd < best_d {
			best_d = dd
			best = {d.x, d.y}
		}
	}
	return best
}

// Aim helper for drivers/keybinds: unit vector from me to the nearest
// dweller ({0,0} when the cave is quiet).
@(gd_method)
cave_lobby_dweller_dir :: proc(self: ^CaveLobby) -> gd.Vector2 {
	if self.me_spel == nil || len(self.dwellers) == 0 {return {}}
	p := cave_lobby_dweller_pos(self)
	dx := p.x - self.me_spel.x
	dy := p.y - self.me_spel.y
	n := math.sqrt(dx * dx + dy * dy)
	if n == 0 {return {}}
	return {dx / n, dy / n}
}

@(gd_method)
cave_lobby_get_players :: proc(self: ^CaveLobby) -> gd.Int {
	return gd.Int(ksess.session_count(&self.ses, connected_only = true))
}

@(gd_method)
cave_lobby_is_seated :: proc(self: ^CaveLobby) -> gd.Bool {
	return gd.Bool(self.ses.joined)
}

// The world reached this peer: my avatar + everyone else's + chest + door.
@(gd_method)
cave_lobby_world_ready :: proc(self: ^CaveLobby) -> gd.Bool {
	return gd.Bool(
		self.started &&
		self.me_spel != nil &&
		len(self.spelunkers) >= ksess.session_count(&self.ses, connected_only = true) &&
		len(self.chests) > 0 &&
		len(self.doors) > 0,
	)
}

// 0 none, 1 chest, 2 door — what the prompt points at (drives test walking).
@(gd_method)
cave_lobby_prompt_kind :: proc(self: ^CaveLobby) -> gd.Int {
	return gd.Int(self.target_kind)
}

@(gd_method)
cave_lobby_my_gems :: proc(self: ^CaveLobby) -> gd.Int {
	if self.me_spel == nil {return 0}
	return gd.Int(kitems.count_of(self.me_spel.bag[:], GEM))
}

@(gd_method)
cave_lobby_my_torches :: proc(self: ^CaveLobby) -> gd.Int {
	if self.me_spel == nil {return 0}
	return gd.Int(kitems.count_of(self.me_spel.bag[:], TORCH))
}

// Every gem this peer can see anywhere — the conservation check.
@(gd_method)
cave_lobby_world_gems :: proc(self: ^CaveLobby) -> gd.Int {
	total := 0
	for _, c in self.chests {
		total += kitems.count_of(c.slots[:], GEM)
	}
	for _, sp in self.spelunkers {
		total += kitems.count_of(sp.bag[:], GEM)
	}
	for _, p in self.pickups {
		if p.item == GEM {
			total += int(p.count)
		}
	}
	return gd.Int(total)
}

// Items still sitting in chests, as this peer sees them.
@(gd_method)
cave_lobby_chest_items :: proc(self: ^CaveLobby) -> gd.Int {
	total := 0
	for _, c in self.chests {
		for s in c.slots {
			total += int(s.count)
		}
	}
	return gd.Int(total)
}

@(gd_method)
cave_lobby_door_open :: proc(self: ^CaveLobby) -> gd.Bool {
	for _, d in self.doors {
		return gd.Bool(d.open)
	}
	return false
}

@(gd_method)
cave_lobby_my_pos :: proc(self: ^CaveLobby) -> gd.Vector2 {
	if self.me_spel == nil {return {}}
	return {self.me_spel.x, self.me_spel.y}
}

// Which floor this peer believes the run is on (0 before the world exists).
@(gd_method)
cave_lobby_depth :: proc(self: ^CaveLobby) -> gd.Int {
	if self.level == nil {return 0}
	return gd.Int(self.level.depth)
}

// The director's current wave, replicated — campaign progress any peer can
// key off without racing entity counts.
@(gd_method)
cave_lobby_wave :: proc(self: ^CaveLobby) -> gd.Int {
	if self.level == nil {return 0}
	return gd.Int(self.level.wave)
}
