package kit_net

// edge — delta-lane CHANGE presentation: the machinery behind the generated
// `<class>_<field>_edge` halves. Deltas carry state; one-shot reactions (the
// hurt flash, the goal horn, the floor fanfare) need the TRANSITION — and
// every game used to hand-roll it: a `seen_*` scratch mirror, a compare in
// some per-frame proc, and the re-seed-on-resync footgun beside it. The half
// replaces all three: declare a plain proc named for the field and the
// machinery owns the mirror, the compare, and the resync rule.
//
// THE SEMANTICS, deliberate:
//
//   * NET CHANGE PER FRAME, never per apply. A predicting client legitimately
//     writes a delta-lane field several times inside one frame (optimistic
//     apply, reject-truth, the replay reconcile's unwind→apply→replay) — the
//     half fires once, on what actually changed since the last frame, or not
//     at all when the churn cancels out.
//   * THE DIFF ATOM IS THE FIELD. A tagged POD struct or fixed array is one
//     field (one dirty bit, one wire unit) — so fields that must edge
//     TOGETHER (a scoreboard's l/r/won) are co-located into one struct and
//     receive one half with the whole old/new value: the grouping knob is the
//     data model, not a framework mode.
//   * FIRST SIGHT SEEDS, RESYNC RE-SEEDS — silently. Spawn-time values are a
//     baseline, not an edge; a wholesale catch-up (interest re-entry, a
//     snapshot over live state) is history, not gameplay. Both commit the
//     mirror without firing, which deletes the seen_*-re-seed gotcha whole.
//   * EDGES SAY "IT CHANGED"; FACTS SAY "IT HAPPENED N TIMES". Two hits
//     coalescing into one net tick were always one delta — they are one edge.
//     When multiplicity or arguments matter, that is a FACT: the sim lane's
//     mine-form `_fx`, or a verb.
//
// Delta lane only: predicted fields resim (their facts ride the mine-form
// `_fx`), owner-streamed fields interpolate every frame (dress from fields).
// scriptgen holds that gate at build time.

import "core:mem"

// One generated edge half: cast, deref old, call the author's proc with the
// game pointer (the factory's user — the same `game` every `_then` receives).
Edge_Thunk :: proc(entity: rawptr, game: rawptr, old: rawptr)

Edge_Desc :: struct {
	field: int, // index into Entity_Desc.fields — the diff atom is the FIELD
	fire:  Edge_Thunk,
}

// Byte size of one entity's edge mirror (its edge-declared fields, packed).
@(private)
edge_shadow_size :: proc(set: ^Command_Set) -> int {
	n := 0
	for e in set.edges {
		n += set.entity_desc.fields[e.field].size
	}
	return n
}

// Pack the entity's current edge-field bytes into its mirror.
@(private = "file")
edge_capture :: proc(e: ^Registry_Entry) {
	off := 0
	for ed in e.set.edges {
		f := e.set.entity_desc.fields[ed.field]
		mem.copy(&e.edge_shadow[off], rawptr(uintptr(e.entity) + f.offset), f.size)
		off += f.size
	}
}

// A deferred fire: game code runs AFTER the walk — a half may spawn or
// despawn entities, and firing mid-iteration would mutate the map under us.
@(private = "file")
Edge_Fire :: struct {
	id:   Net_Id,
	edge: int, // index into set.edges
	old:  []u8, // temp copy of the pre-change bytes
}

// The per-frame pass: diff every edge-declaring entity against its mirror,
// commit, then fire the halves for what changed — in descriptor order per
// entity. Call once per frame with the game pointer (the session drives this
// at the end of session_tick, host and client alike: the authority's own
// mutations edge the same way, zero role branches). Returns fires.
registry_edges_tick :: proc(reg: ^Registry, game: rawptr) -> int {
	fires := make([dynamic]Edge_Fire, context.temp_allocator)
	for _, &e in reg.entries {
		if len(e.set.edges) == 0 {
			continue
		}
		if !e.edge_seeded {
			// First sight: the spawn values are the baseline, not an edge.
			edge_capture(&e)
			e.edge_seeded = true
			continue
		}
		off := 0
		for ed, i in e.set.edges {
			f := e.set.entity_desc.fields[ed.field]
			cur := ([^]u8)(rawptr(uintptr(e.entity) + f.offset))
			if mem.compare(cur[:f.size], e.edge_shadow[off:off + f.size]) != 0 {
				old := make([]u8, f.size, context.temp_allocator)
				copy(old, e.edge_shadow[off:off + f.size])
				append(&fires, Edge_Fire{id = e.id, edge = i, old = old})
				// Commit BEFORE firing: a half that mutates its own field
				// simply edges again next frame, never re-enters this one.
				copy(e.edge_shadow[off:off + f.size], cur[:f.size])
			}
			off += f.size
		}
	}
	for fr in fires {
		e, ok := &reg.entries[fr.id]
		if !ok || fr.edge >= len(e.set.edges) {
			continue // an earlier half despawned it: nothing left to present on
		}
		e.set.edges[fr.edge].fire(e.entity, game, raw_data(fr.old))
	}
	return len(fires)
}

// Silent re-seed for ONE entity: a wholesale catch-up (interest re-entry, a
// redundant spawn tuple, a snapshot over live state) is history, not
// gameplay — the mirror adopts the caught-up values without firing. The
// session calls this on its Ev_Resynced path; the old hand-rolled version of
// this rule was net.md's "re-seed your seen_* scratch" gotcha.
registry_edges_commit :: proc(reg: ^Registry, id: Net_Id) {
	if e, ok := &reg.entries[id]; ok && len(e.set.edges) > 0 {
		edge_capture(e)
		e.edge_seeded = true
	}
}
