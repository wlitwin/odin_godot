package kit_sim

// spawn — client-predicted entity spawns (fired projectiles) on the sim lane.
//
// A projectile is everything born-gating (reconcile.odin) and the command loop
// (command.odin) were built toward: you fire, and the shot leaves your screen
// THIS instant — a predicted entity, flying its own arc, reconciled and glided
// like any other — a full round trip before the authority's real projectile
// arrives.
//
// The dance, and why each piece exists:
//
//   * The authority owns net ids (session_spawn), so a client can't name its
//     projectile the real thing yet. lane_spawn_predicted tracks it under a
//     PROVISIONAL id (high-bit tagged, client-local) and stamps it born = this
//     tick — born-gating keeps the reconciles that land before the spawn (the
//     server runs a transit behind, so that is the projectile's whole first
//     round trip) from re-flying it from stale head state.
//   * When the authority's spawn arrives (the reliable Ev_Spawned), the client
//     MATCHES it to the oldest unmatched provisional of that (owner, type) and
//     REKEYS — the same node/struct, now under the real id, its predicted
//     flight ledger intact, a received-truth ledger opened so snapshots
//     reconcile it from here. No second projectile, no pop.
//   * A fire the server REFUSES (an empty magazine the client mispredicted)
//     despawns its provisional the moment the verdict lands (lane_spawn_reject,
//     keyed by the firing command's seq); one that is simply never matched —
//     a lost fire — times out (lane_spawn_sweep). Both self-heal.
//
// V1 matching is FIFO per (owner, type): the authority spawns in command order,
// so its Nth projectile is the client's Nth — and a rejected fire is pruned by
// its verdict before the match consumes it. A burst whose reject races its
// spawns past the FIFO is the documented edge (stamp the spawn with the fire
// seq to make it exact); it self-heals at the next snapshot regardless.

import "core:mem"
import knet "godot:kit/net"
import ksess "godot:kit/session"

// The high bit of a Net_Id marks a client-local provisional spawn — the
// authority's ids increment from 1 and never reach here (2^31 entities).
PROVISIONAL_BIT :: u32(0x8000_0000)

// How long an unmatched provisional rides before it is swept as a lost fire:
// the lane's ring depth (l.slots) — comfortably past a bad round trip, and
// honest when cfg.slots resizes the lane's whole memory (it was a fixed 128).

// A node-free hook: when the lane despawns a provisional (reject or sweep) the
// engine layer must free the node it made for it, keyed by the provisional id.
// nil on the engine-free core (tests own their structs); the boot factory
// installs one.
Spawn_Free_Proc :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr)

lane_set_spawn_free :: proc(l: ^Lane, user: rawptr, free: Spawn_Free_Proc) {
	l.spawn_free_user = user
	l.spawn_free = free
}

// Install the reveal hook (the boot factory does): the lane calls it once per
// watched entity, the tick it first becomes presentable.
lane_set_present_ready :: proc(l: ^Lane, user: rawptr, ready: Present_Ready_Proc) {
	l.present_ready_user = user
	l.present_ready = ready
}

// Is this a provisional (unmatched, client-local) id?
lane_id_provisional :: proc(id: knet.Net_Id) -> bool {
	return u32(id) & PROVISIONAL_BIT != 0
}

// Is `id` still tracked on this lane? A game can ask whether a predicted
// projectile is still alive, or was culled by a refused fire (lane_spawn_reject).
lane_tracks :: proc(l: ^Lane, id: knet.Net_Id) -> bool {
	return cmd_tracked(l, id) != nil
}

// Spawn `entity` PREDICTED — a projectile you just fired, born at the current
// tick, tracked and flown on this client alone until the authority's spawn
// rekeys it. Call it from inside the firing verb's exec (so the tick is the
// command's tick and the seq links the two). Host-side it is a no-op returning
// 0: the authority spawns for real via session_spawn. Returns the provisional id.
lane_spawn_predicted :: proc(
	l: ^Lane,
	entity: rawptr,
	set: ^Sim_Set,
	owner: knet.Player_Id,
	type: ksess.Entity_Type,
	allocator := mem.Allocator{},
) -> knet.Net_Id {
	allocator := allocator.procedure != nil ? allocator : l.allocator // zero = the lane's (see lane_class_add)
	if l.ses.is_host {
		return 0 // the authority spawns for real; prediction is the client's job
	}
	assert(set != nil && set.tick != nil, "a predicted spawn needs a ticking Sim_Set (the projectile flies itself)")
	assert(!l.rewound, "lane_spawn_predicted inside a rewound block — spawning reallocates the track list the restore points into")
	{
		// A reject-chain RE-EXECUTION (cmd_settle re-runs surviving verb
		// bodies) reaches here with this fire's projectile already tracked —
		// still provisional, or already rekeyed by the authority's spawn. A
		// second one is a ghost the FIFO match can never pair: the caller must
		// hand back the existing spawn instead (lane_spawn_of_exec — the
		// boot's spawn door does).
		_, _, exists := lane_spawn_of_exec(l)
		assert(!exists, "this fire already has its projectile (a reject-chain re-execution) — reuse it via lane_spawn_of_exec instead of spawning a ghost (boot_spawn_predicted does)")
	}
	l.spawn_next += 1
	id := knet.Net_Id(PROVISIONAL_BIT | l.spawn_next)
	born := l.step_tick // spawned inside the tick pipeline: this is the fire tick
	hist := new(History, allocator)
	hist^ = history_make(set.entity_desc, l.slots, allocator)
	append(&l.tracked, Tracked {
		id = id, entity = entity, desc = set.entity_desc, owner = owner,
		hist = hist, tick = set.tick, has_in = set.input_size > 0, in_class = set.input_class, cmds = set.commands, set = set,
		born = born, provisional = true, spawn_seq = l.cmd_exec_seq, spawn_type = type,
	})
	append(&l.entries, Entry{id = id, entity = entity, hist = hist, born = born})
	return id
}

// The authority's spawn arrived: if it matches a provisional we predicted,
// REKEY that one to the real id and return (its entity, true) — the caller
// reuses the node it already made, never a second one. (nil, false) means we
// predicted nothing for it (a remote player's projectile, or our own we failed
// to predict): the caller spawns it normally, watched or predicted as usual.
lane_spawn_match :: proc(
	l: ^Lane,
	auth_id: knet.Net_Id,
	owner: knet.Player_Id,
	type: ksess.Entity_Type,
	allocator := mem.Allocator{},
) -> (entity: rawptr, from: knet.Net_Id, ok: bool) {
	allocator := allocator.procedure != nil ? allocator : l.allocator // zero = the lane's (see lane_class_add)
	// Oldest unmatched of this (owner, type) — lowest provisional id, FIFO with
	// the authority's in-order spawns.
	best := -1
	best_id := max(u32)
	for &tr, i in l.tracked {
		if !tr.provisional || tr.owner != owner || tr.spawn_type != type {
			continue
		}
		if u32(tr.id) < best_id {
			best_id = u32(tr.id)
			best = i
		}
	}
	if best < 0 {
		return nil, 0, false
	}
	tr := &l.tracked[best]
	prov := tr.id
	tr.id = auth_id
	tr.provisional = false
	for &e in l.entries {
		if e.id == prov {
			e.id = auth_id
			break
		}
	}
	// Open a received-truth ledger for the real id so snapshots reconcile the
	// projectile from here (its predicted-flight ledger, tr.hist, is untouched).
	snap_rx_add(&l.rx, auth_id, tr.desc, allocator)
	return tr.entity, prov, true
}

// The spawn already minted by the command executing RIGHT NOW, if any —
// still provisional, or already rekeyed to the authority's id (spawn_seq
// survives the rekey). Meaningful only inside a verb exec (l.cmd_exec_seq
// is set). The reject-chain's settle (cmd_settle) re-runs surviving verb
// bodies whose projectile still flies: a caller about to spawn asks here
// first and reuses the existing one — minting a second would be a ghost the
// FIFO match can never pair (and the ghost would coast until the sweep).
lane_spawn_of_exec :: proc(l: ^Lane) -> (entity: rawptr, id: knet.Net_Id, ok: bool) {
	if l.cmd_exec_seq == 0 || l.ses.is_host {
		return nil, 0, false
	}
	for &tr in l.tracked {
		if tr.spawn_seq == l.cmd_exec_seq {
			return tr.entity, tr.id, true
		}
	}
	return nil, 0, false
}

// The fire the server refused: despawn the provisional it spawned (keyed by the
// firing command's seq). Returns its entity so the caller frees the node
// (or the installed spawn_free hook does). nil = this fire spawned nothing.
lane_spawn_reject :: proc(l: ^Lane, seq: u32) -> rawptr {
	for tr in l.tracked {
		if tr.provisional && tr.spawn_seq == seq {
			despawn_provisional(l, tr.id, tr.entity)
			return tr.entity
		}
	}
	return nil
}

// Sweep provisionals no authority spawn ever claimed — a lost fire. Call once
// per client frame. Despawned entities are freed through the spawn_free hook
// (and appended to `out`, if given, for a caller that frees nodes itself).
lane_spawn_sweep :: proc(l: ^Lane, out: ^[dynamic]rawptr = nil) {
	for i := 0; i < len(l.tracked); {
		tr := l.tracked[i]
		if tr.provisional && l.ticker.tick > tr.born + u64(l.slots) {
			if out != nil {
				append(out, tr.entity)
			}
			despawn_provisional(l, tr.id, tr.entity)
			continue // the slice shifted; don't advance
		}
		i += 1
	}
}

@(private = "file")
despawn_provisional :: proc(l: ^Lane, id: knet.Net_Id, entity: rawptr) {
	lane_untrack(l, id) // removes the tracked + entry, frees the ledger (rx is a no-op)
	if l.spawn_free != nil {
		l.spawn_free(l.spawn_free_user, id, entity)
	}
}
