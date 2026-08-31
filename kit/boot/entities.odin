package kit_boot

// boot_entities — the factory, written by nobody.
//
// Every game's make/free pair was the same six lines per entity type:
// instantiate the exported scene under boot.world, remember the node by id,
// script_of the struct, return it with its command set; free walked it all
// back. The declaration now lives where the house puts declarations — a tag
// on the exported scene field:
//
//     mob_scene: ^gd.Resource `gd:"entity=Mob:3"`,
//
// scriptgen turns those tags into `<snake>_entity_kinds` (plus the
// `MOB_TYPE :: ksess.Entity_Type(3)` constants games used to hand-keep) and a
// typed install wrapper, `<snake>_entities`, that hands this driver the table
// AND the class's generated event dispatcher — the dispatcher is what lets
// the authority's own spawns be BORN AT THE SEND (boot_born below):
//
//     // ready(), AFTER boot_attach (the factory parents under b.world):
//     scrapyard_entities(self, &self.boot)
//     // the raw door: kboot.boot_entities(&self.boot, self, <table>[:], <events or nil>)
//
// The genuinely game-shaped halves stay yours, as name-paired TYPED hooks
// scriptgen wires into the table (both optional, per entity):
//
//     mob_spawned :: proc(game: ^Scrapyard, self: ^Mob, id: knet.Net_Id, owner: knet.Player_Id) {
//         game.mobs[id] = self          // bookkeeping — fields NOT set yet;
//     }                                 // presentation belongs on Ev_Spawned
//     mob_freed :: proc(game: ^Scrapyard, self: ^Mob, id: knet.Net_Id) {
//         delete_key(&game.mobs, id)    // fields still readable, node still
//     }                                 // alive — death fx go here
//
// The scene is read THROUGH the field at spawn time, so editor wiring, live
// reassignment, and hot reload keep working. `session_set_factory` remains
// the escape hatch for exotic creation — installing it after boot_entities
// simply replaces the driver.

import gd "godot:godot"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import ksim "godot:kit/sim"
import "core:fmt"

// One row of the generated table — pure data, no state (state lives on Boot;
// generated code has no globals to fork across script dlls).
Entity_Kind :: struct {
	type:         ksess.Entity_Type,
	name:         string, // "Mob" — diagnostics only
	set:          ^knet.Command_Set,
	script_of:    proc(node: gd.Node) -> rawptr, // generated typed rt.script_of thunk
	scene_offset: uintptr, // the ^gd.Resource field's offset on the GAME struct
	spawned:      proc(game: rawptr, entity: rawptr, id: knet.Net_Id, owner: knet.Player_Id), // nil = no hook
	freed:        proc(game: rawptr, entity: rawptr, id: knet.Net_Id), // nil = no hook
	sim_set:      ^ksim.Sim_Set, // generated from @(gd_tick); with boot_lane the
	                             // factory tracks/untracks the entity on the lane itself
	// Declared knobs off the tag's trailing tokens:
	stream_hz:    int,  // `entity=Mob:3,stream_hz=30` — the kind's owner-stream rate, installed
	                    // on the session per TYPE (session_set_type_stream_hz) so every spawn
	                    // on every peer — the heir's resume rebuild included — carries it
	avatar:       bool, // `entity=Runner:2,avatar` — this kind is a SEAT'S BODY, not an NPC:
	                    // a host takeover parks it with its seat (reclaimable) instead of
	                    // adopting it like the dead host's NPCs (session_set_avatar_type)
}

// The game's session-event dispatcher behind a rawptr — the generated
// `<game>_events` thunked (scriptgen emits it beside the kind table). Handing
// it to boot_entities is what turns on BORN AT THE SEND for the authority.
Events_Proc :: proc(game: rawptr, events: []ksess.Event)

// Install the table as the session's factory. `game` is the struct carrying
// the tagged scene fields (scene_offset resolves against it) — it is also
// named as the session's game pointer, so `<verb>_then` consequences keep
// receiving the game, not this driver.
//
// `events` (the generated `<game>_entities` wrapper passes it; the raw door
// defaults to nil) is the game's event dispatcher. With it, the AUTHORITY's
// own spawns are BORN AT THE SEND: `<game>_entity_spawned` runs inside
// boot_spawn_send, before it returns — the symmetric guarantee to a client's
// (whose make → fields → Ev_Spawned is one synchronous flow) — so no engine
// callback (render, a physics step, a later _process) can ever see the host's
// node parented but undressed. Without it the host hears its own spawns from
// the next pump's batch, which for any spawn made AFTER the pump (a host
// step, a timer, a later _process) is the NEXT frame: one rendered frame at
// the scene's default pose. A hand-rolled game that drains the batch itself
// passes nil and keeps the queue; one that passes a dispatcher must not ALSO
// expect the host's Ev_Spawned in boot_pump's events — it is delivered here.
boot_entities :: proc(b: ^Boot, game: rawptr, kinds: []Entity_Kind, events: Events_Proc = nil) {
	assert(b.ses != nil, "boot_entities comes AFTER boot_attach — it installs the factory on the attached session")
	assert(game != nil, "boot_entities needs the game struct — its tagged scene fields are the table's scenes")
	b.ent_kinds = kinds
	b.ent_game = game
	b.ent_events = events
	ksess.session_set_factory(b.ses, b, boot_make_entity, boot_free_entity)
	ksess.session_set_game(b.ses, game)
	// The kinds' declared knobs become session wiring (pre-start, survives
	// re-init like the factory): a per-type stream rate, and which kinds are
	// seats' bodies.
	for &k in kinds {
		if k.stream_hz > 0 {
			ksess.session_set_type_stream_hz(b.ses, k.type, k.stream_hz)
		}
		if k.avatar {
			ksess.session_set_avatar_type(b.ses, k.type, true)
		}
	}
	// Only with a dispatcher to hand the event to — a nil hook keeps the
	// session's queue path, so a batch-draining game never silently loses
	// its own spawns.
	ksess.session_set_born(b.ses, b, events != nil ? boot_born : nil)
}

// The authority's spawn is BORN (kit/session's born hook, installed above):
// the fields are set and announced — dress it NOW, inside the spawn site's
// call. The game's dispatcher runs on a one-element batch, so the SAME
// `<game>_entity_spawned` half fires, with the same role gate, as it would
// from boot_pump's batch on any other peer. Two things boot_forward's
// Ev_Spawned arm does NOT happen here on purpose: (1) the phase latch is
// deferred to the next pump (world_pending — boot_phase rises only in
// boot_pump, the level games edge-detect across it); (2) nothing is queued —
// the host's own Ev_Spawned is not in that frame's batch. Re-entrant by
// construction: the census already ran at make, the registry row exists, a
// handler that spawns again just recurses this door.
@(private = "file")
boot_born :: proc(user: rawptr, ev: ksess.Ev_Spawned) {
	b := cast(^Boot)user
	b.world_pending = true
	one := [1]ksess.Event{ev}
	b.ent_events(b.ent_game, one[:])
}

// The node an entity rides — what the hand-written `nodes[id]` map was for
// (dressing a newborn, parenting a nameplate, flashing a hit).
boot_node :: proc(b: ^Boot, id: knet.Net_Id) -> (gd.Node, bool) {
	node, ok := b.ent_nodes[id]
	return node, ok
}

// ---------------------------------------------------------------------------
// The census, without game-side maps. Every game kept `map[Net_Id]^T` + an
// owner mirror + an avatar_of mirror beside the factory — bookkeeping of
// state the kit already holds (the registry's entity + owner, this ledger's
// type). These queries read it back; scriptgen wraps them per `entity=` tag
// as typed `<snake>_of` / `<snake>_mine` / `<snake>_owned_by` /
// `<snake>_all`, so census hooks shrink to genuinely game-shaped
// bookkeeping (or vanish). A per-type linked index makes a kind query walk
// only that kind; generated iteration resolves entity + owner in one pass.

// Resolve the entity and owner together. Authoritative ids live in the
// session registry; client-predicted spawns live only on the sim lane until
// their real spawn arrives and rekeys them. The type ledger gates BOTH before
// the cast, so an id of another kind can never be mis-cast.
@(private = "file")
boot_entity_canonical :: proc(b: ^Boot, id: knet.Net_Id) -> knet.Net_Id {
	if to, rekeyed := b.ent_alias[id]; rekeyed {
		return to
	}
	return id
}

@(private = "file")
boot_entity_raw :: proc(b: ^Boot, id: knet.Net_Id, type: ksess.Entity_Type) -> (entity: rawptr, owner: knet.Player_Id, ok: bool) {
	cid := boot_entity_canonical(b, id)
	t, tracked := b.ent_types[cid]
	if !tracked || t != type {
		return nil, knet.PLAYER_ID_INVALID, false
	}
	if b.ses != nil {
		if e, found := knet.registry_get(&b.ses.reg, cid); found {
			return e.entity, e.owner, true
		}
	}
	if b.lane != nil {
		if e, found := ksim.lane_entity(b.lane, cid); found {
			return e, ksim.lane_owner_of(b.lane, e), true
		}
	}
	return nil, knet.PLAYER_ID_INVALID, false
}

// The entity behind an id, IF it is of `type` (a stale id or a different
// kind returns false rather than a mis-cast).
boot_entity :: proc(b: ^Boot, id: knet.Net_Id, type: ksess.Entity_Type) -> (rawptr, bool) {
	e, _, ok := boot_entity_raw(b, id, type)
	return e, ok
}

// Who owns an entity (PLAYER_ID_INVALID = host-owned / unknown id) — the
// `owner_pid` map every world pass hand-kept.
boot_entity_owner :: proc(b: ^Boot, id: knet.Net_Id) -> knet.Player_Id {
	cid := boot_entity_canonical(b, id)
	if type, tracked := b.ent_types[cid]; tracked {
		_, owner, ok := boot_entity_raw(b, cid, type)
		if ok {
			return owner
		}
	}
	return knet.PLAYER_ID_INVALID
}

// A player's singular entity of `type` — the `avatar_of` map. Zero matches is
// false; one is the answer; two is an invalid question, not permission to pick
// whichever Net_Id happens to sort first. Call the generated `<type>_all` and
// select explicitly when ownership is plural.
boot_owned_entity :: proc(b: ^Boot, type: ksess.Entity_Type, owner: knet.Player_Id) -> (entity: rawptr, id: knet.Net_Id, ok: bool) {
	if owner == knet.PLAYER_ID_INVALID {
		return nil, 0, false
	}
	found: rawptr
	found_id := knet.NET_ID_INVALID
	has_found := false
	for eid := b.ent_heads[type]; eid != knet.NET_ID_INVALID; eid = b.ent_next[eid] {
		if e, found_owner, live := boot_entity_raw(b, eid, type); live && found_owner == owner {
			if has_found {
				assert(
					false,
					fmt.tprintf(
						"entity kind %d ownership is plural for player %d (ids %d and %d) — the singular *_mine/*_owned_by query cannot choose; enumerate *_all and select explicitly",
						u16(type), u64(owner), u64(found_id), u64(eid),
					),
				)
				// Release builds still reject ambiguity instead of silently
				// returning the first row after assertions are disabled.
				return nil, 0, false
			}
			found = e
			found_id = eid
			has_found = true
		}
	}
	return found, found_id, has_found
}

// The typed, one-pass census behind generated `<snake>_all`. T is named
// by the entity= tag at generation time; boot_entity_raw still checks the
// runtime kind before any cast. Rows are a temp snapshot: retain `.ref`, not
// `.entity`, if the value must cross a despawn boundary.
boot_entity_rows :: proc(
	b: ^Boot,
	type: ksess.Entity_Type,
	$T: typeid,
	allocator := context.temp_allocator,
) -> []knet.Net_Entity(T) {
	rows := make([dynamic]knet.Net_Entity(T), allocator)
	for eid := b.ent_heads[type]; eid != knet.NET_ID_INVALID; eid = b.ent_next[eid] {
		if e, owner, live := boot_entity_raw(b, eid, type); live {
			append(&rows, knet.Net_Entity(T) {
				ref = {id = eid},
				entity = cast(^T)e,
				owner = owner,
			})
		}
	}
	return rows[:]
}

// Maintain the sorted per-kind linked index and the lifetime/type ledger as
// one operation. Net_Id zero is the end sentinel; authority ids are positive
// and provisional ids reserve the high bit, so every live id is representable.
@(private = "file")
boot_entity_track :: proc(b: ^Boot, type: ksess.Entity_Type, id: knet.Net_Id) {
	assert(id != knet.NET_ID_INVALID)
	_, exists := b.ent_types[id]
	assert(!exists, "boot entity tracked twice")

	prev := knet.NET_ID_INVALID
	next := b.ent_heads[type]
	for next != knet.NET_ID_INVALID && next < id {
		prev = next
		next = b.ent_next[next]
	}
	b.ent_types[id] = type
	b.ent_prev[id] = prev
	b.ent_next[id] = next
	if prev == knet.NET_ID_INVALID {
		b.ent_heads[type] = id
	} else {
		b.ent_next[prev] = id
	}
	if next != knet.NET_ID_INVALID {
		b.ent_prev[next] = id
	}
}

@(private = "file")
boot_entity_forget :: proc(b: ^Boot, id: knet.Net_Id) -> bool {
	cid := boot_entity_canonical(b, id)
	type, tracked := b.ent_types[cid]
	if !tracked {
		return false
	}
	prev := b.ent_prev[cid]
	next := b.ent_next[cid]
	if prev == knet.NET_ID_INVALID {
		if next == knet.NET_ID_INVALID {
			delete_key(&b.ent_heads, type)
		} else {
			b.ent_heads[type] = next
		}
	} else {
		b.ent_next[prev] = next
	}
	if next != knet.NET_ID_INVALID {
		b.ent_prev[next] = prev
	}
	delete_key(&b.ent_prev, cid)
	delete_key(&b.ent_next, cid)
	delete_key(&b.ent_types, cid)
	// A real despawn retires every provisional handle that was rekeyed to it.
	for from, to in b.ent_alias {
		if to == cid {
			delete_key(&b.ent_alias, from)
		}
	}
	return true
}

@(private = "file")
boot_entity_rekey :: proc(b: ^Boot, from, to: knet.Net_Id) {
	type, tracked := b.ent_types[from]
	assert(tracked, "boot entity rekey source is not tracked")
	assert(boot_entity_forget(b, from))
	boot_entity_track(b, type, to)
	b.ent_alias[from] = to
}

// Free every entity node and forget the ledger — the back-to-lobby / host-
// takeover wipe ("the factory is about to rebuild them"). The SESSION's
// registry is torn down by its own re-init; this clears the engine half.
boot_entities_clear :: proc(b: ^Boot) {
	for _, node in b.ent_nodes {
		gd.node_queue_free(node)
	}
	clear(&b.ent_nodes)
	clear(&b.ent_types)
	clear(&b.ent_heads)
	clear(&b.ent_next)
	clear(&b.ent_prev)
	clear(&b.ent_alias)
}

@(private = "file")
boot_make_entity :: proc(user: rawptr, type: ksess.Entity_Type, id: knet.Net_Id, owner: knet.Player_Id) -> (rawptr, ^knet.Command_Set) {
	b := cast(^Boot)user
	for &k in b.ent_kinds {
		if k.type != type {continue}
		// PREDICTED-SPAWN MATCH: a projectile WE fired is already on our screen,
		// flying under a provisional id — reuse it (rekey our node to the real
		// one), never a second. The lane already rekeyed its tracking + opened a
		// received-truth ledger; here we just carry the node ledger across.
		if b.lane != nil {
			if entity, from, matched := ksim.lane_spawn_match(b.lane, id, owner, type); matched {
				if node, ok := b.ent_nodes[from]; ok {
					b.ent_nodes[id] = node
					delete_key(&b.ent_nodes, from)
				}
				boot_entity_rekey(b, from, id)
				return entity, k.set
			}
		}
		scene := (cast(^^gd.Resource)(uintptr(b.ent_game) + k.scene_offset))^
		assert(
			cast(rawptr)scene != nil,
			fmt.tprintf("entity %s (type %d): its tagged scene field is nil — assign the PackedScene in the Inspector", k.name, u16(type)),
		)
		node := gd.instantiate(cast(gd.Packed_Scene)scene)
		entity := k.script_of(node)
		assert(
			entity != nil,
			fmt.tprintf("entity %s (type %d): the scene's root does not carry the %s script — attach it in the editor", k.name, u16(type), k.name),
		)
		gd.add_child(b.world, node)
		b.ent_nodes[id] = node
		boot_entity_track(b, type, id)
		if k.spawned != nil {
			// Bookkeeping-time, like the hand factories were: the entity exists
			// but its spawn-time FIELDS are not set yet — track it, don't dress
			// it (dressing belongs on Ev_Spawned, which fires once fields land).
			k.spawned(b.ent_game, entity, id, owner)
		}
		if k.sim_set != nil {
			// A ticking entity with no lane would spawn, render, and never
			// simulate — the silent version of the wiring mistake the sibling
			// assert (boot_spawn_predicted) already names. Name it here too.
			assert(
				b.lane != nil,
				fmt.tprintf("entity %s ticks (@(gd_tick)) but the boot has no lane — wire `<game>_lane_init` + kboot.boot_lane before entities spawn", k.name),
			)
			// The sim-lane line nobody writes anymore: predicted on its
			// owner's screen, truth-ledgered on the host, watched elsewhere.
			ksim.lane_track_set(b.lane, id, entity, k.sim_set, owner)
			// A watched (remote-owned) sim entity renders on the DELAYED clock,
			// so it should not appear until that clock reaches its spawn — a
			// fresh muzzle's shot must emerge as the delayed barrel fires it, not
			// a render delay early (which reads as a pause at the barrel). Hide
			// it now; lane_present's present_ready hook reveals it on cue.
			// Contested objects present their predicted pose immediately, so they
			// are never hidden; the owner's own predicted entities aren't either.
			if !ksim.lane_is_authority(b.lane) && owner != ksim.lane_me(b.lane) && !k.sim_set.contested {
				gd.set_bool(cast(gd.Object)node, "visible", false)
			}
		}
		return entity, k.set
	}
	// Unknown type: skipped whole by the session (the wire carries lengths) —
	// an OLD build meeting a NEW entity degrades to not seeing it, same
	// forward-compatibility contract the hand factories kept.
	return nil, nil
}

@(private = "file")
boot_free_entity :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) {
	b := cast(^Boot)user
	type, tracked := b.ent_types[id]
	if tracked {
		for &k in b.ent_kinds {
			if k.type != type {continue}
			if k.freed != nil {
				// Before the node dies: the struct's fields and the node are
				// both still alive, so death fx and map cleanup see the entity
				// as it was.
				k.freed(b.ent_game, entity, id)
			}
			break
		}
	}
	if b.lane != nil {
		ksim.lane_untrack(b.lane, id) // no-op for entities the lane never tracked
	}
	if node, ok := b.ent_nodes[id]; ok {
		gd.node_queue_free(node)
		delete_key(&b.ent_nodes, id)
	}
	_ = boot_entity_forget(b, id)
}

// ---------------------------------------------------------------------------
// Predicted spawns — a fired projectile (kit/sim spawn.odin). The client makes
// the node and flies it THIS instant; the authority's real spawn rekeys it
// (boot_make_entity's match) a round trip later. See docs/kit/sim.md.

// Spawn a projectile the client PREDICTS and the authority OWNS — one call, no
// role branch. Host: session_spawn_make (a real id, announced by _send). Client:
// a local predicted node (a provisional id, flying now). Set the returned
// entity's spawn fields (position, velocity from the muzzle), then
// boot_spawn_send(b, id). The generated typed `<entity>_spawn` helpers route
// through here for ticking entities — prefer those; this is the raw door.
boot_fire_spawn :: proc(b: ^Boot, type: ksess.Entity_Type, owner: knet.Player_Id) -> (entity: rawptr, id: knet.Net_Id) {
	if b.ses != nil && b.ses.is_host {
		return ksess.session_spawn_make(b.ses, type, owner)
	}
	return boot_spawn_predicted(b, type, owner)
}

// The second half — and the ONE announce for both models: the host sends the
// real spawn; a client's predicted spawn stays local until the authority's
// arrives and rekeys it. Pairs with the generated typed `<entity>_spawn`
// helpers exactly like it pairs with boot_fire_spawn (it absorbed the old
// boot_fire_spawn_send: same body, wider duty).
boot_spawn_send :: proc(b: ^Boot, id: knet.Net_Id) {
	if b.ses != nil && b.ses.is_host {
		ksess.session_spawn_send(b.ses, id)
	}
}

// Cancel a typed spawn that has not been announced yet. This is the explicit
// early-return/failed-validation companion to make -> configure -> send:
//
//     e, id := mob_spawn(&g.boot)
//     if !dress(e) {kboot.boot_spawn_cancel(&g.boot, id); return}
//     kboot.boot_spawn_send(&g.boot, id)
//
// It cannot delete a committed authoritative entity. On a predicting client it
// only cancels a provisional spawn and routes cleanup through the lane's
// installed node/census free hook.
boot_spawn_cancel :: proc(b: ^Boot, id: knet.Net_Id) -> bool {
	if b.ses != nil && b.ses.is_host {
		if !ksess.session_spawn_pending(b.ses, id) {return false}
		ksess.session_despawn(b.ses, id)
		return true
	}
	return b.lane != nil && ksim.lane_spawn_cancel(b.lane, id)
}

// Client-side: make the node and track it PREDICTED (provisional id, born this
// tick). Prefer boot_fire_spawn, which routes host/client so game code stays
// single-player-shaped. Returns (entity, provisional id).
boot_spawn_predicted :: proc(b: ^Boot, type: ksess.Entity_Type, owner: knet.Player_Id) -> (entity: rawptr, id: knet.Net_Id) {
	assert(b.lane != nil, "boot_spawn_predicted needs a sim lane (boot_lane) — a projectile flies on it")
	if e0, id0, exists := ksim.lane_spawn_of_exec(b.lane); exists {
		// A reject-chain re-execution (cmd_settle re-runs surviving verb
		// bodies): this fire's projectile already exists — still provisional,
		// or already rekeyed by the authority's spawn. Hand it back; a second
		// node would be a ghost the FIFO match can never pair.
		return e0, id0
	}
	for &k in b.ent_kinds {
		if k.type != type {continue}
		assert(k.sim_set != nil, "a predicted projectile must @(gd_tick) — it flies itself with no inputs")
		scene := (cast(^^gd.Resource)(uintptr(b.ent_game) + k.scene_offset))^
		assert(cast(rawptr)scene != nil, fmt.tprintf("entity %s: its tagged scene field is nil", k.name))
		node := gd.instantiate(cast(gd.Packed_Scene)scene)
		entity = k.script_of(node)
		assert(entity != nil, fmt.tprintf("entity %s: the scene's root does not carry the %s script", k.name, k.name))
		gd.add_child(b.world, node)
		id = ksim.lane_spawn_predicted(b.lane, entity, k.sim_set, owner, type)
		b.ent_nodes[id] = node
		boot_entity_track(b, type, id)
		if k.spawned != nil {
			k.spawned(b.ent_game, entity, id, owner)
		}
		return
	}
	return nil, 0
}

// The lane's node-free hook (installed by boot_lane): a culled predicted spawn
// (a refused fire, or a lost one swept) queue-frees the node the client made.
boot_free_predicted :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) {
	b := cast(^Boot)user
	if node, ok := b.ent_nodes[id]; ok {
		gd.node_queue_free(node)
		delete_key(&b.ent_nodes, id)
	}
	_ = boot_entity_forget(b, id)
}

// The lane's reveal hook (installed by boot_lane): a watched entity hidden at
// spawn becomes presentable — the delayed clock reached its first pose — so
// uncover it. It is already dressed and positioned; this is the moment it was
// meant to appear, in step with the delayed barrel that fired it.
boot_present_ready :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) {
	b := cast(^Boot)user
	if node, ok := b.ent_nodes[id]; ok {
		gd.set_bool(cast(gd.Object)node, "visible", true)
	}
}
