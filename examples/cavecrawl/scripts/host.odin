package cavecrawl_scripts

// The authority: everything only the HOST runs. The command hook settles the
// cross-entity half of each verb (a command proc may only mutate its own
// target — see chest.odin/spelunker.odin), the game tick decays clocks and
// deals damage, and the dwellers think here. Every consequence written to a
// replicated field travels as a plain delta; no file below kit/ knows any
// of this exists.

import gd "godot:godot"
import rt "godot:runtime"
import kai "godot:kit/ai"
import kcombat "godot:kit/combat"
import kcomms "godot:kit/comms"
import kitems "godot:kit/items"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import "core:fmt"

// THE CROSS-ENTITY HALF of looting, host only (see chest.odin): a successful
// take credits the issuer's bag; what doesn't fit goes back in the chest.
cave_credit :: proc(self: ^CaveLobby, player: knet.Player_Id, chest: ^Chest) {
	av, has := self.avatar_of[player]
	if !has {return}
	sp := self.spelunkers[av]
	credited := kitems.add(&self.table, sp.bag[:], chest.last_take.item, chest.last_take.count)
	if leftover := chest.last_take.count - credited; leftover > 0 {
		_ = kitems.add(&self.table, chest.slots[:], chest.last_take.item, leftover)
	}
}

// Host: mint a pickup lying on the floor.
@(private = "file")
cave_mint_pickup_at :: proc(self: ^CaveLobby, item: kitems.Item_Id, count: u16, x, y: f32) {
	node := spawn_node(self, "res://scripts/pickup.odin")
	p := rt.script_of(node, Pickup)
	p.x = x
	p.y = y
	p.item = item
	p.count = count
	p.net_id = ksess.session_spawn(&self.ses, PICKUP_TYPE, p, &pickup_command_set)
	self.pickups[p.net_id] = p
	self.nodes[p.net_id] = node
}

// Host: mint the Pickup a drop left behind (the dropper's scratch tells us
// what; the host's view of their avatar tells us where).
cave_mint_pickup :: proc(self: ^CaveLobby, sp: ^Spelunker) {
	cave_mint_pickup_at(self, sp.last_drop.item, sp.last_drop.count, sp.x + 24, sp.y)
}

// Host: damage a spelunker from any source — a rock (attacker credited, a
// chill on survivors) or a dweller's bite (the environment; deaths only).
@(private = "file")
cave_hurt_spelunker :: proc(self: ^CaveLobby, victim_id: knet.Net_Id, victim: ^Spelunker, dmg: i32, attacker: knet.Player_Id, chill: bool) {
	kcombat.credit_hit(&self.ses, self.cols, attacker, dmg)
	if kcombat.hit(&victim.hp, dmg) {
		victim_pid := knet.PLAYER_ID_INVALID
		for pid, av in self.avatar_of {
			if av == victim_id {victim_pid = pid}
		}
		kcombat.credit_kill(&self.ses, self.cols, attacker, victim_pid)
		cave_spill_bag(self, victim)
		self.respawn_at[victim_id] = self.host_ticks + RESPAWN_TICKS
	} else if chill {
		_ = kcombat.effects_add(victim.fx[:], CHILL, 50, 40) // 2s of cold feet
	}
}

// Host: a dweller falls — credit the game's own "slain" column, drop its
// torch where it died, and tell the director the field thinned.
@(private = "file")
cave_slay_dweller :: proc(self: ^CaveLobby, id: knet.Net_Id, slayer: knet.Player_Id) {
	dw := self.dwellers[id]
	fx_burst_at(self, dw.x, dw.y, {0.8, 0.4, 1, 1}) // the host's screen; clients burst in cave_free_entity
	cave_mint_pickup_at(self, TORCH, 1, dw.x, dw.y)
	if slayer != knet.PLAYER_ID_INVALID {
		ksess.session_stat_add(&self.ses, slayer, self.slain_col, 1)
	}
	ksess.session_despawn(&self.ses, id)
	if node, ok := self.nodes[id]; ok {
		gd.node_queue_free(node)
		delete_key(&self.nodes, id)
	}
	delete_key(&self.dwellers, id)
	delete_key(&self.brains, id)
	kai.director_note_death(&self.director, u64(self.host_ticks), CAVE_WAVES[:])
	gd.print_str(fmt.tprintf("CAVE_SLAIN left=%d", len(self.dwellers)))
}

// Host: a dweller crawls out of a den (the kit/ai director said when).
@(private = "file")
cave_spawn_dweller :: proc(self: ^CaveLobby) {
	den := DWELLER_DENS[self.dens_used % len(DWELLER_DENS)]
	self.dens_used += 1
	node := spawn_node(self, "res://scripts/dweller.odin")
	d := rt.script_of(node, Dweller)
	d.x = den.x
	d.y = den.y
	d.hp = DWELLER_HP
	d.net_id = ksess.session_spawn(&self.ses, DWELLER_TYPE, d, &dweller_set, owner = self.ses.me)
	self.dwellers[d.net_id] = d
	self.nodes[d.net_id] = node
	self.brains[d.net_id] = Dweller_Brain{home = den}
	gd.print_str(fmt.tprintf("CAVE_DEN id=%d at=%.0f,%.0f", u32(d.net_id), den.x, den.y))
}

// Host: one think-tick for every dweller — the WHOLE brain, written from
// kit/ai verbs: perceive, then a plain switch. State and position are
// replicated fields; writing them IS the AI's entire network presence.
@(private = "file")
cave_dwellers_think :: proc(self: ^CaveLobby) {
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
				pos, _ = kai.step_toward(pos, seen.pos, DWELLER_SPEED)
			}
		case:
			pos, _ = kai.step_toward(pos, brain.home, DWELLER_SPEED)
		}
		dw.x = pos.x
		dw.y = pos.y
		dw.state = state
		self.brains[id] = brain
	}
}

// Host: a grab succeeded — credit the grabber and remove the pickup for
// everyone (clients free through the factory; the host frees its own node).
cave_settle_grab :: proc(self: ^CaveLobby, player: knet.Player_Id, id: knet.Net_Id, p: ^Pickup) {
	if av, has := self.avatar_of[player]; has {
		sp := self.spelunkers[av]
		_ = kitems.add(&self.table, sp.bag[:], p.last_grab.item, p.last_grab.count)
	}
	ksess.session_despawn(&self.ses, id)
	if node, ok := self.nodes[id]; ok {
		gd.node_queue_free(node)
		delete_key(&self.nodes, id)
	}
	delete_key(&self.pickups, id)
}

// Client commands land here right after they execute on the host.
cave_command_hook :: proc(user: rawptr, player: knet.Player_Id, entity: knet.Net_Id, cmd: u16, ok: bool) {
	self := cast(^CaveLobby)user
	if !ok {return}
	if chest, is_chest := self.chests[entity]; is_chest && cmd == 0 {
		cave_credit(self, player, chest)
		return
	}
	if sp, is_spel := self.spelunkers[entity]; is_spel {
		switch cmd {
		case SPEL_CMD_DROP:
			cave_mint_pickup(self, sp)
		case SPEL_CMD_THROW:
			cave_launch_rock(self, player, sp)
		}
		return
	}
	if p, is_pickup := self.pickups[entity]; is_pickup && cmd == 0 {
		cave_settle_grab(self, player, entity, p)
	}
}

// Host: death spills the whole bag onto the floor — phase 3's pickups are
// suddenly a combat mechanic. (Loot the fallen, or guard them.)
@(private = "file")
cave_spill_bag :: proc(self: ^CaveLobby, sp: ^Spelunker) {
	for slot in sp.bag {
		if slot.item == kitems.ITEM_NONE {continue}
		sp.last_drop = slot
		cave_mint_pickup(self, sp)
	}
	sp.bag = {}
}

// The host's game tick (once per 20 Hz net tick): decay ability clocks and
// effects, regen stamina, fly the rocks, deal the damage, credit the
// ledger, run the respawn clocks. Deltas carry every consequence.
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
	to_spawn := kai.director_tick(&self.director, u64(self.host_ticks), CAVE_WAVES[:])
	for _ in 0 ..< to_spawn {
		cave_spawn_dweller(self)
	}
	if w := kai.director_wave(&self.director); w > self.last_wave {
		self.last_wave = w
		kcomms.comms_system(&self.comms, "the dwellers stir")
		gd.print_str(fmt.tprintf("CAVE_WAVE n=%d", w))
	}
	cave_dwellers_think(self)

	// Respawn restores STATE; position is owner-streamed, so each OWNER
	// walks out of the grave themselves (see the was_dead edge in process).
	for id, at in self.respawn_at {
		if self.host_ticks >= at {
			sp := self.spelunkers[id]
			sp.hp = MAX_HP
			sp.stamina = MAX_STAMINA
			delete_key(&self.respawn_at, id)
		}
	}
}
