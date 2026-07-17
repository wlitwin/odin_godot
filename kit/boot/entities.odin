package kit_boot

// boot_entities — the factory, written by nobody.
//
// Every game's make/free pair was the same six lines per entity type:
// instantiate the exported scene under boot.world, remember the node by id,
// script_of the struct, return it with its command set; free walked it all
// back. The declaration now lives where the house puts declarations — a tag
// on the exported scene field:
//
//     mob_scene: ^gd.Resource `gd:"export,resource=PackedScene,entity=Mob:3"`,
//
// scriptgen turns those tags into `<snake>_entity_kinds` (plus the
// `MOB_TYPE :: ksess.Entity_Type(3)` constants games used to hand-keep), and
// this driver turns the table into the session's factory:
//
//     // ready(), AFTER boot_attach (the factory parents under b.world):
//     kboot.boot_entities(&self.boot, self, scrapyard_entity_kinds[:])
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
}

// Install the table as the session's factory. `game` is the struct carrying
// the tagged scene fields (scene_offset resolves against it) — it is also
// named as the session's game pointer, so `<verb>_then` consequences keep
// receiving the game, not this driver.
boot_entities :: proc(b: ^Boot, game: rawptr, kinds: []Entity_Kind) {
	assert(b.ses != nil, "boot_entities comes AFTER boot_attach — it installs the factory on the attached session")
	assert(game != nil, "boot_entities needs the game struct — its tagged scene fields are the table's scenes")
	b.ent_kinds = kinds
	b.ent_game = game
	ksess.session_set_factory(b.ses, b, boot_make_entity, boot_free_entity)
	ksess.session_set_game(b.ses, game)
}

// The node an entity rides — what the hand-written `nodes[id]` map was for
// (dressing a newborn, parenting a nameplate, flashing a hit).
boot_node :: proc(b: ^Boot, id: knet.Net_Id) -> (gd.Node, bool) {
	node, ok := b.ent_nodes[id]
	return node, ok
}

// ---------------------------------------------------------------------------
// The census, without the maps. Every game kept `map[Net_Id]^T` + an
// owner mirror + an avatar_of mirror beside the factory — bookkeeping of
// state the kit already holds (the registry's entity + owner, this ledger's
// type). These queries read it back; scriptgen wraps them per `entity=` tag
// as typed `<snake>_of` / `my_<snake>` / `<snake>_owned_by` / `<snake>_ids`,
// so the census hooks shrink to the genuinely game-shaped bookkeeping (or
// vanish). Lookups are map hits; the owned/ids scans walk the type ledger —
// friendslop-sized, cache it yourself if a game ever makes it hot.

// The entity behind an id, IF it is of `type` (a stale id or a different
// kind returns false rather than a mis-cast).
boot_entity :: proc(b: ^Boot, id: knet.Net_Id, type: ksess.Entity_Type) -> (rawptr, bool) {
	t, tracked := b.ent_types[id]
	if !tracked || t != type || b.ses == nil {
		return nil, false
	}
	if e, ok := knet.registry_get(&b.ses.reg, id); ok {
		return e.entity, true
	}
	return nil, false
}

// Who owns an entity (PLAYER_ID_INVALID = host-owned / unknown id) — the
// `owner_pid` map every world pass hand-kept.
boot_entity_owner :: proc(b: ^Boot, id: knet.Net_Id) -> knet.Player_Id {
	if b.ses == nil {
		return knet.PLAYER_ID_INVALID
	}
	if e, ok := knet.registry_get(&b.ses.reg, id); ok {
		return e.owner
	}
	return knet.PLAYER_ID_INVALID
}

// A player's entity of `type` — the `avatar_of` map. First match wins (one
// avatar per player per type is the friendslop shape).
boot_owned_entity :: proc(b: ^Boot, type: ksess.Entity_Type, owner: knet.Player_Id) -> (entity: rawptr, id: knet.Net_Id, ok: bool) {
	if b.ses == nil || owner == knet.PLAYER_ID_INVALID {
		return nil, 0, false
	}
	for eid, t in b.ent_types {
		if t != type {
			continue
		}
		if e, found := knet.registry_get(&b.ses.reg, eid); found && e.owner == owner {
			return e.entity, eid, true
		}
	}
	return nil, 0, false
}

// Every live id of `type`, temp-allocated by default — range it and resolve
// each through the typed `<snake>_of`.
boot_entity_ids :: proc(b: ^Boot, type: ksess.Entity_Type, allocator := context.temp_allocator) -> []knet.Net_Id {
	ids := make([dynamic]knet.Net_Id, allocator)
	for eid, t in b.ent_types {
		if t == type {
			append(&ids, eid)
		}
	}
	return ids[:]
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
				b.ent_types[id] = type
				delete_key(&b.ent_types, from)
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
		b.ent_types[id] = type
		if k.spawned != nil {
			// Bookkeeping-time, like the hand factories were: the entity exists
			// but its spawn-time FIELDS are not set yet — track it, don't dress
			// it (dressing belongs on Ev_Spawned, which fires once fields land).
			k.spawned(b.ent_game, entity, id, owner)
		}
		if k.sim_set != nil && b.lane != nil {
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
	delete_key(&b.ent_types, id)
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

// Client-side: make the node and track it PREDICTED (provisional id, born this
// tick). Prefer boot_fire_spawn, which routes host/client so game code stays
// single-player-shaped. Returns (entity, provisional id).
boot_spawn_predicted :: proc(b: ^Boot, type: ksess.Entity_Type, owner: knet.Player_Id) -> (entity: rawptr, id: knet.Net_Id) {
	assert(b.lane != nil, "boot_spawn_predicted needs a sim lane (boot_lane) — a projectile flies on it")
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
		b.ent_types[id] = type
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
	delete_key(&b.ent_types, id)
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
