package cavecrawl_scripts

// The authority: everything only the HOST runs. Each verb's cross-entity
// half lives in its `<verb>_then` consequence NEXT TO the verb (a command
// proc may only mutate its own target — see chest.odin/spelunker.odin);
// this file keeps the host helpers those consequences call, the game tick
// that decays clocks and deals damage, and the dwellers' thinking. Every
// consequence written to a replicated field travels as a plain delta; no
// file below kit/ knows any of this exists.

import gd "godot:godot"
import rt "godot:runtime"
import kai "godot:kit/ai"
import kboot "godot:kit/boot"
import kcombat "godot:kit/combat"
import kcomms "godot:kit/comms"
import kinter "godot:kit/interact"
import kitems "godot:kit/items"
import knav "godot:kit/nav"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import "core:fmt"


// THE CROSS-ENTITY HALF of looting, host only (fired by chest_take_then): a
// successful take credits the issuer's bag; what doesn't fit goes back in
// the chest.
cave_credit :: proc(self: ^CaveLobby, player: knet.Player_Id, chest: ^Chest, taken: kitems.Slot) {
	av, has := self.avatar_of[player]
	if !has {return}
	sp := self.spelunkers[av]
	credited := kitems.add(&self.table, sp.bag[:], taken.item, taken.count)
	if leftover := taken.count - credited; leftover > 0 {
		_ = kitems.add(&self.table, chest.slots[:], taken.item, leftover)
	}
}

// Host: mint a pickup lying on the floor — THROUGH THE FACTORY, the same
// creation path clients run (make, set the per-spawn fields, send).
@(private = "file")
cave_mint_pickup_at :: proc(self: ^CaveLobby, item: kitems.Item_Id, count: u16, x, y: f32) {
	p, id := pickup_spawn(&self.boot) // typed, from the entity tag — no const, no cast
	p.x = x
	p.y = y
	p.item = item
	p.count = count
	kboot.boot_spawn_send(&self.boot, id)
}

// Host: mint the Pickup a drop left behind (the verb's payload says what;
// the host's view of the dropper's avatar says where).
cave_mint_pickup :: proc(self: ^CaveLobby, sp: ^Spelunker, dropped: kitems.Slot) {
	cave_mint_pickup_at(self, dropped.item, dropped.count, sp.x + 24, sp.y)
}

// Host: damage a spelunker from any source — a rock (attacker credited, a
// chill on survivors) or a dweller's bite (the environment; deaths only).
@(private = "file")
cave_hurt_spelunker :: proc(self: ^CaveLobby, victim_id: knet.Net_Id, victim: ^Spelunker, dmg: i32, attacker: knet.Player_Id, chill: bool) {
	kcombat.credit_hit(&self.ses, self.cols, attacker, dmg)
	if kcombat.hit(&victim.hp, dmg) {
		victim_pid := ksess.session_owner_of(&self.ses, victim_id)
		kcombat.credit_kill(&self.ses, self.cols, attacker, victim_pid)
		cave_spill_bag(self, victim)
		self.respawn_at[victim_id] = self.host_ticks + RESPAWN_TICKS
	} else if chill {
		_ = kcombat.effects_add(victim.fx[:], CHILL, 50, 40) // 2s of cold feet
	}
}

// Host: a dweller falls — credit the game's own "slain" column, drop its
// torch where it died, and tell the director the field thinned. The despawn
// runs cave_free_entity on EVERY role now (node, maps, death burst) — no
// host-side cleanup to repeat here.
@(private = "file")
cave_slay_dweller :: proc(self: ^CaveLobby, id: knet.Net_Id, slayer: knet.Player_Id) {
	dw := self.dwellers[id]
	cave_mint_pickup_at(self, TORCH, 1, dw.x, dw.y)
	if slayer != knet.PLAYER_ID_INVALID {
		ksess.session_stat_add(&self.ses, slayer, self.slain_col, 1)
	}
	_ = dweller_despawn(&self.boot, id)
	kai.director_note_death(&self.director, u64(self.host_ticks), self.waves[:self.waves_n])
	gd.print_str(fmt.tprintf("CAVE_SLAIN left=%d", len(self.dwellers)))
}

// Host: a dweller crawls out of a den (the kit/ai director said when).
@(private = "file")
cave_spawn_dweller :: proc(self: ^CaveLobby) {
	den := self.dens[self.dens_used % len(self.dens)]
	self.dens_used += 1
	d, id := dweller_spawn(&self.boot, owner = self.ses.me)
	d.x = den.x
	d.y = den.y
	d.hp = DWELLER_HP
	kboot.boot_spawn_send(&self.boot, id)
	self.brains[id] = Dweller_Brain{home = den}
	gd.print_str(fmt.tprintf("CAVE_DEN id=%d at=%.0f,%.0f", u32(id), den.x, den.y))
}

// Host: one dweller's step toward a point, AROUND the rift instead of through
// it. kit/nav asks the engine for the polyline; kit/ai walks one tick of it.
//
// The path is re-queried every think tick and thrown away — fresh polyline,
// fresh cursor at 0. That is one map_get_path per dweller per tick (a wave is
// single digits at 20 Hz, against a map already resolved by the caller), and
// it buys two things the cached alternative cannot:
//
//   * NO path state in Dweller_Brain. The brain map is `gd:"backup"` — it
//     rides the takeover snapshot to whoever inherits the host seat. A cached
//     polyline would have to serialize, and a SUCCESSOR would inherit paths
//     computed against a NavigationServer it never ran. Asking again costs one
//     tick and is always correct.
//   * No invalidation on a descent. cave_descend swaps the whole floor's
//     scenery — and with it the nav region — under any dweller still standing;
//     a cached path would be pointing at the floor above.
@(private = "file")
cave_dweller_walk :: proc(self: ^CaveLobby, nav_map: gd.Rid, from, to: [3]f32) -> [3]f32 {
	path := knav.path_2d_on(nav_map, from, to, context.temp_allocator)

	// THE RECEIPT, once per process. The fallback below is silent by design —
	// which means a navmesh that failed to load, or a region that never synced,
	// would leave every dweller walking the old straight line and every test
	// still passing. A path with an interior corner can only come from the mesh
	// (a straight shot returns just its two endpoints), so this line is the
	// acid's proof that the rift is really being walked around and not through.
	if !self.nav_bent && len(path) > 2 {
		self.nav_bent = true
		gd.print_str(fmt.tprintf("CAVE_NAV_BENT points=%d", len(path)))
	}

	idx := 0
	// Cursor 0 on a fresh path: next_point consumes the waypoints already
	// within reach — the first is always the dweller's own position, snapped
	// onto the mesh — and hands back the first one it must actually walk to.
	if goal, ok := knav.next_point(path, &idx, from, DWELLER_SPEED); ok {
		p, _ := kai.step_toward(from, goal, DWELLER_SPEED)
		return p
	}
	// Empty or exhausted. Three ways to land here and one right answer:
	// arrived (the step below caps at `to`, so it is a no-op), unreachable, or
	// the region has not synced into the map yet — it enters the tree with the
	// floor's scenery a few frames before the first den opens, and kit/nav's
	// header says a query that early comes back empty. "Stand still and ask
	// again" would freeze a wave mid-cave, so the dweller falls back to the
	// dumb straight line it walked before this game had a navmesh.
	p, _ := kai.step_toward(from, to, DWELLER_SPEED)
	return p
}

// Host: one think-tick for every dweller — the WHOLE brain, written from
// kit/ai verbs: perceive, then a plain switch. State and position are
// replicated fields; writing them IS the AI's entire network presence.
//
// THIS IS THE ONLY PASS THAT MAY ASK THE NAVIGATION SERVER ANYTHING, and the
// claim below is what makes that enforceable rather than aspirational. The
// server is live engine state that does not rewind, so a pass that replays
// history would path old ticks across today's mesh — and a wrong path steers,
// so the error compounds instead of snapping back.
//
// Today cavecrawl cannot violate that even by accident: it is a delta/stream
// coop game with NO sim lane at all — grep the scripts and there is not one
// `@(gd_tick)` and not one bare `@(gd_step)`, only the single
// `@(gd_step = "authority")` this runs under. Nothing here is ever replayed.
// But "today's game has no rollback" is exactly the kind of reason that rots
// silently, so the claim is made in CODE at the query site: give cavecrawl a
// sim lane later, move the brains into a resimulating pass, and the very first
// path query asserts instead of quietly steering dwellers off a mesh that
// time-travelled.
@(private = "file")
cave_dwellers_think :: proc(self: ^CaveLobby) {
	knav.pass_never_resims() // scoped: closes itself when this proc returns

	// Resolved ONCE for the whole wave — the node-form path_2d would re-walk
	// node -> viewport -> world -> map for every dweller, every tick.
	nav_map := knav.map_2d(self.owner)

	targets := make([dynamic]kai.Target, context.temp_allocator)
	for id, sp in self.spelunkers {
		if sp.hp > 0 {
			append(&targets, kai.Target{id = u32(id), pos = {sp.x, sp.y, 0}})
		}
	}
	for id, dw in self.dwellers {
		brain := self.brains[id]
		if brain.bite_cd > 0 {
			brain.bite_cd -= 1
		}
		pos := [3]f32{dw.x, dw.y, 0}
		seen, spotted := kai.nearest(pos, targets[:], DWELLER_AGGRO)

		state := DWELLER_IDLE
		switch {
		case spotted && dw.hp <= FLEE_BELOW:
			state = DWELLER_FLEE
			// NOT pathed, deliberately: fleeing has a direction, not a
			// destination, and there is nothing to ask the mesh for. A panicked
			// dweller can back itself into the rift — pathing home from in
			// there still works, because map_get_path snaps an off-mesh `from`
			// to the nearest walkable point.
			pos = kai.step_away(pos, seen.pos, DWELLER_SPEED / 2)
		case spotted:
			state = DWELLER_CHASE
			if kai.in_reach(pos, seen.pos, BITE_RANGE) {
				if brain.bite_cd == 0 {
					brain.bite_cd = BITE_CD
					victim_id := knet.Net_Id(seen.id)
					cave_hurt_spelunker(self, victim_id, self.spelunkers[victim_id], BITE_DMG, knet.PLAYER_ID_INVALID, false)
				}
			} else {
				pos = cave_dweller_walk(self, nav_map, pos, seen.pos)
			}
		case:
			pos = cave_dweller_walk(self, nav_map, pos, brain.home)
		}
		dw.x = pos.x
		dw.y = pos.y
		dw.state = state
		self.brains[id] = brain
	}
}

// Host: a grab succeeded (fired by pickup_grab_then) — credit the grabber
// and remove the pickup for everyone (clients free through the factory; the
// host frees its own node).
cave_settle_grab :: proc(self: ^CaveLobby, player: knet.Player_Id, id: knet.Net_Id, grabbed: kitems.Slot) {
	if av, has := self.avatar_of[player]; has {
		sp := self.spelunkers[av]
		_ = kitems.add(&self.table, sp.bag[:], grabbed.item, grabbed.count)
	}
	_ = pickup_despawn(&self.boot, id) // the free proc handles node + maps, every role
}

// (Client commands used to land in a command hook here — a switch over
// entity maps and cmd indices reading scratch fields. Each verb's
// consequence now lives NEXT TO the verb as its `<verb>_then` proc, typed,
// with the wire args and the verb's payload handed in: see chest.odin,
// relic.odin, spelunker.odin, pickup.odin.)

// Host: death spills the whole bag onto the floor — phase 3's pickups are
// suddenly a combat mechanic. (Loot the fallen, or guard them.)
@(private = "file")
cave_spill_bag :: proc(self: ^CaveLobby, sp: ^Spelunker) {
	for slot in sp.bag {
		if slot.item == kitems.ITEM_NONE {continue}
		cave_mint_pickup(self, sp, slot)
	}
	sp.bag = {}
}

// The host's game tick (once per 20 Hz net tick): decay ability clocks and
// effects, regen stamina, fly the rocks, deal the damage, credit the
// ledger, run the respawn clocks. Deltas carry every consequence. The
// attribute is the whole wiring: generated `cave_lobby_step(self, ticks)`
// runs it on the AUTHORITY alone off boot_pump's accumulator, then fires
// the host's fresh edges same-frame — no is_host, no ritual, in game code.
@(gd_step = "authority")
cave_host_tick :: proc(self: ^CaveLobby) {
	self.host_ticks += 1
	for _, sp in self.spelunkers {
		kcombat.abilities_tick(sp.cds[:])
		kcombat.effects_tick(sp.fx[:])
		if self.host_ticks % 20 == 0 && sp.hp > 0 {
			sp.stamina = min(sp.stamina + 1, MAX_STAMINA)
		}
	}

	for i := 0; i < len(self.flying); {
		fl := &self.flying[i]
		from := fl.p.pos
		alive := kcombat.projectile_step(&fl.p)

		targets := make([dynamic]kcombat.Target, context.temp_allocator)
		for id, sp in self.spelunkers {
			if id == self.avatar_of[fl.shooter] || sp.hp <= 0 {continue}
			append(&targets, kcombat.Target{id = u32(id), pos = {sp.x, sp.y, 0}, radius = BODY_RADIUS})
		}
		for id, dw in self.dwellers {
			if dw.hp > 0 {
				append(&targets, kcombat.Target{id = u32(id), pos = {dw.x, dw.y, 0}, radius = BODY_RADIUS})
			}
		}
		if hit, hit_ok := kcombat.projectile_hit(from, fl.p.vel, targets[:]); hit_ok {
			victim_id := knet.Net_Id(hit.id)
			if victim, is_sp := self.spelunkers[victim_id]; is_sp {
				cave_hurt_spelunker(self, victim_id, victim, ROCK_DMG, fl.shooter, true)
			} else if dw, is_dw := self.dwellers[victim_id]; is_dw {
				kcombat.credit_hit(&self.ses, self.cols, fl.shooter, ROCK_DMG)
				if kcombat.hit(&dw.hp, ROCK_DMG) {
					cave_slay_dweller(self, victim_id, fl.shooter)
				}
			}
			unordered_remove(&self.flying, i)
			continue
		}
		if !alive {
			unordered_remove(&self.flying, i)
			continue
		}
		i += 1
	}

	// The dwellers stir: the director paces the waves, the brains think.
	// (The call is HOISTED: an Odin range bound is re-evaluated per
	// iteration, and director_tick has side effects — inlining it in the
	// range silently drains the wave.)
	to_spawn, _ := kai.director_tick(&self.director, u64(self.host_ticks), self.waves[:self.waves_n])
	for _ in 0 ..< to_spawn {
		cave_spawn_dweller(self)
	}
	if w := kai.director_wave(&self.director); w > self.last_wave {
		self.last_wave = w
		kcomms.comms_system(&self.comms, "the dwellers stir")
		gd.print_str(fmt.tprintf("CAVE_WAVE n=%d", w))
	}
	if self.level != nil {
		self.level.wave = u8(kai.director_wave(&self.director))
	}
	cave_dwellers_think(self)

	// Respawn restores STATE; position is owner-streamed, so each OWNER
	// walks out of the grave themselves (see the was_dead edge in process).
	for id, at in self.respawn_at {
		sp := self.spelunkers[id]
		if sp.hp > 0 { // a friend revived them — the bleed-out clock stops
			delete_key(&self.respawn_at, id)
			continue
		}
		if self.host_ticks >= at { // bled out: a fresh body at the spawn
			sp.hp = MAX_HP
			sp.stamina = MAX_STAMINA
			delete_key(&self.respawn_at, id)
		}
	}

	// LEVEL MIGRATION trigger: the floor CLEARED (the director is done) and
	// the whole party, alive, at the open door — the same reach gate the
	// interact prompt uses. Without the cleared gate, opening the door
	// (which you do standing at it) would descend the party on the spot.
	// One check, host only; everything downstream is ordinary despawns,
	// spawns, and deltas.
	if self.level != nil && self.director.done && len(self.spelunkers) > 0 {
		for _, door in self.doors {
			if !door.open {continue}
			all_at_door := true
			for _, sp in self.spelunkers {
				if sp.hp <= 0 || !kinter.in_range({sp.x, sp.y, 0}, {door.x, door.y, 0}, REACH) {
					all_at_door = false
					break
				}
			}
			if all_at_door {
				// The LAST floor's door doesn't go down — it goes OUT.
				if int(self.level.depth) >= self.floors_n {
					cave_win(self)
				} else {
					cave_descend(self)
				}
				break
			}
		}
	}
}
