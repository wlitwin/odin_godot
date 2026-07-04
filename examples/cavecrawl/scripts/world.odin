package cavecrawl_scripts

// The world: entity nodes, the spawn factory, and the interact prompt. The
// session announces WHAT exists; this file decides what that looks like on
// this screen (a scene per entity type) and keeps the by-type maps every
// other file navigates with.

import gd "godot:godot"
import rt "godot:runtime"
import kcomms "godot:kit/comms"
import kinter "godot:kit/interact"
import kitems "godot:kit/items"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import kui "godot:kit/ui"
import "core:fmt"

// A script-backed entity node, made from code: base Label + the entity's own
// .odin script. Same flow the editor uses, no scene assets to install.
spawn_node :: proc(self: ^CaveLobby, script_path: cstring) -> gd.Node {
	node := cast(gd.Node)gd.new_label()
	script := gd.resource_loader_load(
		gd.singleton_resource_loader(),
		gd.new_string_cstring(script_path),
		gd.new_string_cstring(""),
		.Cache_Mode_Reuse,
	)
	obj := cast(gd.Object)script
	gd.object_set_script(cast(gd.Object)node, gd.variant_from_object(&obj))
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
		node := spawn_node(self, "res://scripts/spelunker.odin")
		self.nodes[id] = node
		sp := rt.script_of(node, Spelunker)
		track_spelunker(self, id, sp, owner)
		return sp, &spelunker_command_set
	case PICKUP_TYPE:
		node := spawn_node(self, "res://scripts/pickup.odin")
		self.nodes[id] = node
		p := rt.script_of(node, Pickup)
		p.net_id = id
		self.pickups[id] = p
		return p, &pickup_command_set
	case DWELLER_TYPE:
		node := spawn_node(self, "res://scripts/dweller.odin")
		self.nodes[id] = node
		d := rt.script_of(node, Dweller)
		d.net_id = id
		self.dwellers[id] = d
		return d, &dweller_set
	case CHEST_TYPE:
		node := spawn_node(self, "res://scripts/chest.odin")
		self.nodes[id] = node
		c := rt.script_of(node, Chest)
		c.net_id = id
		self.chests[id] = c
		return c, &chest_command_set
	case DOOR_TYPE:
		node := spawn_node(self, "res://scripts/door.odin")
		self.nodes[id] = node
		d := rt.script_of(node, Door)
		d.net_id = id
		self.doors[id] = d
		return d, &door_command_set
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
}

// Host, Start pressed: build the world — a spelunker per seated player, a
// stocked chest, a door — and go live. Every already-seated client gets the
// whole world; later joiners get it behind their welcome (drop-in).
@(gd_method)
cave_lobby_on_start :: proc(self: ^CaveLobby) {
	if !self.ses.is_host || self.started {return}

	chest_node := spawn_node(self, "res://scripts/chest.odin")
	chest := rt.script_of(chest_node, Chest)
	chest.x = 300
	chest.y = 180
	chest.slots[0] = {GEM, 3}
	chest.slots[1] = {TORCH, 2}
	chest.net_id = ksess.session_spawn(&self.ses, CHEST_TYPE, chest, &chest_command_set)
	self.chests[chest.net_id] = chest
	self.nodes[chest.net_id] = chest_node

	door_node := spawn_node(self, "res://scripts/door.odin")
	door := rt.script_of(door_node, Door)
	door.x = 560
	door.y = 180
	door.net_id = ksess.session_spawn(&self.ses, DOOR_TYPE, door, &door_command_set)
	self.doors[door.net_id] = door
	self.nodes[door.net_id] = door_node

	i := 0
	for _, p in self.ses.players {
		if !p.connected {continue}
		node := spawn_node(self, "res://scripts/spelunker.odin")
		sp := rt.script_of(node, Spelunker)
		sp.x = SPAWN_X + f32(i) * 60
		sp.y = SPAWN_Y
		sp.hp = MAX_HP
		sp.stamina = MAX_STAMINA
		i += 1
		id := ksess.session_spawn(&self.ses, SPEL_TYPE, sp, &spelunker_command_set, owner = p.id)
		self.nodes[id] = node
		track_spelunker(self, id, sp, p.id)
	}

	ksess.session_start_replicating(&self.ses)
	enter_the_cave(self)
	kcomms.comms_system(&self.comms, "the descent begins")
	gd.print_str(fmt.tprintf("CAVE_STARTED spel=%d", i))
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
