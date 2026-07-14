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
