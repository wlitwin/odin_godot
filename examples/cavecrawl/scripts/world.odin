package cavecrawl_scripts

// The world: the entity census and the interact prompt. The session
// announces WHAT exists; the GENERATED factory table (each scene field's
// `entity=Name:id` tag in cavecrawl.odin) decides what that looks like —
// instantiate the scene, free the node, keep the id→node ledger. What's left
// here is the genuinely game-shaped half: the typed *_spawned/*_freed hooks
// that keep the by-type maps every other file navigates with.

import gd "godot:godot"
import rt "godot:runtime"
import kai "godot:kit/ai"
import kboot "godot:kit/boot"
import kcomms "godot:kit/comms"
import kfx "godot:kit/fx"
import kinter "godot:kit/interact"
import kitems "godot:kit/items"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import kui "godot:kit/ui"
import "core:fmt"

// ---- the census: name-paired spawn/free hooks (fired by the kboot driver;
// ---- spawn-time fields are NOT set yet — dressing belongs on Ev_Spawned) ----

@(gd_half)
spelunker_spawned :: proc(game: ^CaveLobby, self: ^Spelunker, id: knet.Net_Id, owner: knet.Player_Id) {
	game.spelunkers[id] = self
	if owner != knet.PLAYER_ID_INVALID {
		game.avatar_of[owner] = id
		if owner == game.ses.me {
			game.me_spel = self
		}
	}
}

@(gd_half)
spelunker_freed :: proc(game: ^CaveLobby, self: ^Spelunker, id: knet.Net_Id) {
	delete_key(&game.spelunkers, id)
}

@(gd_half)
chest_spawned :: proc(game: ^CaveLobby, self: ^Chest, id: knet.Net_Id, owner: knet.Player_Id) {
	game.chests[id] = self
}

@(gd_half)
chest_freed :: proc(game: ^CaveLobby, self: ^Chest, id: knet.Net_Id) {
	delete_key(&game.chests, id)
}

@(gd_half)
door_spawned :: proc(game: ^CaveLobby, self: ^Door, id: knet.Net_Id, owner: knet.Player_Id) {
	game.doors[id] = self
}

@(gd_half)
door_freed :: proc(game: ^CaveLobby, self: ^Door, id: knet.Net_Id) {
	delete_key(&game.doors, id)
}

@(gd_half)
pickup_spawned :: proc(game: ^CaveLobby, self: ^Pickup, id: knet.Net_Id, owner: knet.Player_Id) {
	game.pickups[id] = self
}

@(gd_half)
pickup_freed :: proc(game: ^CaveLobby, self: ^Pickup, id: knet.Net_Id) {
	delete_key(&game.pickups, id)
}

@(gd_half)
dweller_spawned :: proc(game: ^CaveLobby, self: ^Dweller, id: knet.Net_Id, owner: knet.Player_Id) {
	game.dwellers[id] = self
}

// A despawned dweller was slain — the hook runs BEFORE the node dies, so the
// death burst still reads the corpse's position (parented to the world).
@(gd_half)
dweller_freed :: proc(game: ^CaveLobby, self: ^Dweller, id: knet.Net_Id) {
	fx_burst_at(game, self.x, self.y, {0.8, 0.4, 1, 1})
	delete_key(&game.dwellers, id)
	delete_key(&game.brains, id) // host-side mind (empty map on clients)
}

@(gd_half)
level_spawned :: proc(game: ^CaveLobby, self: ^Level, id: knet.Net_Id, owner: knet.Player_Id) {
	game.level = self
}

@(gd_half)
level_freed :: proc(game: ^CaveLobby, self: ^Level, id: knet.Net_Id) {
	if game.level == self {
		game.level = nil
	}
}

@(gd_half)
relic_spawned :: proc(game: ^CaveLobby, self: ^Relic, id: knet.Net_Id, owner: knet.Player_Id) {
	game.relic = self
	game.relic_id = id
}

@(gd_half)
relic_freed :: proc(game: ^CaveLobby, self: ^Relic, id: knet.Net_Id) {
	if game.relic_id == id {
		game.relic = nil
		game.relic_id = 0
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
// the depth byte that told us to do this. The authored scene then gets its
// PROCEDURAL layer: decoration grown from the replicated seed (below).
cave_load_scenery :: proc(self: ^CaveLobby, depth: int) {
	if self.scenery != nil && int(self.scenery_depth) == depth {return}
	if self.scenery != nil {
		gd.node_queue_free(self.scenery)
	}
	def := cave_def(self, depth)
	self.scenery = gd.instantiate(cast(gd.Packed_Scene)def.scene)
	gd.add_child(self.boot.stage, self.scenery)
	self.scenery_depth = u8(depth)
	cave_scatter(self, depth)
}

// SHARED-SEED PROCGEN, the whole pattern: INTEGER math end to end from the
// replicated seed, so the same (seed, depth, index) lands on the same pixel
// on every machine — floats are the classic procgen divergence trap (FMA
// contraction, libm differences, fast-math flags all vary by platform; keep
// them out of anything that must agree). The printed checksum is the acid
// test's proof that two processes grew the same cave.
@(private = "file")
splitmix32 :: proc(state: ^u32) -> u32 {
	state^ += 0x9E3779B9
	z := state^
	z = (z ~ (z >> 16)) * 0x21F0AAAD
	z = (z ~ (z >> 15)) * 0x735A2D97
	return z ~ (z >> 15)
}

@(private = "file")
cave_scatter :: proc(self: ^CaveLobby, depth: int) {
	if self.level == nil || self.level.seed == 0 || self.scenery == nil {return}
	state := self.level.seed ~ (u32(depth) * 0x9E3779B9)
	sum := u32(0)
	for i in 0 ..< 10 {
		x := int(splitmix32(&state) % 560) + 30
		y := int(splitmix32(&state) % 230) + 60
		sum = sum * 31 + u32(x) * 7 + u32(y)
		node := gd.new_label()
		gd.set_string(cast(gd.Object)node, "text", i % 2 == 0 ? "\xF0\x9F\xAA\xA8" : "\xF0\x9F\x8D\x84") // 🪨 / 🍄
		gd.add_child(self.scenery, cast(gd.Node)node)
		gd.control_set_position(cast(gd.Control)node, {f32(x), f32(y)}, false)
	}
	gd.print_str(fmt.tprintf("CAVE_SCATTER depth=%d sum=%d", depth, sum))
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

	chest, cid := chest_spawn(&self.boot) // typed, from the entity tag — no const, no cast
	chest.x = chest_at.x
	chest.y = chest_at.y
	chest.slots[0] = {GEM, u16(def.gems)}
	chest.slots[1] = {TORCH, u16(def.torches)}
	kboot.boot_spawn_send(&self.boot, cid)

	door, did := door_spawn(&self.boot)
	door.x = door_at.x
	door.y = door_at.y
	kboot.boot_spawn_send(&self.boot, did)
}

// Host, Start pressed: build the world — the depth marker, floor 1, and a
// spelunker per seated player — and go live. Every already-seated client
// gets the whole world; later joiners get it behind their welcome (drop-in).
@(gd_method)
cave_lobby_on_start :: proc(self: ^CaveLobby) {
	if !self.ses.is_host {return}
	if self.started {
		// Mid-run Start is a no; Start on the end screen begins ANOTHER run
		// in the same session — roster and the cumulative ledger stay.
		if self.level != nil && self.level.won != 0 {
			cave_restart(self)
		}
		return
	}

	lv, lid := level_spawn(&self.boot)
	lv.depth = 1
	lv.seed = u32(i64(now_s() * 1000)) | 1 // the run's dice, minted once, never zero
	kboot.boot_spawn_send(&self.boot, lid)
	cave_inscribe(self) // floor 1's inscription — late joiners get it with the world

	cave_build_floor(self, 1)

	// The relic: one per run, resting near the mouth until someone carries it.
	relic, rid := relic_spawn(&self.boot)
	relic.x, relic.y = SPAWN_X + 40, SPAWN_Y - 40
	kboot.boot_spawn_send(&self.boot, rid)

	i := 0
	for _, p in self.ses.players {
		if !p.connected {continue}
		sp, sid := spelunker_spawn(&self.boot, owner = p.id)
		sp.x = SPAWN_X + f32(i) * 60
		sp.y = SPAWN_Y
		sp.hp = MAX_HP
		sp.stamina = MAX_STAMINA
		i += 1
		kboot.boot_spawn_send(&self.boot, sid)
	}

	ksess.session_start_replicating(&self.ses)
	enter_the_cave(self)
	kcomms.comms_system(&self.comms, "the descent begins")
	gd.print_str(fmt.tprintf("CAVE_STARTED spel=%d", i))
}

// Host: carve this floor's INSCRIPTION into the level entity — the entity-blob
// pattern in its smallest form. The text is variable-length state a NEW
// observer must see (not an event: a rejoiner wasn't there when it was set),
// which is exactly what blobs are for — one session_set_blob and it ships
// reliably now AND rides every later join snapshot, backup, and save with no
// catch-up code. Every peer prints it off Ev_Blob_Changed.
cave_inscribe :: proc(self: ^CaveLobby) {
	text := fmt.tprintf("the walls of floor %d remember seed %d", self.level.depth, self.level.seed)
	ksess.session_set_blob(&self.ses, self.level.net_id, transmute([]u8)text)
}

// The non-entity pools, after the kit's CENSUS-DRIVEN wipe: the `_freed`
// hooks above emptied every entity map (and nilled level/relic) through the
// same code that fills them; this half clears what never was an entity. The
// rebuild comes through the factory right after — a takeover's backup
// snapshot or a rejoin's SES_WORLD.
@(gd_half)
cave_lobby_wiped :: proc(self: ^CaveLobby) {
	clear(&self.avatar_of) // spelunker_freed keeps no owner mirror
	clear(&self.respawn_at)
	clear(&self.flying)
	kfx.tracers_clear(&self.tracers)
	self.me_spel = nil
	self.director = {}
	self.dens_used = 0
	self.last_wave = 0
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
	cave_inscribe(self)
	kcomms.comms_system(&self.comms, fmt.tprintf("the party descends to depth %d", self.level.depth))
	gd.print_str(fmt.tprintf("CAVE_DESCEND depth=%d", self.level.depth))
}

// Host: MATCH OVER — the party cleared the LAST floor's door. Flip the
// replicated byte; every peer (this one included) shows its end screen off
// the won edge in process. The world stays up behind the scoreboard: the
// director is done, the floor is clear, nothing bites.
cave_win :: proc(self: ^CaveLobby) {
	if self.level.won != 0 {return} // the trigger holds while the party stands there; win ONCE
	self.level.won = 1
	kcomms.comms_system(&self.comms, "the cave is conquered")
}

// Host: ANOTHER RUN, same session. The old floor despawns exactly like a
// descent; the spelunkers stay (identity, seats, the cumulative ledger) but
// their host-side fields reset — bags, hp, cooldowns. Depth returns to 1 and
// won to 0; owners teleport themselves on the depth edge, every peer clears
// its end screen on the won edge. No re-JOIN, no re-seat, no new world
// snapshot: a restart is just deltas.
cave_restart :: proc(self: ^CaveLobby) {
	doomed := make([dynamic]knet.Net_Id, context.temp_allocator)
	for id in self.chests {append(&doomed, id)}
	for id in self.doors {append(&doomed, id)}
	for id in self.pickups {append(&doomed, id)}
	for id in self.dwellers {append(&doomed, id)}
	for id in doomed {
		ksess.session_despawn(&self.ses, id)
	}
	clear(&self.brains)
	clear(&self.respawn_at)
	clear(&self.flying)
	self.director = {}
	self.dens_used = 0
	self.last_wave = 0

	for _, sp in self.spelunkers {
		sp.hp = MAX_HP
		sp.stamina = MAX_STAMINA
		sp.bag = {}
		sp.cds = {}
	}
	if self.relic != nil { // the relic returns to the mouth, uncarried
		ksess.session_set_owner(&self.ses, self.relic_id, knet.PLAYER_ID_INVALID)
	}
	self.level.won = 0
	self.level.depth = 1
	self.level.wave = 0
	cave_build_floor(self, 1)
	cave_inscribe(self)
	kcomms.comms_system(&self.comms, "the descent begins anew")
	gd.print_str("CAVE_RESTART")
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
	if self.relic != nil && ksess.session_owner_of(&self.ses, self.relic_id) == knet.PLAYER_ID_INVALID {
		append(&cands, kinter.Candidate{id = u32(self.relic_id), pos = {self.relic.x, self.relic.y, 0}})
	}
	for id, sp in self.spelunkers {
		if sp != self.me_spel && sp.hp <= 0 {
			append(&cands, kinter.Candidate{id = u32(id), pos = {sp.x, sp.y, 0}})
		}
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
		kui.prompt_set(&self.prompt, fmt.tprintf("E — pick up %s", kitems.items_name(&self.table, p.item)))
	} else if self.target_id == self.relic_id {
		self.target_kind = 4
		kui.prompt_set(&self.prompt, "E — take the relic")
	} else if sp, is_spel := self.spelunkers[self.target_id]; is_spel {
		self.target_kind = 5
		name := "them"
		if p, ok := ksess.session_player(&self.ses, ksess.session_owner_of(&self.ses, self.target_id)); ok {
			name = p.name
		}
		kui.prompt_set(&self.prompt, fmt.tprintf("E — revive %s", name))
		_ = sp
	} else {
		self.target_kind = 2
		door := self.doors[self.target_id]
		kui.prompt_set(&self.prompt, door.open ? "E — close door" : "E — open door")
	}
}
