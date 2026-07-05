package cavecrawl_scripts

// The world: entity nodes, the spawn factory, and the interact prompt. The
// session announces WHAT exists; this file decides what that looks like on
// this screen (a scene per entity type) and keeps the by-type maps every
// other file navigates with.

import gd "godot:godot"
import rt "godot:runtime"
import kai "godot:kit/ai"
import kcomms "godot:kit/comms"
import kinter "godot:kit/interact"
import kitems "godot:kit/items"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import kui "godot:kit/ui"
import "core:fmt"

// Instantiate one of the game's AUTHORED entity scenes (the exported slots
// cave.tscn assigns) under the world node. The scene root carries the
// entity's .odin script; children (glyphs, particles, future sprites and
// collision) are the editor's department.
spawn_scene :: proc(self: ^CaveLobby, scene: ^gd.Resource) -> gd.Node {
	node := gd.instantiate(cast(gd.Packed_Scene)scene)
	gd.add_child(self.world, node)
	return node
}

@(private = "file")
track_spelunker :: proc(self: ^CaveLobby, id: knet.Net_Id, sp: ^Spelunker, owner: knet.Player_Id) {
	sp.net_id = id
	self.spelunkers[id] = sp
	if owner != knet.PLAYER_ID_INVALID {
		self.avatar_of[owner] = id
		if owner == self.ses.me {
			self.me_spel = sp
		}
	}
}

// The session announces a spawn by type: make the node, hand back the struct
// and its generated command set. This runs on CLIENTS (and on resume).
cave_make_entity :: proc(user: rawptr, type: ksess.Entity_Type, id: knet.Net_Id, owner: knet.Player_Id) -> (rawptr, ^knet.Command_Set) {
	self := cast(^CaveLobby)user
	switch type {
	case SPEL_TYPE:
		node := spawn_scene(self, self.spelunker_scene)
		self.nodes[id] = node
		sp := rt.script_of(node, Spelunker)
		track_spelunker(self, id, sp, owner)
		return sp, &spelunker_command_set
	case PICKUP_TYPE:
		node := spawn_scene(self, self.pickup_scene)
		self.nodes[id] = node
		p := rt.script_of(node, Pickup)
		p.net_id = id
		self.pickups[id] = p
		return p, &pickup_command_set
	case DWELLER_TYPE:
		node := spawn_scene(self, self.dweller_scene)
		self.nodes[id] = node
		d := rt.script_of(node, Dweller)
		d.net_id = id
		self.dwellers[id] = d
		return d, &dweller_command_set
	case CHEST_TYPE:
		node := spawn_scene(self, self.chest_scene)
		self.nodes[id] = node
		c := rt.script_of(node, Chest)
		c.net_id = id
		self.chests[id] = c
		return c, &chest_command_set
	case DOOR_TYPE:
		node := spawn_scene(self, self.door_scene)
		self.nodes[id] = node
		d := rt.script_of(node, Door)
		d.net_id = id
		self.doors[id] = d
		return d, &door_command_set
	case LEVEL_TYPE:
		node := spawn_scene(self, self.level_scene)
		self.nodes[id] = node
		lv := rt.script_of(node, Level)
		lv.net_id = id
		self.level = lv
		return lv, &level_command_set
	}
	return nil, nil
}

cave_free_entity :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) {
	self := cast(^CaveLobby)user
	// A despawned dweller was slain — its node is gone this frame, so the
	// death burst is parented to the world, not the corpse.
	if dw, was_dweller := self.dwellers[id]; was_dweller {
		fx_burst_at(self, dw.x, dw.y, {0.8, 0.4, 1, 1})
	}
	if node, ok := self.nodes[id]; ok {
		gd.node_queue_free(node)
		delete_key(&self.nodes, id)
	}
	delete_key(&self.spelunkers, id)
	delete_key(&self.chests, id)
	delete_key(&self.doors, id)
	delete_key(&self.pickups, id)
	delete_key(&self.dwellers, id)
	delete_key(&self.brains, id) // host-side mind (empty map on clients)
	if self.level != nil && self.level.net_id == id {
		self.level = nil
	}
}

// The floor's data asset, by depth. Depths past the table replay the
// deepest def (the cave goes on).
cave_def :: proc(self: ^CaveLobby, depth: int) -> ^Level_Def {
	res := depth >= 2 ? self.floor2_def : self.floor1_def
	return rt.script_of(cast(gd.Object)res, Level_Def)
}

// Load this floor's SCENE on this peer (idempotent per depth): backdrop,
// decoration, and the spawn markers, purely local — the wire carries only
// the depth byte that told us to do this.
cave_load_scenery :: proc(self: ^CaveLobby, depth: int) {
	if self.scenery != nil && int(self.scenery_depth) == depth {return}
	if self.scenery != nil {
		gd.node_queue_free(self.scenery)
	}
	def := cave_def(self, depth)
	self.scenery = gd.instantiate(cast(gd.Packed_Scene)def.scene)
	gd.add_child(self.stage, self.scenery)
	self.scenery_depth = u8(depth)
}

// Where the floor's authoring says a thing goes: a Marker2D by name in the
// loaded scenery.
@(private = "file")
marker_pos :: proc(self: ^CaveLobby, name: cstring) -> gd.Vector2 {
	m := gd.get_node(cast(gd.Object)self.scenery, name)
	if m == nil {return {}}
	return gd.node2d_get_position(cast(gd.Node2d)m)
}

// Host: read the floor's def + markers into the campaign caches the game
// tick runs on (dens, wave plan). Called wherever a floor becomes current:
// Start, each descent, and resume.
cave_cache_floor :: proc(self: ^CaveLobby, depth: int) {
	cave_load_scenery(self, depth)
	d1 := marker_pos(self, "Den1")
	d2 := marker_pos(self, "Den2")
	self.dens = {{d1.x, d1.y, 0}, {d2.x, d2.y, 0}}
	def := cave_def(self, depth)
	counts := def.wave_counts
	rests := def.wave_rests
	n := min(int(gd.packed_int32_array_size(&counts)), int(gd.packed_int32_array_size(&rests)), MAX_WAVES)
	self.waves_n = n
	for i in 0 ..< n {
		self.waves[i] = kai.Wave {
			count = u16(gd.packed_int32_array_get(&counts, gd.Int(i))),
			rest  = u16(gd.packed_int32_array_get(&rests, gd.Int(i))),
		}
	}
}

// Host: furnish one floor from its def — the stocked chest and the (closed)
// door at the positions its scene's markers author. Both Start and every
// descent build floors through here.
@(private = "file")
cave_build_floor :: proc(self: ^CaveLobby, depth: int) {
	cave_cache_floor(self, depth)
	def := cave_def(self, depth)
	chest_at := marker_pos(self, "ChestSpawn")
	door_at := marker_pos(self, "DoorSpawn")

	cep, cid := ksess.session_spawn_make(&self.ses, CHEST_TYPE)
	chest := cast(^Chest)cep
	chest.x = chest_at.x
	chest.y = chest_at.y
	chest.slots[0] = {GEM, u16(def.gems)}
	chest.slots[1] = {TORCH, u16(def.torches)}
	ksess.session_spawn_send(&self.ses, cid)

	dep, did := ksess.session_spawn_make(&self.ses, DOOR_TYPE)
	door := cast(^Door)dep
	door.x = door_at.x
	door.y = door_at.y
	ksess.session_spawn_send(&self.ses, did)
}

// Host, Start pressed: build the world — the depth marker, floor 1, and a
// spelunker per seated player — and go live. Every already-seated client
// gets the whole world; later joiners get it behind their welcome (drop-in).
@(gd_method)
cave_lobby_on_start :: proc(self: ^CaveLobby) {
	if !self.ses.is_host || self.started {return}

	lep, lid := ksess.session_spawn_make(&self.ses, LEVEL_TYPE)
	lv := cast(^Level)lep
	lv.depth = 1
	ksess.session_spawn_send(&self.ses, lid)

	cave_build_floor(self, 1)

	i := 0
	for _, p in self.ses.players {
		if !p.connected {continue}
		sep, sid := ksess.session_spawn_make(&self.ses, SPEL_TYPE, owner = p.id)
		sp := cast(^Spelunker)sep
		sp.x = SPAWN_X + f32(i) * 60
		sp.y = SPAWN_Y
		sp.hp = MAX_HP
		sp.stamina = MAX_STAMINA
		i += 1
		ksess.session_spawn_send(&self.ses, sid)
	}

	ksess.session_start_replicating(&self.ses)
	enter_the_cave(self)
	kcomms.comms_system(&self.comms, "the descent begins")
	gd.print_str(fmt.tprintf("CAVE_STARTED spel=%d", i))
}

// Host: LEVEL MIGRATION — the whole party stood at the open door, so the
// run moves down a floor. Despawn everything that belongs to the old floor
// (spelunkers and the depth marker persist — bags, hp, and cooldowns walk
// down the stairs), reset the host-side campaign state, bump the replicated
// depth, and furnish the next def. Clients need NO migration code: the same
// despawns/spawns/deltas that built floor 1 deliver floor 2, and each owner
// walks itself to the new floor's mouth on the depth edge (see process).
cave_descend :: proc(self: ^CaveLobby) {
	doomed := make([dynamic]knet.Net_Id, context.temp_allocator)
	for id in self.chests {append(&doomed, id)}
	for id in self.doors {append(&doomed, id)}
	for id in self.pickups {append(&doomed, id)}
	for id in self.dwellers {append(&doomed, id)}
	for id in doomed {
		ksess.session_despawn(&self.ses, id) // the free proc handles node + maps, every role
	}
	clear(&self.brains)
	clear(&self.respawn_at)
	clear(&self.flying) // old floor's rocks die with the floor
	self.director = {}
	self.dens_used = 0
	self.last_wave = 0

	self.level.depth += 1
	cave_build_floor(self, int(self.level.depth))
	kcomms.comms_system(&self.comms, fmt.tprintf("the party descends to depth %d", self.level.depth))
	gd.print_str(fmt.tprintf("CAVE_DESCEND depth=%d", self.level.depth))
}

// What can I use from here? The prompt and the host's command gate share
// REACH and the same in_range math — they cannot disagree about geometry.
update_prompt :: proc(self: ^CaveLobby) {
	me := self.me_spel
	cands := make([dynamic]kinter.Candidate, context.temp_allocator)
	for id, c in self.chests {
		append(&cands, kinter.Candidate{id = u32(id), pos = {c.x, c.y, 0}})
	}
	for id, d in self.doors {
		append(&cands, kinter.Candidate{id = u32(id), pos = {d.x, d.y, 0}})
	}
	for id, p in self.pickups {
		append(&cands, kinter.Candidate{id = u32(id), pos = {p.x, p.y, 0}})
	}
	best, ok := kinter.pick(cands[:], {me.x, me.y, 0}, REACH)
	if !ok {
		self.target_kind = 0
		kui.prompt_set(&self.prompt, "")
		return
	}
	self.target_id = knet.Net_Id(best.id)
	if _, is_chest := self.chests[self.target_id]; is_chest {
		self.target_kind = 1
		kui.prompt_set(&self.prompt, "E — loot chest")
	} else if _, is_pickup := self.pickups[self.target_id]; is_pickup {
		self.target_kind = 3
		p := self.pickups[self.target_id]
		kui.prompt_set(&self.prompt, fmt.ctprintf("E — pick up %s", kitems.items_name(&self.table, p.item)))
	} else {
		self.target_kind = 2
		door := self.doors[self.target_id]
		kui.prompt_set(&self.prompt, door.open ? "E — close door" : "E — open door")
	}
}
